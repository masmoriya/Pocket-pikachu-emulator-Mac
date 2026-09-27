// Reproducible first color pass. Explicit masks remain editable per source frame.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {applyAuthoredColors} from './authored-frame-colors.mjs';
import {applySceneColors} from './scene-colors.mjs';
import {applyDetailColors} from './detail-colors.mjs';
import {applyFinalColors} from './final-frame-colors.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const frames=JSON.parse(fs.readFileSync(path.join(root,'mac/Sources/PocketPikachu/Resources/animations.json'))).frames;
const corrections=JSON.parse(fs.readFileSync(path.join(root,'art/color-corrections.json'),'utf8'));
const masks={};
const neighbors=p=>[p-36,p+36,...(p%36>0?[p-1]:[]),...(p%36<35?[p+1]:[])].filter(n=>n>=0&&n<1080);
const floodNeighbors=p=>[...neighbors(p),...[-37,-35,35,37].map(n=>p+n).filter(n=>n>=0&&n<1080&&Math.abs(n%36-p%36)===1)];
for(const frame of frames.filter(f=>f.category==='character')) {
 const ink=new Set(frame.pixels), barrier=new Set(ink), group=frame.id.split('.')[0];
 // Close short cropped sprite contours, but leave broad scene edges open so
 // furniture, characters, and props cannot become one large filled region.
 const visited = new Set();
 for (const point of ink) if (!visited.has(point)) {
  const component=[], queue=[point]; visited.add(point);
  while(queue.length) {const p=queue.pop();component.push(p);for(const n of floodNeighbors(p))if(ink.has(n)&&!visited.has(n)){visited.add(n);queue.push(n);}}
  for (const side of ['bottom','left','right']) {
   const edge=component.filter(p=>side==='bottom'?p>=1044:side==='left'?p%36===0:p%36===35);
   if(edge.length<2)continue;
   const values=edge.map(p=>side==='bottom'?p%36:Math.floor(p/36));
   const low=Math.min(...values),high=Math.max(...values);
   if(high-low>((['horn','rollingBall','flyingKite'].includes(group)||group==='study'&&side==='left'&&high<=14)?29:10))continue;
   for(let n=low;n<=high;n++)barrier.add(side==='bottom'?1044+n:side==='left'?n*36:n*36+35);
  }
 }
 // Front-facing close-ups crop the torso and disconnected leg strokes at the
 // bottom. Seal that authored silhouette across the crop, including the gaps
 // between legs; the generic short-component closure cannot identify it.
 if(group==='standLove') {
  const bottom=[...ink].filter(p=>p>=1044).map(p=>p%36);
  for(let x=Math.min(...bottom);x<=Math.max(...bottom);x++)barrier.add(1044+x);
 }
 const exterior=new Set(),pending=[];
 for(let i=0;i<1080;i++)if((i<36||i>=1044||i%36===0||i%36===35)&&!barrier.has(i)){exterior.add(i);pending.push(i);}
 while(pending.length)for(const n of neighbors(pending.pop()))if(!barrier.has(n)&&!exterior.has(n)){exterior.add(n);pending.push(n);}
 const colors=new Map(frame.pixels.map(p=>[p,'ink']));
 for(let p=0;p<1080;p++)if(!ink.has(p)&&!exterior.has(p))colors.set(p,'fur');
 const paint=(rect,color,onlyFill=true)=>{
  const [x1,y1,x2,y2]=rect;
  for(let y=y1;y<=y2;y++)for(let x=x1;x<=x2;x++){
   const p=y*36+x;
   if(colors.has(p)&&(!onlyFill||!ink.has(p)))colors.set(p,color);
  }
 };
 // Prop palettes share bounds across choreography to avoid per-frame color flicker.
 const props={
  eating:[[[0,26,35,29],'brown'],[[0,19,9,23],'white']],
  brushTeeth:[[[0,23,35,29],'blue']],
  letter:[[[0,24,19,29],'brown'],[[4,19,17,23],'white']],
  study:[[[0,23,18,29],'brown'],[[3,17,15,22],'white']],
  reading:[[[8,16,16,28],'white']],
  computer:[[[0,0,11,21],'blue'],[[0,22,17,29],'brown']],
  sandcastle:[[[0,0,18,29],'brown']],
  watchTV:[[[0,17,14,29],'blue']],
  buildingBlocks:[[[0,0,17,29],'blue']],
  rollingBall:[[[0,16,35,29],'blue']],
  sleep:[[[0,21,35,29],'white'],[[2,22,33,27],'green']],
 };
 for(const [rect,color] of props[group]??[])paint(rect,color);
 if(group==='licking')paint([0,13,11,25],frame.id.startsWith('licking.ice')?'pink':'cheek');
 // Locate paired cheek squares in front-facing source drawings. Preserve dark eyes.
 const components=[],seen=new Set();
 for(const p of ink)if(!seen.has(p)){
  const todo=[p],component=[];seen.add(p);
  while(todo.length){const q=todo.pop();component.push(q);for(const n of neighbors(q))if(ink.has(n)&&!seen.has(n)){seen.add(n);todo.push(n);}}
  const xs=component.map(p=>p%36),ys=component.map(p=>Math.floor(p/36));
  components.push({points:component,x:Math.min(...xs),y:Math.min(...ys),w:Math.max(...xs)-Math.min(...xs)+1,h:Math.max(...ys)-Math.min(...ys)+1});
 }
 const squares=components.filter(c=>c.w===2&&c.h===2&&c.points.length===4&&c.y<22);
 for(const a of squares)for(const b of squares)if(a.x<b.x&&a.y===b.y&&b.x-a.x>=7&&b.x-a.x<=13){
  const eyePair=components.some(c=>c.x>=a.x&&c.x<=a.x+2&&c.y>=a.y-5&&c.y<a.y-1&&c.w<=3&&c.h<=4);
  if(eyePair)for(const p of [...a.points,...b.points])colors.set(p,'cheek');
 }
 // Side views have one source pixel for a cheek. Recolor a nearby existing
 // ink pixel below the eye; never grow a cheek into neighboring fur pixels.
 const sideGroups=['standBasic','walk','letter','piano','diving','horn','licking','study','flyingKite','yoyo','computer','sandcastle','reading','bath','watchTV'];
 if(sideGroups.includes(group)) {
  const eyes=components.filter(c=>c.w<=2&&c.h<=2&&c.points.length<=4&&c.y<26&&c.points.some(p=>neighbors(p).filter(n=>colors.get(n)==='fur').length>=3)).sort((a,b)=>a.y-b.y);
  if(eyes.length) {
   const eye=eyes[0], fur=[...colors].filter(([_,color])=>color==='fur').map(([p])=>p%36);
   const direction=eye.x<fur.reduce((a,b)=>a+b,0)/Math.max(1,fur.length)?1:-1;
   const candidates=components.filter(c=>c.points.length<=2&&c.y>=eye.y+1&&c.y<=eye.y+5&&Math.abs(c.x-eye.x)<=4)
    .flatMap(c=>c.points).filter(p=>neighbors(p).filter(n=>colors.get(n)==='fur').length>=2)
    .sort((a,b)=>Math.abs(a%36-(eye.x+direction))+Math.abs(Math.floor(a/36)-(eye.y+2))-Math.abs(b%36-(eye.x+direction))-Math.abs(Math.floor(b/36)-(eye.y+2)));
   if(candidates.length)colors.set(candidates[0],'cheek');
  }
 }
 // The ball animation keeps Pikachu's face at a fixed source pixel while the
 // ball moves. Recolor only that source pixel when present in each mirrored pose.
 if(group==='rollingBall') {
  const x=frame.id.includes('rollingRight')?18:17, cheekPixel=7*36+x;
  if(ink.has(cheekPixel))colors.set(cheekPixel,'cheek');
 }
 applyAuthoredColors(frame, colors, frames);
 applySceneColors(frame, colors, frames);
 applyDetailColors(frame, colors);
 applyFinalColors(frame, colors);
 // User-authored shape and pixel corrections take precedence over pose heuristics.
 for(const [key,override] of Object.entries(corrections))if(frame.id===key||key.endsWith('.*')&&frame.id.startsWith(key.slice(0,-1))){
  for(const {rect,color,ink:includeInk=false} of override.regions??[])paint(rect,color,!includeInk);
  for(const [color,points] of Object.entries(override.pixels??{}))for(const p of points){
   if(color==='cheek')for(const [old,existing] of colors)if(existing==='cheek'){
    if(ink.has(old))colors.set(old,'ink');else colors.delete(old);
   }
   colors.set(p,color);
  }
 }
 const output={};for(const [p,color]of colors)(output[color]??=[]).push(p);
 masks[frame.id]=output;
}
fs.writeFileSync(path.join(root,'art/color-masks.json'),JSON.stringify(masks));
if(!fs.existsSync(path.join(root,'art/review.json'))) fs.writeFileSync(path.join(root,'art/review.json'),JSON.stringify({version:1,status:'First color pass; individual approval pending',frames:frames.filter(f=>f.category==='character').map(f=>({id:f.id,reviewed:false}))},null,2));
console.log(`Authored ${Object.keys(masks).length} color masks.`);
