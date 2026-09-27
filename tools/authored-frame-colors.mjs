// Pose-specific art. Coordinates refer to the original 36 × 30 source pixels.
// Flood regions follow ink contours; transparent regions remain actual alpha.
const width = 36, count = 1080;
const point = (x, y) => y * width + x;
const neighbors = p => [p - width, p + width,
  ...(p % width ? [p - 1] : []), ...(p % width < 35 ? [p + 1] : [])
].filter(p => p >= 0 && p < count);

function enclosed(frame, bottom) {
  const ink = new Set(frame.pixels), barrier = new Set(ink);
  if (bottom) for (let x = bottom[0]; x <= bottom[1]; x++) barrier.add(point(x, 29));
  const outside = new Set(), queue = [];
  for (let p = 0; p < count; p++) {
    if ((p < 36 || p >= 1044 || p % 36 === 0 || p % 36 === 35) && !barrier.has(p)) {
      outside.add(p); queue.push(p);
    }
  }
  while (queue.length) for (const n of neighbors(queue.pop())) {
    if (!barrier.has(n) && !outside.has(n)) { outside.add(n); queue.push(n); }
  }
  const result = new Map(frame.pixels.map(p => [p, 'ink']));
  for (let p = 0; p < count; p++) if (!ink.has(p) && !outside.has(p)) result.set(p, 'fur');
  return result;
}

function region(colors, ink, [x, y], color) {
  const seed = point(x, y);
  if (ink.has(seed) || !colors.has(seed)) throw new Error(`Invalid art region: ${x},${y}`);
  const seen = new Set([seed]), queue = [seed];
  while (queue.length) {
    const p = queue.pop();
    for (const n of neighbors(p)) if (!ink.has(n) && colors.has(n) && !seen.has(n)) {
      seen.add(n); queue.push(n);
    }
  }
  for (const p of seen) color === null ? colors.delete(p) : colors.set(p, color);
}

function inkRect(colors, ink, [left, top, right, bottom], color) {
  for (let y = top; y <= bottom; y++) for (let x = left; x <= right; x++) {
    const p = point(x, y);
    if (ink.has(p)) colors.set(p, color);
  }
}
function recolor(colors, from, to) {
  for (const [p, color] of colors) if (color === from) colors.set(p, to);
}
function clearCheeks(colors, ink) {
  for (const [p, color] of colors) if (color === 'cheek') {
    if (ink.has(p)) colors.set(p, 'ink'); else colors.delete(p);
  }
}

// Stripes include only the black source marks, never the fur beside them.
const stripes = {
  'standLike.left': [[18,18,22,19], [17,22,22,23]],
  'standLike.right': [[13,18,17,19], [13,22,18,23]],
  'standLike.backRight': [[13,18,22,19], [12,22,22,23]],
  'standLike.backLeft': [[13,18,22,19], [13,22,23,23]],
  'standLike.lookLeft': [[21,18,23,19], [22,22,24,23]],
  'standLike.lookRight': [[12,18,14,19], [11,22,13,23]],
  'standBasic.stand': [[19,21,22,21], [18,24,22,24]],
  'standBasic.look': [[19,21,22,21], [18,24,22,24]],
  'standBasic.extend': [[19,21,21,21], [18,24,21,24]],
};
const cheeks = {
  'standLike.left': [[12,15,12,16]],
  'standLike.right': [[23,15,23,16]],
  'standLike.lookLeft': [[16,14,17,15]],
  'standLike.lookRight': [[17,14,18,15]],
  'standBasic.stand': [[15,18,15,18]],
  'standBasic.look': [[17,18,17,18]],
  'standBasic.extend': [[15,18,15,18]],
  'tongueMad.start': [[12,15,13,16], [21,15,22,16]],
  'tongueMad.tongue1': [[11,15,12,16], [22,15,23,16]],
  'tongueMad.tongue2': [[10,16,11,17], [23,16,24,17]],
  'tongueMad.tongue3': [[10,17,11,18], [23,17,24,18]],
};

let glider;
function gliderTemplate(frames) {
  if (glider) return glider;
  const source = frames.find(f => f.id === 'flying.enter5');
  const ink = new Set(source.pixels);
  glider = enclosed(source);
  for (const [seed, color] of [
    [[19,8], 'blue'],       // Canopy, filled before it is cropped at the screen edge.
    [[24,7], 'white'],      // Trailing strip.
    [[17,16], 'brown'],     // Support pole above the hand.
    [[17,26], 'brown'],     // Support pole below the hand.
    [[20,16], null],        // Air between Pikachu's back and the canopy.
    [[15,18], null],        // Air beside the top of the head.
  ]) region(glider, ink, seed, color);
  inkRect(glider, ink, [12,23,12,23], 'cheek');
  return glider;
}

export function applyAuthoredColors(frame, colors, frames) {
  const ink = new Set(frame.pixels), id = frame.id;
  if (id.startsWith('flying.enter')) {
    const offset = [32,24,16,8,0,-8,-16,-24,-31][Number(id.slice('flying.enter'.length)) - 1];
    colors.clear();
    for (const [p, color] of gliderTemplate(frames)) {
      const x = p % 36 + offset;
      if (x >= 0 && x < 36) colors.set(point(x, Math.floor(p / 36)), color);
    }
    return;
  }
  if (id.startsWith('standLove.')) {
    const hello = id.includes('hello');
    const bottom = id.endsWith('helloLeft') ? [7,29] : id.endsWith('helloRight') ? [6,28] : [7,28];
    const filled = enclosed(frame, bottom);
    colors.clear(); for (const entry of filled) colors.set(...entry);
    for (const rect of hello ? [[11,15,12,16], [23,15,24,16]] : [[12,17,13,18], [23,17,24,18]]) {
      inkRect(colors, ink, rect, 'cheek');
    }
    if (hello) region(colors, ink, [17,18], 'pink');
    return;
  }
  if (id.startsWith('piano.')) {
    // The instrument and its key bed stay monochrome; the rectangle pass used
    // to tint the ears along with the piano.
    recolor(colors, 'brown', 'white');
    return;
  }
  if (id.startsWith('walk.')) {
    const cheek = id === 'walk.stand' ? [22,21] : [22,20];
    clearCheeks(colors, ink);
    inkRect(colors, ink, [...cheek, ...cheek], 'cheek');
    return;
  }
  if (id.startsWith('watchTV.')) {
    // Side views face left; the source cheek pixel sits below the eye on the
    // face, while automatic detection previously mistook tail pixels for it.
    const cheeks = id === 'watchTV.jump' ? [[24,21]] : [[20,22]];
    clearCheeks(colors, ink);
    for (const [x,y] of cheeks) inkRect(colors, ink, [x,y,x,y], 'cheek');
    return;
  }
  if (id.startsWith('reading.')) {
    // These are the hand pixels that touched the book in the broad white pass.
    for (const [x,y] of id === 'reading.nextPage' ? [[15,24],[16,24]] : [[16,24]]) {
      const p = point(x,y);
      if (colors.get(p) === 'white' && !ink.has(p)) colors.set(p, 'fur');
    }
    return;
  }
  if (id.startsWith('bath.shower')) {
    // Only the spray and water strokes are blue; retain the shower hardware's
    // black outline and avoid painting adjoining silhouettes.
    for (const p of frame.pixels) {
      const x = p % width, y = Math.floor(p / width);
      if (x <= 4 && (y <= 11 || y >= 23 && y <= 27)) colors.set(p, 'blue');
    }
    clearCheeks(colors, ink);
    const cheek = id === 'bath.shower1' ? [19,16] : [17,16];
    inkRect(colors, ink, [...cheek, ...cheek], 'cheek');
    return;
  }
  if (id.startsWith('bath.bath')) {
    // Bubbles are small filled marks above the bath. Keep the rim and body
    // monochrome, and ensure the pose's cheek stays at its original pixel.
    const cheek = id === 'bath.bath1' ? [19,15] : [16,15];
    clearCheeks(colors, ink);
    inkRect(colors, ink, [...cheek, ...cheek], 'cheek');
    // The bubbles are enclosed fur-colored cells above the character. Tint all
    // of those bounded cells together so no bubble flickers yellow between poses.
    for (const [p, color] of colors) {
      const x = p % width, y = Math.floor(p / width);
      if (color === 'fur' && x <= 15 && y <= 15) colors.set(p, 'blue');
    }
    // These horizontal rows are the bathtub's open waterline inside the black
    // rim. Pikachu's silhouette ends above it, so the enamel stays white.
    for (let y = 18; y <= 19; y++) for (let x = 5; x <= 31; x++) {
      const p = point(x,y);
      if (colors.get(p) === 'fur' && !ink.has(p)) colors.set(p, 'white');
    }
    return;
  }
  if (stripes[id] || id.startsWith('tongueMad.')) {
    for (const p of ink) colors.set(p, 'ink');
    for (const rect of stripes[id] ?? []) inkRect(colors, ink, rect, 'brown');
    for (const rect of cheeks[id] ?? []) inkRect(colors, ink, rect, 'cheek');
    if (id === 'tongueMad.tongue3') region(colors, ink, [16,20], 'pink');
    if (id === 'tongueMad.tongue2') {
      // The tongue interior is white in the source frame; recolor only the
      // small outlined tongue cells and leave the surrounding face untouched.
      for (const [x,y] of [[16,19],[18,19],[16,20],[18,20],[16,21],[17,21],[18,21]]) {
        if (!ink.has(point(x,y))) colors.set(point(x,y), 'pink');
      }
    }
    return;
  }
  if (id === 'letter.write1' || id === 'letter.write2') {
    for (const p of ink) colors.set(p, 'ink');
    region(colors, ink, [23,19], 'fur');
    region(colors, ink, [20,25], 'brown');
    region(colors, ink, [23,28], 'brown');
    region(colors, ink, [10,27], null); // Open space between the desk legs.
    inkRect(colors, ink, [23,20,23,20], 'cheek');
  }
  if (['eating.eatingToast','eating.nomnomToast','eating.nomnomToast2'].includes(id)) {
    // Toast interior at the mouth/tray is white; source ink remains untouched.
    const rect = [15,15,20,19];
    for (let y = rect[1]; y <= rect[3]; y++) for (let x = rect[0]; x <= rect[2]; x++) {
      const p = point(x,y);
      if (!ink.has(p) && colors.has(p)) colors.set(p, 'white');
    }
  }
  if (['eating.eatingOnigiri','eating.nonomOnigiri','eating.nonomOnigiri2',
       'eating.eatingChopsticks','eating.nomnomChopsticks','eating.nomnomChopsticks2',
       'eating.angryOnigiri'].includes(id)) {
    // Rice is white across the rice ball, including its open lower edge.
    for (let y = 16; y <= 23; y++) for (let x = 6; x <= 10; x++) {
      const p = point(x,y);
      if (!ink.has(p) && colors.has(p)) colors.set(p, 'white');
    }
  }
}
