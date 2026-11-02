/* Render the Play listing icon, feature graphic and Android launcher icons from the
   game's own artwork with Playwright. Nearest-neighbour scaling keeps the pixel art
   crisp. Outputs: store/android/images/{icon,feature}.png and game/assets/android/. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||require('node:path').join(__dirname,'../.tools/deploy/node_modules/playwright'));
const fs=require('node:fs/promises'), path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=async p=>'data:image/png;base64,'+(await fs.readFile(path.join(root,p))).toString('base64');
(async()=>{
 const icon=await read('game/assets/icon.png');
 const gameplay=await read('website/assets/gameplay.png');
 const font=(await fs.readFile(path.join(root,'website/assets/PixelifySans.ttf'))).toString('base64');
 const css=`@font-face{font-family:P;src:url(data:font/ttf;base64,${font})}html,body{margin:0;background:transparent}img{image-rendering:pixelated}`;
 const browser=await chromium.launch({headless:true});
 const shoot=async(w,h,html,out,transparent)=>{
  const page=await browser.newPage({viewport:{width:w,height:h},deviceScaleFactor:1});
  await page.setContent(`<!doctype html><style>${css}</style>${html}`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(100);
  await fs.mkdir(path.dirname(path.join(root,out)),{recursive:true});
  await page.screenshot({path:path.join(root,out),omitBackground:!!transparent});await page.close();console.log('wrote',out);
 };
 // Play icon: 512x512, no alpha, full-bleed artwork on the game's ink colour.
 await shoot(512,512,`<div style="width:512px;height:512px;background:#131c26;display:grid;place-items:center"><img src="${icon}" width="512" height="512"></div>`,'store/android/images/icon.png');
 // Feature graphic: 1024x500, wordmark and tagline beside the gameplay capture.
 await shoot(1024,500,`<div style="width:1024px;height:500px;background:linear-gradient(135deg,#131c26 0%,#1d3a2e 100%);position:relative;overflow:hidden;font-family:P,sans-serif;color:#f4edd7">
  <img src="${gameplay}" style="position:absolute;right:-60px;top:40px;height:420px;border:4px solid #42564f;border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.6);image-rendering:auto">
  <img src="${icon}" style="position:absolute;left:48px;top:52px;width:112px;height:112px;border-radius:24px">
  <div style="position:absolute;left:48px;top:184px;font-size:64px;font-weight:600;line-height:1">Purrimeter</div>
  <div style="position:absolute;left:50px;top:258px;font-size:28px;color:#89dfb5">The Garden Guard</div>
  <div style="position:absolute;left:50px;top:318px;width:380px;font-family:'Avenir Next','Segoe UI',sans-serif;font-size:21px;line-height:1.4;color:#b0c3bd">Build a maze with claws. Endless cat tower defence, solo or with two friends.</div>
  <div style="position:absolute;left:50px;top:420px;font-family:'Avenir Next','Segoe UI',sans-serif;font-size:16px;color:#ffc46b">Free · No ads · No account</div>
 </div>`,'store/android/images/feature.png');
 // Android launcher icons: legacy 192 and adaptive 432 layers (foreground centred in the 66% safe zone).
 await shoot(192,192,`<img src="${icon}" width="192" height="192" style="display:block">`,'game/assets/android/icon_192.png');
 await shoot(432,432,`<div style="width:432px;height:432px;display:grid;place-items:center"><img src="${icon}" width="264" height="264" style="border-radius:40px"></div>`,'game/assets/android/adaptive_foreground.png',true);
 await shoot(432,432,`<div style="width:432px;height:432px;background:#131c26"></div>`,'game/assets/android/adaptive_background.png');
 await browser.close();
})().catch(e=>{console.error(e);process.exitCode=1});
