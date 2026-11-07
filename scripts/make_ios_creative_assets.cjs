/* Render App Store creative assets (product page header 3840x1646, search results
   3840x2560) from the game's own artwork and the iPhone store capture with Playwright.
   Outputs: store/ios/creative/{header,search}.png (opaque PNG, no alpha). */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||require('node:path').join(__dirname,'../.tools/deploy/node_modules/playwright'));
const fs=require('node:fs/promises'), path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=async p=>'data:image/png;base64,'+(await fs.readFile(path.join(root,p))).toString('base64');
(async()=>{
 const icon=await read('game/assets/icon.png');
 const shot=await read('store/ios/screenshots/en-US/iphone-01-garden.png');
 const font=(await fs.readFile(path.join(root,'website/assets/PixelifySans.ttf'))).toString('base64');
 const css=`@font-face{font-family:P;src:url(data:font/ttf;base64,${font})}html,body{margin:0;background:#131c26}`;
 const browser=await chromium.launch({headless:true});
 const shoot=async(w,h,html,out)=>{
  const page=await browser.newPage({viewport:{width:w,height:h},deviceScaleFactor:1});
  await page.setContent(`<!doctype html><style>${css}</style>${html}`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(200);
  await page.screenshot({path:path.join(root,out)});await page.close();console.log('wrote',out);
 };
 const scene=(w,h,s)=>`<div style="width:${w}px;height:${h}px;background:linear-gradient(135deg,#131c26 0%,#1d3a2e 100%);position:relative;overflow:hidden;font-family:P,sans-serif;color:#f4edd7">
  <img src="${shot}" style="position:absolute;left:${s.shotLeft}px;top:${s.shotTop}px;width:${s.shotW}px;border:${s.border}px solid #42564f;border-radius:${s.radius}px;box-shadow:0 ${s.border*5}px ${s.border*15}px rgba(0,0,0,.6)">
  <img src="${icon}" style="position:absolute;left:${s.x}px;top:${s.iconTop}px;width:${s.icon}px;height:${s.icon}px;border-radius:${s.icon*0.21}px;image-rendering:pixelated">
  <div style="position:absolute;left:${s.x}px;top:${s.titleTop}px;font-size:${s.title}px;font-weight:600;line-height:1">Purrimeter</div>
  <div style="position:absolute;left:${s.x+4}px;top:${s.subTop}px;font-size:${s.sub}px;color:#89dfb5">The Garden Guard</div>
  <div style="position:absolute;left:${s.x+4}px;top:${s.bodyTop}px;width:${s.bodyW}px;font-family:'Avenir Next','Segoe UI',sans-serif;font-size:${s.body}px;line-height:1.4;color:#b0c3bd">Build a maze with claws. Endless cat tower defence, solo or with friends.</div>
 </div>`;
 // Header 21:9. Focal content kept in the central band so 16:9 crops still show the cats.
 await shoot(3840,1646,scene(3840,1646,{x:220,iconTop:300,icon:380,titleTop:740,title:230,subTop:1000,sub:100,bodyTop:1170,bodyW:1300,body:74,
   shotLeft:1660,shotTop:160,shotW:2600,border:14,radius:48}),'store/ios/creative/header.png');
 // Search results 3:2.
 await shoot(3840,2560,scene(3840,2560,{x:240,iconTop:620,icon:400,titleTop:1100,title:195,subTop:1340,sub:100,bodyTop:1510,bodyW:1300,body:74,
   shotLeft:1760,shotTop:680,shotW:2600,border:14,radius:48}),'store/ios/creative/search.png');
 await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});
