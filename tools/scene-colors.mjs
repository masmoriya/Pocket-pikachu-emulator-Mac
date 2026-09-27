// Object palettes follow the enclosed source contours, including their holes.
// Coordinates are authoring seeds, not screen-space annotation positions.
const point = (x, y) => y * 36 + x;
const neighbors = p => [p - 36, p + 36,
  ...(p % 36 ? [p - 1] : []), ...(p % 36 < 35 ? [p + 1] : [])];

export function fill(colors, ink, [x, y], color) {
  const seed = point(x, y), seen = new Set([seed]), queue = [seed];
  if (!colors.has(seed) || ink.has(seed)) throw new Error(`Invalid scene region ${x},${y}`);
  while (queue.length) {
    const p = queue.pop();
    for (const n of neighbors(p)) if (colors.has(n) && !ink.has(n) && !seen.has(n)) {
      seen.add(n); queue.push(n);
    }
  }
  for (const p of seen) color ? colors.set(p, color) : colors.delete(p);
}

const beds = {
  goingToSleep: {cover: [6,22], fur: [[23,15],[21,16],[27,18]]},
  enteringBed: {cover: [13,20], fur: [[21,11],[27,16],[24,24]]},
  sideSleep: {cover: [15,18], fur: [[22,16],[29,17],[22,22]]},
  sideSleep2: {cover: [14,18], fur: [[22,16],[21,20],[22,23]]},
  frontSleep: {cover: [16,18], fur: [[22,16],[19,18]]},
  frontSleep2: {cover: [15,18], fur: [[23,16],[18,18]]},
  backSleep: {cover: [17,17], fur: [[23,15],[21,16],[24,16]]},
  backSleep2: {cover: [16,17], fur: [[22,15],[20,16],[23,16],[25,17]]},
};

function faceCheek(colors, ink, direction = 1) {
  for (const [p, color] of colors) if (color === 'cheek') colors.set(p, 'ink');
  const surrounded = p => neighbors(p).filter(n => colors.get(n) === 'fur').length === 4;
  const eyes = [...ink].filter(p => Math.floor(p / 36) < 24 && surrounded(p))
    .sort((a, b) => direction * (a % 36 - b % 36) || a - b);
  for (const eye of eyes) {
    const cheek = eye + 72 + direction;
    if (ink.has(cheek) && surrounded(cheek)) {
      colors.set(cheek, 'cheek');
      return [cheek % 36, Math.floor(cheek / 36)];
    }
  }
  return null;
}

export function applySceneColors(frame, colors) {
  const ink = new Set(frame.pixels), id = frame.id;
  if (id.startsWith('sleep.')) {
    // The duvet is a sloped contour, not a horizontal stripe across Pikachu.
    const bed = beds[id.split('.')[1]];
    for (const p of colors.keys()) if (!ink.has(p)) colors.set(p, 'white');
    fill(colors, ink, bed.cover, 'green');
    for (const seed of bed.fur) fill(colors, ink, seed, 'fur');
  }
  if (id.startsWith('bath.bath')) {
    // One connected pool includes the foam humps above the rim.
    for (const p of colors.keys()) if (!ink.has(p) && Math.floor(p / 36) >= 18) colors.set(p, 'white');
    fill(colors, ink, [10,18], 'blue');
    fill(colors, ink, [10,21], 'blue');
  }
  if (id.startsWith('bath.shower')) {
    // Follow the connected pipe, tap and head. Detached drops retain blue.
    const queue = [point(0,11)], hardware = new Set(queue);
    while (queue.length) {
      const p = queue.pop();
      for (const dy of [-1,0,1]) for (const dx of [-1,0,1]) {
        const x = p % 36 + dx, y = Math.floor(p / 36) + dy, n = point(x,y);
        if (x >= 0 && x <= 8 && y >= 0 && y < 30 && ink.has(n) && !hardware.has(n)) {
          hardware.add(n); queue.push(n);
        }
      }
    }
    for (const p of hardware) colors.set(p, 'ink');
    for (const p of colors.keys()) if (!ink.has(p) && p % 36 <= 8) colors.set(p, 'ink');
  }
  if (id.startsWith('piano.')) {
    const right = id === 'piano.right';
    fill(colors, ink, [18,10], null); // Air below the raised grand-piano lid.
    fill(colors, ink, right ? [8,18] : [26,18], 'fur'); // Tail interior.
    if (right) fill(colors, ink, [11,17], null);
    fill(colors, ink, [7,23], 'white');
    fill(colors, ink, right ? [24,23] : [27,23], 'white');
  }
  if (id.startsWith('study.')) {
    fill(colors, ink, [16,18], 'white'); // Open book.
    for (const seed of [[10,24],[10,26],[25,27]]) fill(colors, ink, seed, 'brown');
    faceCheek(colors, ink);
    for (const p of colors.keys()) if (!ink.has(p) && Math.floor(p / 36) < 13) colors.set(p, 'white');
  }
  if (id.startsWith('diving.')) {
    faceCheek(colors, ink);
    // Detached bubbles sit above the swimmer; fish pupils sit below it.
    for (const [p, color] of colors) if (!ink.has(p)) {
      const x = p % 36, y = Math.floor(p / 36);
      if (y >= 23) {
        if (y === 29) colors.delete(p); else colors.set(p, 'blue');
      } else if (y < 9 && x < 23 && color === 'fur') colors.set(p, 'blue');
    }
  }
  if (id.startsWith('horn.')) {
    const direction = /Right/.test(id) ? -1 : 1;
    const cheek = faceCheek(colors, ink, direction);
    if (cheek) for (const dy of [2,5]) for (let dx = 4; dx <= 8; dx++) {
      const x = cheek[0] + direction * dx, y = cheek[1] + dy;
      if (x >= 0 && x < 36 && ink.has(point(x,y))) colors.set(point(x,y), 'brown');
    }
  }
  if (id.startsWith('standMad.')) {
    faceCheek(colors, ink, -1);
    // The gap between the feet is exterior, even when the sole closes it.
    for (const x of [16,17]) if (!ink.has(point(x,29))) colors.delete(point(x,29));
  }
  if (/^(flyingKite|rollingBall|yoyo)\./.test(id)) {
    const direction = /Right/.test(id) ? -1 : 1;
    const cheek = faceCheek(colors, ink, direction);
    if (cheek) for (let dy = 2; dy <= 5; dy++) {
      const row = [];
      for (let dx = 3; dx <= 8; dx++) {
        const x = cheek[0] + direction * dx, y = cheek[1] + dy;
        if (x >= 0 && x < 36 && ink.has(point(x,y))) row.push(point(x,y));
      }
      // Back stripes are horizontal strokes, never a lone outline pixel.
      for (const p of row) if (row.includes(p - 1) || row.includes(p + 1)) colors.set(p, 'brown');
    }
  }
  if (id.startsWith('start.') || id === 'standLeft' || id === 'letter.letter') {
    const ball = id === 'start.leftGiggle' || id === 'start.rightGigle';
    for (const [p] of colors) {
      if (ink.has(p)) colors.set(p, 'ink');
      else if (ball && Math.floor(p / 36) >= 16) colors.set(p, 'white');
      else colors.delete(p);
    }
  }
}
