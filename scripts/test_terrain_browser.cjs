/* Run after build_web.sh; real landscape touch input and IndexedDB, isolated browser profile. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const http=require('node:http');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.wasm':'application/wasm','.json':'application/json','.png':'image/png'};
(async()=>{
 const server=http.createServer(async(req,res)=>{
  const url=new URL(req.url,'http://localhost');
  const name=url.pathname.endsWith('/')?url.pathname+'index.html':url.pathname;
  try{const data=await fs.readFile(path.join(root,'dist/web',name));res.setHeader('Content-Type',mime[path.extname(name)]||'application/octet-stream');res.end(data)}catch{res.writeHead(404);res.end()}
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true});
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},hasTouch:true,isMobile:true,deviceScaleFactor:1});
  await context.route('**/updates',r=>r.fulfill({json:{payload:Buffer.from(JSON.stringify({id:'development',version:'Development'})).toString('base64')}}));
  const page=await context.newPage();const errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.text().includes('SCRIPT ERROR'))errors.push(m.text())});
  const loaded=()=>page.waitForFunction(()=>document.getElementById('gate').hidden,null,{timeout:90000});
  const tap=async(x,y)=>{await page.touchscreen.tap(x,y);await pause(250)};
  const snapshot=()=>page.evaluate(()=>new Promise((resolve,reject)=>{const r=indexedDB.open('purrimeter-garden',1);r.onsuccess=()=>{const db=r.result;const get=db.transaction('state').objectStore('state').get('garden');get.onsuccess=()=>{db.close();resolve(get.result?JSON.parse(get.result):null)};get.onerror=reject}}));
  const saved=async()=>{await pause(4500);await page.waitForFunction(()=>PurrimeterBrowser.saveState()==='saved')};
  await page.goto(`http://127.0.0.1:${server.address().port}/`);await loaded();await pause(500);
  await fs.mkdir(path.join(root,'build/terrain-review/browser'),{recursive:true});
  await page.screenshot({path:path.join(root,'build/terrain-review/browser/menu.png')});
  await tap(420,280); // Single player.
  await saved();
  const initial=await snapshot();
  assert.equal(initial.version,5,'terrain save version');
  assert.ok(initial.terrain.length>=39 && initial.terrain.length<=51,'new browser garden has obstacles');
  const terrain=initial.terrain;
  const occupied=new Set(terrain.map(t=>t.cell));
  const buildCell=Array.from({length:256},(_,i)=>i).find(i=>i>64 && i<192 && i!==128 && i!==143 && !occupied.has(i));
  // Landscape mobile field: 342 square pixels, starting at (8,40).
  const tilePoint=cell=>[8+(cell%16+0.5)*342/16,40+(Math.floor(cell/16)+0.5)*342/16];
  await tap(420,90); // Scout.
  await tap(...tilePoint(terrain[0].cell));
  await page.screenshot({path:path.join(root,'build/terrain-review/browser/blocked-placement.png')});
  await tap(510,200); // Confirm invalid placement.
  await saved();
  assert.equal((await snapshot()).towers.length,0,'terrain rejects touch recruitment');
  assert.equal((await snapshot()).coins,initial.coins,'invalid recruitment does not spend coins');
  await tap(...tilePoint(buildCell));
  await tap(510,200); // Confirm valid placement.
  await saved();
  const built=await snapshot();
  assert.equal(built.towers.length,1,'touch confirmation builds on ground');
  assert.equal(built.towers[0].cell,buildCell,'touch targets expected ground cell');
  assert.deepEqual(built.terrain,terrain,'recruitment preserves terrain');
  await page.screenshot({path:path.join(root,'build/terrain-review/browser/garden.png')});
  await page.reload();await loaded();await saved();
  const resumed=await snapshot();
  assert.deepEqual(resumed.terrain,terrain,'reload retains layout and styles');
  assert.equal(resumed.towers.length,1,'reload retains cat');
  assert.deepEqual(errors,[],'no browser script errors');
  console.log('Terrain browser checks passed');
 }finally{await browser.close();await new Promise(r=>server.close(r))}
})().catch(e=>{console.error(e);process.exitCode=1});
