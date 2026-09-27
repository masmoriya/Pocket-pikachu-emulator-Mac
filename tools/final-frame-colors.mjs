import {fill} from './scene-colors.mjs';
const point=(x,y)=>y*36+x;

// Object-specific finishes based on original/color comparisons.
export function applyFinalColors(frame,colors) {
  const id=frame.id, ink=new Set(frame.pixels);
  const clearCheeks=()=>{for(const [p,c]of colors)if(c==='cheek')colors.set(p,ink.has(p)?'ink':'fur');};
  const cheek=(x,y)=>{
    clearCheeks();
    if(!ink.has(point(x,y)))throw new Error(`Missing face mark ${id}: ${x},${y}`);
    colors.set(point(x,y),'cheek');
  };
  const interior=(x,y,c)=>{if(!ink.has(point(x,y)))colors.set(point(x,y),c);};
  if(id.startsWith('study.'))for(const x of [8,19])for(let y=26;y<=29;y++)interior(x,y,'brown');
  if(id.startsWith('letter.write'))for(const x of [8,19])for(let y=27;y<=29;y++)interior(x,y,'brown');
  if(id.startsWith('computer.'))for(let y=26;y<=29;y++)interior(12,y,'brown');
  if(id.startsWith('buildingBlocks.')) cheek(id==='buildingBlocks.try'?21:22,15);
  if(id.startsWith('brushTeeth.')) {
    fill(colors,ink,id.endsWith('1')?[17,15]:[16,15],'white');
    fill(colors,ink,id.endsWith('1')?[12,18]:[13,17],'white');
  }
  if(id==='bath.bath2')cheek(19,16);
  if(id.startsWith('piano.'))clearCheeks();
  if(id==='horn.hornLeft10')fill(colors,ink,[35,12],null);
  if(id==='horn.hornRight10')fill(colors,ink,[0,12],null);
  if(id.startsWith('walk.')) {
    // Letter counters in the floating Pika caption stay transparent.
    for(const p of colors.keys())if(!ink.has(p)&&Math.floor(p/36)<14)colors.delete(p);
  }
  if(id.startsWith('radioControl.')) {
    // The wheel arch is an opening at the bottom edge, not bodywork.
    for(const p of colors.keys())if(!ink.has(p)&&Math.floor(p/36)===29)colors.delete(p);
  }
  if(id==='licking.lollypopFall')for(let x=1;x<=6;x++)interior(x,29,'cheek');
  if(id==='licking.icecreamFall') {
    // The scoop is on the left of the fallen cone, cropped by the bottom edge.
    for(const [y,l,r]of [[26,5,5],[27,3,5],[28,1,5],[29,1,5]])for(let x=l;x<=r;x++)interior(x,y,'pink');
    fill(colors,ink,[7,27],'brown');
    fill(colors,ink,[9,28],'brown');
  }
  if(id.startsWith('heartSmiles.')&&id!=='heartSmiles.stand') {
    // The detached heart is the ink component above the head.
    const seed=frame.pixels.find(p=>Math.floor(p/36)<7&&(id.endsWith('loveRight')?p%36>=21:p%36<=12)), queue=[seed],seen=new Set(queue);
    while(queue.length){const p=queue.pop();for(const d of [-37,-36,-35,-1,1,35,36,37]){
      const n=p+d;if(ink.has(n)&&Math.abs(n%36-p%36)<=1&&!seen.has(n)){seen.add(n);queue.push(n);}
    }}
    for(const p of seen)colors.set(p,'cheek');
    const patches=id.endsWith('loveLeft')?[[19,13],[11,16]]:[[14,13],[22,16]];
    for(const [left,top]of patches)for(let y=top;y<top+2;y++)for(let x=left;x<left+2;x++) {
      if(!ink.has(point(x,y)))throw new Error(`Incomplete heart-pose cheek: ${id}`);
      colors.set(point(x,y),'cheek');
    }
  }
  if(id==='start.leftGiggle'||id==='start.rightGigle') {
    // Red hemisphere inside the black silhouette; keep the button and seam.
    for(const p of ink)if(p>=18*36&&p<22*36&&[p-36,p+36,p-1,p+1].every(n=>colors.has(n)))colors.set(p,'cheek');
  }
  if(id==='standLike.lookRight'||id==='standLike.lookLeft') {
    const left=id.endsWith('lookLeft')?16:18;
    for(let y=14;y<=15;y++)for(let x=left;x<=left+1;x++)if(ink.has(point(x,y)))colors.set(point(x,y),'cheek');
  }
  if(id==='standLove.helloLeft')colors.delete(point(8,15));
  if(id==='standLove.helloRight')colors.delete(point(27,15));
  if(['eating.eatingToast','eating.nomnomToast','eating.nomnomToast2'].includes(id)) {
    const body=id==='eating.eatingToast'?[9,2]:id==='eating.nomnomToast'?[8,3]:[8,2];
    fill(colors,ink,body,'fur');
    const bread=id==='eating.eatingToast'?[15,14]:id==='eating.nomnomToast'?[21,15]:[21,16];
    fill(colors,ink,bread,'white');
    fill(colors,ink,[13,23],'white');
  }
  if(id.includes('Chopsticks')) {
    const shift=id==='eating.nomnomChopsticks2'?1:0;
    fill(colors,ink,[17,15+shift],'white');
    fill(colors,ink,[14,19+shift],'white');
    fill(colors,ink,[11,23],'white');
    fill(colors,ink,[4,26],'brown');
  }
}
