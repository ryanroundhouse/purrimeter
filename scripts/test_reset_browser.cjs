/* Run build_web.sh and tests/reset_progress.gd first. All data is synthetic. */
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
  if(req.url==='/fixture'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><title>Isolated reset fixture</title>');return}
  let file=path.join(root,'dist/web',new URL(req.url,'http://localhost').pathname);
  if(req.url==='/')file=path.join(root,'dist/web/index.html');
  try{const data=await fs.readFile(file);res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(data)}catch{res.writeHead(404);res.end()}
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const origin=`http://127.0.0.1:${server.address().port}`;
 try{
  browser=await chromium.launch({headless:true});
  const context=await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1});
  await context.route('**/updates',route=>route.fulfill({json:{payload:Buffer.from(JSON.stringify({id:'development',version:'Development'})).toString('base64')}}));
  const errors=[];
  context.on('page',page=>{
   page.on('pageerror',e=>errors.push(e.message));
   page.on('console',m=>{if(m.text().includes('SCRIPT ERROR') || m.text().startsWith('ERROR:'))errors.push(m.text())});
  });
  const page=await context.newPage();
  await page.goto(origin+'/fixture');
  const fixture=JSON.parse(await fs.readFile(path.join(root,'build/reset-browser-fixture.json'),'utf8'));
  const settings={audio:'[audio]\nmuted=true\n',network:'[connection]\naddress="wss://example.invalid/ws"\n[player]\nname="Reset tester"\nchat_sound=false\n'};
  await page.evaluate(({fixture,settings})=>new Promise((resolve,reject)=>{
   const open=indexedDB.open('purrimeter-garden',1);open.onupgradeneeded=()=>open.result.createObjectStore('state');
   open.onsuccess=()=>{const db=open.result,tx=db.transaction('state','readwrite'),store=tx.objectStore('state');store.put(JSON.stringify(fixture),'garden');store.put(settings,'settings');tx.oncomplete=()=>{db.close();resolve()};tx.onerror=reject};open.onerror=reject;
  }),{fixture,settings});
  const state=target=>target.evaluate(()=>new Promise((resolve,reject)=>{const open=indexedDB.open('purrimeter-garden',1);open.onsuccess=()=>{const db=open.result,store=db.transaction('state').objectStore('state'),g=store.get('garden'),s=store.get('settings');s.onsuccess=()=>{db.close();resolve({garden:JSON.parse(g.result),settings:s.result})};s.onerror=reject}}));
  const loaded=target=>target.waitForFunction(()=>document.getElementById('gate').hidden,null,{timeout:90000});
  const capture=async(name)=>page.screenshot({path:path.join(root,`build/reset-browser-${name}.png`)});
  const openReset=async()=>{await page.locator('#canvas').focus();for(let i=0;i<7;i++)await page.keyboard.press('Tab');await page.keyboard.press('Enter');await pause(300)};
  await page.goto(origin+'/');await loaded(page);await capture('menu');
  await openReset();await capture('confirmation');
  if(process.argv.includes('--probe'))return;
  await page.keyboard.press('Enter');await pause(250); // Cancel is the default.
  assert.equal((await state(page)).garden.achievements.unlocked_level,5,'default Enter cancels reset');
  await page.reload();await loaded(page);await openReset();
  await page.keyboard.press('Tab');await page.keyboard.press('Enter');await pause(500);
  await capture('success');
  let saved=await state(page);
  const fresh=s=>{
   assert.equal(s.garden_level,1);assert.equal(s.level,1);assert.equal(s.achievements.unlocked_level,1);
   assert.deepEqual(s.achievements.earned,{});assert.deepEqual(s.towers,[]);assert.deepEqual(s.pending_draft,{});
   assert.equal(s.auto_start,true);assert.equal(s.auto_start_remaining,0);assert.equal(s.active,false);
  };
  fresh(saved.garden);assert.deepEqual(saved.settings,settings,'reset preserves browser preferences');
  await page.reload();await loaded(page);fresh((await state(page)).garden);
  // Old exported progression is still deliberately restorable via the real import UI.
  await page.locator('#canvas').focus();await page.keyboard.press('Tab');await page.keyboard.press('Enter');await pause(250);
  // This fixture has a pending draft, but import confirmation precedes its restoration.
  await page.locator('#import-file').setInputFiles({name:'old-garden.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(fixture))});
  await pause(300);await page.keyboard.press('Tab');await page.keyboard.press('Enter');await pause(500);
  assert.equal((await state(page)).garden.achievements.unlocked_level,5,'old export restores player progression');
  await page.reload();await loaded(page);
  // Block IndexedDB writes exactly at reset. No candidate may leak into export/autosave.
  await page.evaluate(()=>{
   const original=IDBDatabase.prototype.transaction;
   IDBDatabase.prototype.transaction=function(stores,mode,...rest){if(mode==='readwrite')throw new DOMException('Isolated quota failure','QuotaExceededError');return original.call(this,stores,mode,...rest)};
  });
  await openReset();await page.keyboard.press('Tab');await page.keyboard.press('Enter');await pause(500);
  await capture('failed');
  assert.equal((await state(page)).garden.achievements.unlocked_level,5,'failed reset retains durable progress');
  const download=page.waitForEvent('download');await page.locator('#backup').click();
  const backup=await download;const exported=JSON.parse(await fs.readFile(await backup.path(),'utf8'));
  assert.equal(exported.achievements.unlocked_level,5,'failed reset retains in-memory progress');
  assert.equal(await page.locator('#save-warning').isVisible(),true,'saving failure remains visible');
  await page.locator('#session').click();
  // Reload would clear the injected failure; continue explicitly in session-only mode instead.
  await openReset();await page.keyboard.press('Tab');await page.keyboard.press('Enter');await pause(400);
  await capture('session');
  const sessionDownload=page.waitForEvent('download');await page.locator('#backup').click();
  const sessionBackup=await sessionDownload;fresh(JSON.parse(await fs.readFile(await sessionBackup.path(),'utf8')));
  assert.equal((await state(page)).garden.achievements.unlocked_level,5,'session-only reset does not claim to replace durable data');
  assert.equal(await page.locator('#save-warning').isVisible(),true,'session-only reset retains warning');
  // A queued autosave must finish before reset; stale captures during reset are suppressed.
  await page.reload();await loaded(page);
  await page.evaluate(({old,fresh})=>{
   PurrimeterBrowser.save(JSON.stringify(old));
   PurrimeterBrowser.resetSave(JSON.stringify(fresh));
   PurrimeterBrowser.save(JSON.stringify(old));
  },{old:fixture,fresh:saved.garden});
  await page.waitForFunction(()=>PurrimeterBrowser.saveState()==='saved');
  fresh((await state(page)).garden);
  // Taking over fences even an explicitly requested reset from the old tab.
  const second=await context.newPage();await second.goto(origin+'/');
  await second.locator('#takeover').waitFor({state:'visible'});
  await second.locator('#takeover').click();await loaded(second);
  await page.waitForFunction(()=>!PurrimeterBrowser.active());
  const owned=await state(second);
  await page.evaluate(old=>PurrimeterBrowser.resetSave(JSON.stringify(old)),fixture);await pause(100);
  assert.deepEqual((await state(second)).garden,owned.garden,'stale tab cannot reset the active tab garden');
  assert.deepEqual(errors,[],'no browser runtime errors');
  console.log('PASS browser reset confirmation, cancellation, persistence, reload, preferences, old imports, failed writes, session-only reset, queued saves, and stale-tab fencing');
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve))}
})().catch(error=>{console.error(error);process.exitCode=1});
