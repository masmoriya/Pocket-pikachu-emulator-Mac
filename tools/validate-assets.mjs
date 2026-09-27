import fs from 'node:fs';
import assert from 'node:assert/strict';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateColorArt} from './validate-color-art.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const library=JSON.parse(fs.readFileSync(path.join(root,'mac/Sources/PocketPikachu/Resources/animations.json')));
const original=JSON.parse(fs.readFileSync(path.join(root,'anims.json')));
const masks=JSON.parse(fs.readFileSync(path.join(root,'art/color-masks.json')));
const source=new Map();
function flatten(value,id='') {
 if(Array.isArray(value)&&value.every(p=>typeof p==='string'))source.set(id,value.map(p=>Number(p.slice(4))));
 else for(const [key,child] of Object.entries(value))flatten(child,id?`${id}.${key}`:key);
}
flatten(original);
assert.equal(library.sourceFrameCount,source.size);
assert.equal(new Set(library.frames.map(f=>f.id)).size,library.frames.length);
const frames=new Map(library.frames.map(f=>[f.id,f]));
for(const [id,pixels]of source){
 assert.deepEqual(frames.get(id).sourcePixels,pixels,`Source frame changed: ${id}`);
 assert.deepEqual(frames.get(id).pixels,[...new Set(pixels.filter(p=>p>=0&&p<1080))]);
}
for(const clip of library.clips){
 assert(clip.steps.length>0,clip.id);assert(clip.loopStart>=0&&clip.loopStart<clip.steps.length);
 for(const step of clip.steps){assert(frames.has(step.frame));assert(step.duration>0&&Number.isFinite(step.duration));}
}
for(const frame of library.frames.filter(f=>f.category==='character')){
 assert(masks[frame.id],`Missing color mask: ${frame.id}`);
 const colored=new Set(Object.values(masks[frame.id]).flat());
 for(const pixel of frame.pixels)assert(colored.has(pixel),`Lost source pixel in ${frame.id}`);
 for(const pixel of colored)assert(Number.isInteger(pixel)&&pixel>=0&&pixel<1080);
}
// Regression: cropped front-facing poses must have opaque fur, while the
// background remains transparent. Check every tail and greeting variant.
for(const frame of library.frames.filter(f=>f.id.startsWith('standLove.'))) {
 const fur=new Set(masks[frame.id].fur);
 assert(fur.has(12*36+18), `Transparent face: ${frame.id}`);
 assert(fur.has(29*36+18), `Transparent cropped torso: ${frame.id}`);
 assert(!Object.values(masks[frame.id]).flat().includes(0), `Filled background: ${frame.id}`);
}
assert.equal(library.clips.find(c=>c.id==='loveHello').steps.reduce((s,f)=>s+f.duration,0),2);
validateColorArt(frames,masks);
console.log(`${source.size} exact source frames, ${library.clips.length} valid clips, ${Object.keys(masks).length} complete color masks.`);
