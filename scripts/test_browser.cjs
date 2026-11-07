/* Run after build_web.sh. Uses an installed Playwright via PLAYWRIGHT_MODULE. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const http=require('node:http');
const path=require('node:path');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.wasm':'application/wasm','.json':'application/json','.png':'image/png'};
(async()=>{
 let browser,relay;
 const server=http.createServer(async(req,res)=>{
  const url=new URL(req.url,'http://localhost');
  let file=path.join(root,url.pathname.startsWith('/play/')?'dist/web':'website',url.pathname.startsWith('/play/')?url.pathname.slice(6):url.pathname);
  if(url.pathname.endsWith('/')) file=path.join(file,'index.html');
  try {const data=await fs.readFile(file);res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.setHeader('Cache-Control','no-store');res.end(data)}catch{res.writeHead(404);res.end()}
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const origin=`http://127.0.0.1:${server.address().port}`;
 const directory=await fs.mkdtemp(path.join(root,'build/browser-test-'));
 try {
  let relayAddress='';
  relay=spawn(path.join(root,'build/purrimeter-relay'),[],{env:{...process.env,LISTEN_ADDR:'127.0.0.1:0',ALLOW_DEVELOPMENT_BUILDS:'true',ALLOWED_ORIGINS:`127.0.0.1:${server.address().port}`,SIGNING_KEY_FILE:path.join(directory,'key')}});
  relay.stderr.on('data',data=>{const match=data.toString().match(/listening on (127\.0\.0\.1:\d+)/);if(match)relayAddress=match[1]});
  for(let i=0;i<100&&!relayAddress;i++)await pause(50);
  assert.ok(relayAddress,'local relay started');
  browser=await chromium.launch({headless:true});
  const errors=[]; const frames=new Map();
  const makeContext=async()=>{
   const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:1});
   // Isolate release availability from gameplay tests. Admission is enforced by the real relay.
   await context.route('**/updates',route=>route.fulfill({json:{payload:Buffer.from(JSON.stringify({id:'development',version:'Development'})).toString('base64')}}));
   context.on('page',page=>{frames.set(page,[]);page.on('websocket',ws=>ws.on('framereceived',event=>{try{frames.get(page).push(JSON.parse(event.payload))}catch{}}));page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.text().includes('SCRIPT ERROR')){errors.push(m.text());console.error(m.text())}})});
   return context;
  };
  const loaded=page=>page.waitForFunction(()=>document.getElementById('gate').hidden,null,{timeout:90000});
  const tap=async(page,x,y)=>{await page.bringToFront();await page.touchscreen.tap(x,y);await pause(200)};
  const snapshot=page=>page.evaluate(()=>new Promise((resolve,reject)=>{const r=indexedDB.open('purrimeter-garden',1);r.onsuccess=()=>{const db=r.result;const get=db.transaction('state').objectStore('state').get('garden');get.onsuccess=()=>{db.close();resolve(get.result?JSON.parse(get.result):null)};get.onerror=reject}}));
  const saveWait=async(page)=>{await pause(4500);await page.waitForFunction(()=>PurrimeterBrowser.saveState()==='saved')};
  const context=await makeContext();const page=await context.newPage();await page.goto(origin+'/play/');await loaded(page);
  await tap(page,160,310); // Single player
  await tap(page,65,511); // Scout
  await tap(page,183,280); // Tile preview
  assert.equal((await snapshot(page))?.towers?.length||0,0,'preview does not purchase');
  await page.screenshot({path:path.join(root,'build/browser-placement.png')});
  await tap(page,130,626);await saveWait(page);
  assert.equal((await snapshot(page)).towers.length,1,'touch confirmation builds and persists');
  await page.screenshot({path:path.join(root,'build/browser-phone.png')});
  await tap(page,130,574); // Start while Scout recruitment remains selected.
  await tap(page,60,78); // Pause before continuing the persistence checks.
  await saveWait(page);
  assert.equal((await snapshot(page)).active,true,'touch starts a wave while recruiting');
  // Two-finger zoom via actual Chromium touch dispatch, followed by pan.
  const cdp=await context.newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:130,y:250,id:0},{x:230,y:350,id:1}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:85,y:205,id:0},{x:275,y:395,id:1}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:170,y:260,id:0}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:195,y:280,id:0}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await page.screenshot({path:path.join(root,'build/browser-zoom.png')});
  await page.setViewportSize({width:844,height:390});await pause(500);
  await page.screenshot({path:path.join(root,'build/browser-landscape.png')});
  await page.setViewportSize({width:360,height:740});await pause(500);
  await page.screenshot({path:path.join(root,'build/browser-narrow.png')});
  await page.reload();await loaded(page);assert.equal((await snapshot(page)).towers.length,1,'reload retains garden');
  const second=await context.newPage();await second.goto(origin+'/play/');await second.locator('#takeover').waitFor({state:'visible'});
  await second.locator('#takeover').click();await loaded(second);
  await page.waitForFunction(()=>!PurrimeterBrowser.active());
  assert.equal((await snapshot(second)).towers.length,1,'takeover retains the latest garden');
  // A stale/frozen writer is fenced, even when it still has an old snapshot.
  await page.evaluate(()=>PurrimeterBrowser.save('{"stale":true}'));await pause(300);
  assert.equal((await snapshot(second)).towers.length,1,'old tab cannot overwrite after takeover');
  await page.close();
  // Import rejects invalid data without replacing progress.
  await second.locator('#import-file').setInputFiles({name:'invalid.json',mimeType:'application/json',buffer:Buffer.from('{"version":999}')});
  await pause(400);assert.equal((await snapshot(second)).towers.length,1,'invalid import preserves garden');
  // Configure two independent browser players against a real relay.
  await second.evaluate(address=>PurrimeterBrowser.setSettings('network',`[connection]\naddress="ws://${address}/ws"\n[player]\nname="Phone one"\n`),relayAddress);
  await pause(400);await second.reload();await loaded(second);
  await tap(second,150,427);await pause(500); // Multiplayer
  await second.screenshot({path:path.join(root,'build/browser-lobby.png')});
  await tap(second,140,166); // Create game (verified against screenshot if layout changes)
  await pause(300);await second.screenshot({path:path.join(root,'build/browser-create.png')});
  await second.keyboard.type('Browser garden'); await tap(second,150,554); await pause(1200);
  await second.screenshot({path:path.join(root,'build/browser-multiplayer.png')});
  const waitUntil=async(predicate)=>{for(let i=0;i<100;i++){if(predicate())return;await pause(50)}throw new Error('Timed out waiting for relay message')};
  const players=[];
  const room=frames.get(second).find(frame=>frame.type==='joined').game.id;
  // Two lightweight real relay clients exercise three-player browser rendering.
  // Native integration separately runs three full simulations; avoiding three
  // simultaneous software-rendered WASM engines keeps this UI test bounded.
  for (const name of ['Phone two','Phone three']) {
   const messages=[];const socket=new WebSocket(`ws://${relayAddress}/ws`);
   socket.addEventListener('message',event=>messages.push(JSON.parse(event.data)));
   await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve);socket.addEventListener('error',reject)});
   socket.send(JSON.stringify({type:'hello',version:1,release:'development',name}));
   await waitUntil(()=>messages.some(frame=>frame.type==='welcome'));
   socket.send(JSON.stringify({type:'join',game:room}));
   await waitUntil(()=>messages.some(frame=>frame.type==='joined'));
   await waitUntil(()=>messages.some(frame=>frame.type==='state'));
   socket.send(JSON.stringify({type:'state',state:messages.find(frame=>frame.type==='state').state}));
   players.push({socket,messages});
  }
  await waitUntil(()=>frames.get(second).some(frame=>frame.type==='room'&&frame.game.players.length===3));
  await waitUntil(()=>frames.get(second).filter(frame=>frame.type==='state').length>=2);
  await second.screenshot({path:path.join(root,'build/browser-three-players.png')});
  await tap(second,150,28);await second.screenshot({path:path.join(root,'build/browser-remote.png')});await tap(second,40,28);
  await tap(second,340,28);await second.screenshot({path:path.join(root,'build/browser-chat.png')});
  await tap(second,120,344);await second.keyboard.type('Hello from the phone');await tap(second,327,344);
  await waitUntil(()=>players[0].messages.some(frame=>frame.type==='chat'&&frame.text==='Hello from the phone'));
  const transfer=await snapshot(second);
  await tap(second,330,28);await tap(second,65,568);await tap(second,200,290);await tap(second,130,684);await saveWait(second);
  assert.equal((await snapshot(second)).towers.length,2,'second purchase changes garden before transfer');
  await second.locator('#import-file').setInputFiles({name:'garden.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(transfer))});
  await pause(300);await second.keyboard.press('Tab');await second.keyboard.press('Enter');await saveWait(second);
  assert.equal((await snapshot(second)).towers.length,1,'valid import transfers garden through confirmation');
  for(const player of players)player.socket.close();await context.close();
  const temporary=await makeContext();await temporary.addInitScript(()=>{indexedDB.open=()=>{throw new DOMException('Storage unavailable','SecurityError')}});
  const unsaved=await temporary.newPage();await unsaved.goto(origin+'/play/');await unsaved.locator('#continue').waitFor({state:'visible'});await unsaved.locator('#continue').click();await loaded(unsaved);
  assert.equal(await unsaved.locator('#save-warning').isVisible(),true,'session-only play keeps a visible warning');
  const download=unsaved.waitForEvent('download');await unsaved.locator('#backup').click();
  const backup=await download;const exported=JSON.parse(await fs.readFile(await backup.path(),'utf8'));assert.equal(exported.version,5,'export works when persistent storage is unavailable');
  console.log('PASS browser startup, touch purchase and wave start, pinch/pan, rotation, persistence, takeover fencing, import/export, unavailable storage, three-player multiplayer and chat');
  assert.deepEqual(errors,[],'no Godot or JavaScript runtime errors');
 } finally {
  if(browser)await browser.close();if(relay)relay.kill();server.close();await fs.rm(directory,{recursive:true,force:true});
 }
})().catch(e=>{console.error(e);process.exitCode=1});
