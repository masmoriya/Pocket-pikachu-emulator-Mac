import {fill} from './scene-colors.mjs';
const point = (x,y) => y * 36 + x;

export function applyDetailColors(frame, colors) {
  const id = frame.id, ink = new Set(frame.pixels);
  const rect = ([l,t,r,b], color, mode = 'ink') => {
    for (let y=t;y<=b;y++) for(let x=l;x<=r;x++) {
      const p=point(x,y);
      if (mode === 'ink' ? ink.has(p) : !ink.has(p) && (mode === 'add' || colors.has(p))) {
        color ? colors.set(p,color) : colors.delete(p);
      }
    }
  };
  const cheek = (x,y) => {
    for (const [p,c] of colors) if(c === 'cheek') colors.set(p, ink.has(p) ? 'ink' : 'fur');
    const p = point(x,y);
    if (!ink.has(p)) throw new Error(`Cheek is not a source mark: ${id} ${x},${y}`);
    colors.set(p,'cheek');
  };
  if (id === 'bath.shower1' || id === 'bath.shower2') cheek(18,18);
  if (id === 'bath.bathLook') cheek(22,15);
  if (id.startsWith('sandcastle.')) cheek(24,21);
  if (id.startsWith('reading.')) {
    cheek(20,22);
    if (id === 'reading.nextPage') {
      fill(colors,ink,[4,16],'white');
      fill(colors,ink,[7,19],'white');
    }
  }
  if (id.startsWith('watchTV.')) cheek(24,id === 'watchTV.jump' ? 20 : 23);
  if (id.startsWith('licking.')) {
    // Restore the whole connected arm/body, preserving the separate sweet.
    const body = [...colors].find(([p]) => !ink.has(p) && p%36 >= 14 && p%36 <= 22 && Math.floor(p/36) === 19);
    fill(colors,ink,[body[0]%36,19],'fur');
    if (id === 'licking.icecream1' || id === 'licking.icecream2') {
      const top = id.endsWith('1') ? 22 : 23;
      rect([4,top,9,29],'brown','fill');
    }
  }
  if (id.startsWith('study.')) {
    // The wooden interiors are brown; original outlines stay black.
    // The upper ear is Pikachu, even when it reaches into the lesson area.
    for (const [p,c] of colors) if (!ink.has(p) && c === 'white' && p%36>=26 && p%36<=29 && Math.floor(p/36)>=11) colors.set(p,'fur');
  }
  if (id === 'study.studyAskHistory') {
    fill(colors,ink,[0,1],'blue');
    fill(colors,ink,[21,1],'fur'); // Sun.
    for(const seed of [[14,5],[3,6],[11,9]]) fill(colors,ink,seed,'brown');
  }
  if (id === 'study.studyAnswerHistory') {
    // Fill the dotted thought illustration up to its curved source outline.
    for(const [y,l,r] of [[7,14,16],[8,12,18],[9,11,19],[10,10,20],[11,9,21],[12,8,21]]) rect([l,y,r,y],'blue','add');
    fill(colors,ink,[25,9],'fur');
  }
  if (id.startsWith('computer.')) {
    fill(colors,ink,[7,7],'white');
    rect([0,8,5,17],'white','add'); // Cropped screen.
    rect([0,19,8,22],'white','add'); // Lower casing and keys.
    fill(colors,ink,[12,22],'white'); // Keyboard beside the hand.
    for(const [p,c] of colors) if(c === 'brown' && p%36>=16 && Math.floor(p/36)<25 && !ink.has(p)) colors.set(p,'fur');
    rect([0,24,15,24],'brown','add'); // Solid desktop between its edges.
    rect([22,18,27,18],'brown');
    rect([21,21,27,21],'brown');
    fill(colors,ink,[18,26],'brown');
  }
  if(id.startsWith('yoyo.')) {
    // The second back stripe moves between rows 19 and 20 with the pose.
    for(let y=19;y<=20;y++) {
      const row=[];
      for(let x=21;x<=27;x++) if(ink.has(point(x,y)))row.push(point(x,y));
      for(const p of row) if(row.includes(p-1)||row.includes(p+1))colors.set(p,'brown');
    }
    if(id === 'yoyo.yoyo3') fill(colors,ink,[15,21],null);
  }
  if(id.startsWith('buildingBlocks.')) {
    fill(colors,ink,id === 'buildingBlocks.try' ? [21,11] : [25,10],'fur');
    fill(colors,ink,[5,23],null); // Space between the two levels of blocks.
    if(id === 'buildingBlocks.try') fill(colors,ink,[7,18],null);
    for(const [p,c] of colors) if(c === 'blue' && !ink.has(p) && p%36>=16 && Math.floor(p/36)===16) colors.set(p,'fur');
  }
  if(id.startsWith('brushTeeth.')) fill(colors,ink,[8,5],'fur');
}
