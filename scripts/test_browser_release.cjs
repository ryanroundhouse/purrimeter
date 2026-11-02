/* Verify the prepared production entry point, immutable URLs, gzip and CSP. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const http=require('node:http'), fs=require('node:fs/promises'), path=require('node:path'), assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),site=path.join(root,'build/website');
(async()=>{
 const envelope=JSON.parse(await fs.readFile(path.join(site,'game-release.json'),'utf8'));
 const release=JSON.parse(Buffer.from(envelope.payload,'base64').toString());
 const nginx=await fs.readFile(path.join(root,'website/deploy/nginx.conf'),'utf8');
 const policies=[...nginx.matchAll(/Content-Security-Policy "([^"]+)"/g)];
 const policy=policies.at(-1)[1];
 const errors=[], requested=[];
 const server=http.createServer(async(req,res)=>{
  const url=new URL(req.url,'http://localhost');let suffix=url.pathname;
  if(suffix.startsWith(`/game-releases/${release.id}/web/`))suffix='/play/'+suffix.split('/web/')[1];
  if(suffix.endsWith('/'))suffix+='index.html';let file=path.join(site,suffix);
  const ext=path.extname(file);let encoding=false;
  if((req.headers['accept-encoding']||'').includes('gzip')){try{await fs.access(file+'.gz');file+='.gz';encoding=true}catch{}}
  try{
   const data=await fs.readFile(file);res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.wasm':'application/wasm','.png':'image/png','.json':'application/json'})[ext]||'application/octet-stream');
   if(encoding)res.setHeader('Content-Encoding','gzip');res.setHeader('Content-Length',data.length);
   if(url.pathname.startsWith('/play/'))res.setHeader('Content-Security-Policy',policy);
   res.end(data);
  }catch{res.writeHead(404);res.end()}
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin=`http://127.0.0.1:${server.address().port}`;
 let browser;
 try{
  browser=await chromium.launch({headless:true});const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:1});
  await context.route('**/updates',route=>route.fulfill({json:envelope}));
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  page.on('response',response=>requested.push({url:response.url(),status:response.status(),headers:response.headers()}));
  await page.goto(origin+'/play/');await page.waitForFunction(()=>document.getElementById('gate').hidden,null,{timeout:90000});
  await page.touchscreen.tap(160,310);await page.waitForTimeout(500);await page.screenshot({path:path.join(root,'build/browser-release-phone.png')});
  const wasm=requested.find(r=>r.url.endsWith('.wasm'));assert.ok(wasm.url.includes(`/game-releases/${release.id}/web/`));assert.equal(wasm.headers['content-encoding'],'gzip');
  assert.equal(requested.some(r=>r.status>=400),false,'all release assets resolve');assert.deepEqual(errors,[],'packaged runtime obeys CSP and loads without errors');
  await page.goto(origin+'/');assert.equal(await page.locator('a[href="/play/"]').count(),1);assert.equal(await page.locator('a[href="/downloads/Purrimeter-Server.tar.gz"]').count(),1);assert.equal(await page.locator('#download-android').count(),1);assert.equal(await page.locator('#download-android[data-store-status="coming-soon"][href]').count(),0,'coming-soon Play link is inert');
  await page.goto(origin+'/privacy/');assert.equal(await page.locator('h1').textContent(),'Privacy policy');await page.screenshot({path:path.join(root,'build/browser-release-home.png'),fullPage:true});
  console.log('PASS production browser packaging, immutable assets, gzip, CSP and homepage entry',release.id);
 }finally{if(browser)await browser.close();server.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
