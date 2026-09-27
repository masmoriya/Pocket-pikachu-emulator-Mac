import assert from 'node:assert/strict';

// Validate entire semantic regions, using source contours as their boundary.
export function validateSceneColors(frames, masks) {
  const point = (x,y) => y * 36 + x;
  const palette = id => new Map(Object.entries(masks[id]).flatMap(([c,ps]) => ps.map(p => [p,c])));
  const adjacent = p => [p-36,p+36,...(p%36 ? [p-1] : []),...(p%36<35 ? [p+1] : [])];
  const region = (id, seed, color, minimum) => {
    const ink = new Set(frames.get(id).pixels), colors = palette(id);
    const queue = [point(...seed)], seen = new Set(queue);
    assert(!ink.has(queue[0]) && colors.has(queue[0]), `Missing region: ${id} ${seed}`);
    while (queue.length) for (const n of adjacent(queue.pop())) {
      if (colors.has(n) && !ink.has(n) && !seen.has(n)) {seen.add(n); queue.push(n);}
    }
    assert(seen.size >= minimum, `Incomplete contour: ${id} ${seed}`);
    for (const p of seen) assert.equal(colors.get(p), color, `Mixed region: ${id} ${seed}`);
  };
  for (const frame of frames.values()) {
    if (!masks[frame.id]) continue;
    const colors = palette(frame.id), ink = new Set(frame.pixels);
    if (frame.id.startsWith('start.') || ['standLeft','letter.letter'].includes(frame.id)) {
      const ball = /Giggle|Gigle/.test(frame.id);
      for (const p of ink) {
        const redTop = ball && p >= 18 * 36 && p < 22 * 36 && colors.get(p) === 'cheek';
        if (!redTop) assert.equal(colors.get(p), 'ink', `Changed letter/outline: ${frame.id}`);
      }
      if (ball) assert((masks[frame.id].cheek?.length ?? 0) > 15, `Missing red hemisphere: ${frame.id}`);
      for (const [p,c] of colors) if (!ink.has(p)) {
        assert(ball && p >= 16 * 36, `Filled text counter: ${frame.id}`);
        assert.equal(c, 'white', `Poké Ball base: ${frame.id}`);
      }
      if (ball) assert((masks[frame.id].white?.length ?? 0) > 50);
    }
    if (frame.id.startsWith('standLove.')) {
      const top = frame.id.includes('hello') ? 15 : 17;
      for (const x of [11,12,23,24]) for (const y of [top,top+1]) {
        assert.equal(colors.get(point(x,y)), 'cheek', `Incomplete cheek square: ${frame.id}`);
      }
      assert.equal(masks[frame.id].cheek.length, 8);
    }
    if (/^(diving|horn|flyingKite|rollingBall)\./.test(frame.id)) {
      assert((masks[frame.id].cheek?.length ?? 0) <= 1, `Extra cheek: ${frame.id}`);
      for (const p of masks[frame.id].cheek ?? []) {
        assert(ink.has(p));
        assert(adjacent(p).every(n => colors.get(n) === 'fur'), `Cheek off face: ${frame.id}`);
      }
    }
    if (frame.id.startsWith('bath.shower')) {
      for (const [p,c] of colors) if (!ink.has(p) && p % 36 <= 8) {
        assert.equal(c, 'ink', `Hardware interior: ${frame.id}`);
      }
      assert.equal(colors.get(point(2,25)), 'ink', `Tap: ${frame.id}`);
      assert.equal(colors.get(point(4,3)), 'ink', `Shower head: ${frame.id}`);
      assert.equal(masks[frame.id].cheek?.length, 1, `Shower cheek: ${frame.id}`);
      assert(masks[frame.id].blue.length > 10, `Missing water: ${frame.id}`);
    }
    if (frame.id.startsWith('bath.bath')) {
      region(frame.id, [10,18], 'blue', 50);
      region(frame.id, [10,21], 'blue', 30);
      region(frame.id, [12,24], 'white', 100);
    }
    if (frame.id.startsWith('study.')) {
      region(frame.id, [16,18], 'white', 10);
      region(frame.id, [10,26], 'brown', 10);
      region(frame.id, [25,27], 'brown', 5);
      if (/Maths|English/.test(frame.id)) for (const p of masks[frame.id].fur ?? []) assert(p >= 11 * 36, `Yellow lesson text: ${frame.id}`);
    }
  }
  for (const id of ['piano.right','piano.left']) {
    const colors = palette(id);
    assert(!colors.has(point(18,10)), `Filled air beneath piano lid: ${id}`);
    region(id, [7,23], 'white', 2);
  }
  region('sleep.sideSleep', [15,18], 'green', 60);
  region('sleep.sideSleep', [22,16], 'fur', 30);
  for (const [id, seed] of Object.entries({goingToSleep:[6,22],enteringBed:[13,20],
    sideSleep2:[14,18],frontSleep:[16,18],frontSleep2:[15,18],backSleep:[17,17],backSleep2:[16,17]})) {
    region(`sleep.${id}`, seed, 'green', 30);
    assert(masks[`sleep.${id}`].white.length > 15, `Missing white bedding: ${id}`);
  }
  const diving = palette('diving.diving1');
  assert.equal(diving.get(point(9,17)), 'cheek');
  assert.equal(diving.get(point(11,18)), 'ink'); // Arm remains black.
  assert(!diving.has(point(18,29))); // Open fish-tail notch is alpha.
  region('diving.diving1', [12,3], 'blue', 4);
  assert.equal(diving.get(point(29,24)), 'blue');
  assert.equal(diving.get(point(15,27)), 'blue');
  assert.equal(palette('standMad.look').get(point(14,21)), 'cheek');
  assert(!palette('standMad.look').has(point(16,29)));
  region('horn.hornLeft9', [35,18], 'fur', 20);
  assert(!masks['horn.hornLeft22'].cheek, 'Tail-only crop has no cheek');
}
