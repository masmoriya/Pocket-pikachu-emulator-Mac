import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const destination = path.join(root,'mac/Sources/PocketPikachu/Resources');
const library = JSON.parse(fs.readFileSync(path.join(destination,'animations.json'),'utf8'));
const palette = {ink:[43,35,28,255],fur:[250,207,52,255],cheek:[222,66,42,255],brown:[144,83,42,255],white:[255,255,255,255],blue:[100,181,218,255],green:[110,153,87,255],teal:[36,119,124,255],pink:[237,142,163,255]};
const masksPath = path.join(root,'art/color-masks.json');
const masks = fs.existsSync(masksPath) ? JSON.parse(fs.readFileSync(masksPath,'utf8')) : {};
function crc32(data) { let crc = -1; for (const byte of data) { crc ^= byte; for(let k=0;k<8;k++) crc=(crc>>>1)^((crc&1)?0xedb88320:0); } return (crc^-1)>>>0; }
function chunk(name,data) { const n=Buffer.from(name), len=Buffer.alloc(4), crc=Buffer.alloc(4); len.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([n,data]))); return Buffer.concat([len,n,data,crc]); }
function png(width,height,pixels) {
 const header=Buffer.alloc(13); header.writeUInt32BE(width);header.writeUInt32BE(height,4);header[8]=8;header[9]=6;
 const rows=Buffer.alloc(height*(width*4+1)); for(let y=0;y<height;y++) pixels.copy(rows,y*(width*4+1)+1,y*width*4,(y+1)*width*4);
 return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(rows)),chunk('IEND',Buffer.alloc(0))]);
}
function enclosed(ink) {
 const outside=new Set(), queue=[];
 for(let i=0;i<1080;i++) if ((i<36||i>=1044||i%36===0||i%36===35)&&!ink.has(i)) { outside.add(i);queue.push(i); }
 while(queue.length) { const p=queue.pop(); for(const n of [p-36,p+36,...(p%36>0?[p-1]:[]),...(p%36<35?[p+1]:[])]) if(n>=0&&n<1080&&!ink.has(n)&&!outside.has(n)){outside.add(n);queue.push(n);} }
 return Array.from({length:1080},(_,i)=>i).filter(i=>!ink.has(i)&&!outside.has(i));
}
// Color masks are explicit pixel memberships. Unreviewed interiors get a conservative
// draft fill; art/review.json records approval separately, never claiming a tint is finished art.
function raster(frame,colored) {
 const pixels=Buffer.alloc(36*30*4), ink=new Set(frame.pixels);
 for(const p of ink) pixels.set(palette.ink,p*4);
 if(!colored||frame.category!=='character') return pixels;
 const regions=masks[frame.id];
 if(regions) {
   for(const [color,points] of Object.entries(regions)) for(const p of points) {
     if(color==='transparent') pixels.fill(0,p*4,p*4+4);
     else pixels.set(palette[color]??palette.ink,p*4);
   }
 } else {
   for(const p of enclosed(ink)) pixels.set(palette.fur,p*4);
 }
 return pixels;
}
for(const colored of [false,true]) {
 const width=16*36,height=Math.ceil(library.frames.length/16)*30, pixels=Buffer.alloc(width*height*4);
 library.frames.forEach((frame,index)=>{
  const data=raster(frame,colored), x=index%16*36,y=Math.floor(index/16)*30;
  for(let row=0;row<30;row++) data.copy(pixels,((y+row)*width+x)*4,row*36*4,(row+1)*36*4);
 });
fs.writeFileSync(path.join(destination,`${colored?'color':'mono'}-atlas.png`),png(width,height,pixels));
}
// Native app icon uses the affectionate hello pose from the same reviewed sprite source.
const iconFrame=library.frames.find(frame=>frame.id==='standLove.helloRight');
if(!iconFrame) throw new Error('Missing affectionate app icon frame: standLove.helloRight');
const iconSize=1024, spriteScale=22, icon=Buffer.alloc(iconSize*iconSize*4);
for(let y=0;y<iconSize;y++) for(let x=0;x<iconSize;x++) icon.set([45,70,104,255],(y*iconSize+x)*4);
const sprite=raster(iconFrame,true), offsetX=Math.floor((iconSize-36*spriteScale)/2), offsetY=Math.floor((iconSize-30*spriteScale)/2);
for(let y=0;y<30;y++) for(let x=0;x<36;x++) {
 const source=(y*36+x)*4;
 if(!sprite[source+3]) continue;
 for(let sy=0;sy<spriteScale;sy++) for(let sx=0;sx<spriteScale;sx++)
  icon.set(sprite.subarray(source,source+4),((offsetY+y*spriteScale+sy)*iconSize+offsetX+x*spriteScale+sx)*4);
}
fs.writeFileSync(path.join(root,'art/app-icon.png'),png(iconSize,iconSize,icon));
const groups = [...new Set(library.frames.filter(f=>f.category==='character').map(f=>f.id.split('.')[0]))];
const samples=groups.map(group=>library.frames.find(f=>f.id.split('.')[0]===group));
const width=6*216,height=Math.ceil(samples.length/6)*192,pixels=Buffer.alloc(width*height*4,255);
samples.forEach((frame,index)=>{ const data=raster(frame,true);for(let y=0;y<30;y++)for(let x=0;x<36;x++)for(let sy=0;sy<6;sy++)for(let sx=0;sx<6;sx++){
 const dst=((Math.floor(index/6)*192+y*6+sy)*width+index%6*216+x*6+sx)*4,src=(y*36+x)*4;
 if(data[src+3])data.copy(pixels,dst,src,src+4);
}});
fs.writeFileSync(path.join(root,'art/contact-sheet.png'),png(width,height,pixels));
fs.writeFileSync(path.join(root,'art/contact-sheet-index.json'),JSON.stringify(samples.map(f=>f.id),null,2));
console.log(`Built two atlases; ${Object.keys(masks).length} explicitly colored frames.`);
// Small, numbered review sheets cover every character frame, not just first poses.
const digits=['111101101101111','010110010010111','111001111100111','111001111001111','101101111001001','111100111001111','111100111101111','111001001001001','111101111101111','111101111001111'];
const characters=library.frames.filter(f=>f.category==='character');
for(let page=0;page<Math.ceil(characters.length/72);page++){
 const width=8*148,height=9*138,data=Buffer.alloc(width*height*4,255);
 characters.slice(page*72,(page+1)*72).forEach((frame,index)=>{
  const tileX=index%8*148,tileY=Math.floor(index/8)*138, rgba=raster(frame,true);
  for(let y=0;y<30;y++)for(let x=0;x<36;x++)for(let sy=0;sy<4;sy++)for(let sx=0;sx<4;sx++){
   const dst=((tileY+12+y*4+sy)*width+tileX+x*4+sx)*4,src=(y*36+x)*4;
   if(rgba[src+3])rgba.copy(data,dst,src,src+4);
  }
  for(const [i,d]of [...String(page*72+index)].entries())for(let y=0;y<5;y++)for(let x=0;x<3;x++)if(digits[Number(d)][y*3+x]==='1'){
   for(let sy=0;sy<2;sy++)for(let sx=0;sx<2;sx++)data.set([60,60,60,255],((tileY+y*2+sy)*width+tileX+i*8+x*2+sx)*4);
  }
 });
 fs.writeFileSync(path.join(root,`art/review-${page+1}.png`),png(width,height,data));
}
fs.writeFileSync(path.join(root,'art/review-index.json'),JSON.stringify(characters.map(f=>f.id),null,2));
