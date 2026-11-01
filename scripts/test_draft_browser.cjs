/* Run build_web.sh and tests/rebirth_draft.gd -- --browser-fixture first.
 * Uses an isolated browser profile and only generated fixtures, never player data. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const http=require('node:http');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.wasm':'application/wasm','.json':'application/json','.png':'image/png'};
(async()=>{
 let browser;
 const server=http.createServer(async(req,res)=>{
  if(req.url==='/fixture'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><title>Isolated draft fixture</title>');return}
  let file=path.join(root,'dist/web',new URL(req.url,'http://localhost').pathname);
  if(req.url==='/')file=path.join(root,'dist/web/index.html');
  try{const data=await fs.readFile(file);res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(data)}catch{res.writeHead(404);res.end()}
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const origin=`http://127.0.0.1:${server.address().port}`;
 try{
  browser=await chromium.launch({headless:true});
  const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:1});
  await context.route('**/updates',route=>route.fulfill({json:{payload:Buffer.from(JSON.stringify({id:'development',version:'Development'})).toString('base64')}}));
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.text().includes('SCRIPT ERROR'))errors.push(m.text())});
  await page.goto(origin+'/fixture');
  const fixture=JSON.parse(await fs.readFile(path.join(root,'build/draft-browser-fixture.json'),'utf8'));
  await page.evaluate(data=>new Promise((resolve,reject)=>{
   const open=indexedDB.open('purrimeter-garden',1);open.onupgradeneeded=()=>open.result.createObjectStore('state');
   open.onsuccess=()=>{const db=open.result,tx=db.transaction('state','readwrite');tx.objectStore('state').put(JSON.stringify(data),'garden');tx.oncomplete=()=>{db.close();resolve()};tx.onerror=reject};open.onerror=reject;
  }),fixture);
  const snapshot=()=>page.evaluate(()=>new Promise((resolve,reject)=>{const open=indexedDB.open('purrimeter-garden',1);open.onsuccess=()=>{const db=open.result,request=db.transaction('state').objectStore('state').get('garden');request.onsuccess=()=>{db.close();resolve(JSON.parse(request.result))};request.onerror=reject}}));
  const loaded=()=>page.waitForFunction(()=>document.getElementById('gate').hidden,null,{timeout:90000});
  const tap=async(x,y)=>{await page.touchscreen.tap(x,y);await pause(350)};
  const capture=async(name)=>page.screenshot({path:path.join(root,`build/draft-browser-${name}.png`)});
  await page.goto(origin+'/');await loaded();await tap(160,310);await capture('ready');
  await tap(245,626);await capture('confirmation');
  if(process.argv.includes('--probe')){console.log('Draft browser confirmation captured');return}
  await tap(190,784);await pause(500);await capture('offers');
  let saved=await snapshot();
  assert.equal(saved.rebirths,fixture.rebirths+1,'confirmation durably increments rebirth once');
  assert.equal(saved.pending_draft.offers.length,3,'three offers persisted before choosing');
  const offers=saved.pending_draft.offers;
  await page.keyboard.press('Escape');await tap(70,78);await pause(200);
  assert.deepEqual((await snapshot()).pending_draft.offers,offers,'Escape cannot reroll offers');
  await page.reload();await loaded();await tap(160,310);await capture('reloaded');
  assert.deepEqual((await snapshot()).pending_draft.offers,offers,'reload restores identical pending offers');
  await tap(190,325);await capture('selected');
  // Simulate a storage failure at the exact reward boundary. Reads still work.
  await page.evaluate(()=>{
   const original=IDBDatabase.prototype.transaction;
   IDBDatabase.prototype.transaction=function(stores,mode,...rest){
    if(mode==='readwrite')throw new DOMException('Isolated quota fixture','QuotaExceededError');
    return original.call(this,stores,mode,...rest);
   };
  });
  await tap(190,750);await pause(400);await capture('save-failed');
  saved=await snapshot();
  assert.deepEqual(saved.pending_draft.offers,offers,'failed reward write retains durable pending offers');
  assert.equal(saved.draft_ranks[offers[0]]||0,fixture.draft_ranks[offers[0]]||0,'failed reward write grants nothing');
  await page.reload();await loaded();await tap(160,310);
  assert.deepEqual((await snapshot()).pending_draft.offers,offers,'failure recovery restores the same unresolved draft');
  await tap(190,325);await tap(190,750);await pause(500);
  saved=await snapshot();
  assert.deepEqual(saved.pending_draft,{},'choice resolves and persists pending draft');
  assert.equal(saved.draft_ranks[offers[0]],(fixture.draft_ranks[offers[0]]||0)+1,'touch choice grants one rank');
  const ranks=saved.draft_ranks;
  await page.reload();await loaded();await tap(160,310);await capture('chosen-reloaded');
  saved=await snapshot();assert.deepEqual(saved.draft_ranks,ranks,'chosen improvement survives browser reload');
  assert.equal(saved.bonus_points,fixture.bonus_points,'normal drafts do not add automatic coin bonuses');
  assert.deepEqual(errors,[],'browser has no script or page errors');
  console.log('PASS browser draft confirmation, durable offers, no rerolls, failed-write recovery, touch choice, reload, and legacy bonus preservation');
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve))}
})().catch(error=>{console.error(error);process.exitCode=1});
