import assert from 'node:assert/strict';
import {validateSceneColors} from './validate-scene-colors.mjs';
import {validateDetailColors} from './validate-detail-colors.mjs';
import {validateFinalColors} from './validate-final-colors.mjs';

// Pixel-level regressions from the original/color gallery comparisons.
// Alpha matters here: empty space must be absent, not painted white.
export function validateColorArt(frames, masks) {
  const at = (id, x, y) => Object.entries(masks[id])
    .find(([, points]) => points.includes(y * 36 + x))?.[0];
  const expect = (id, x, y, color) =>
    assert.equal(at(id, x, y), color, `${id} at ${x},${y}`);

  for (const frame of frames.values()) {
    const mask = masks[frame.id];
    if (!mask) continue;
    const points = Object.values(mask).flat();
    assert.equal(new Set(points).size, points.length, `Overlapping colors: ${frame.id}`);
    if (/^stand(Like|Basic)\./.test(frame.id)) {
      for (const p of mask.brown ?? []) {
        assert(frame.pixels.includes(p), `Stripe expanded into fur: ${frame.id}, ${p}`);
      }
    }
    if (/^(stand(Love|Like|Basic)|tongueMad|letter|flying)\./.test(frame.id)) {
      for (const p of mask.cheek ?? []) {
        assert(frame.pixels.includes(p),
          `Cheek added outside source mark: ${frame.id}, ${p}`);
      }
    }
  }

  expect('standLike.lookLeft', 16, 14, 'cheek');
  expect('standLike.lookLeft', 18, 18, 'fur');
  expect('standLike.left', 12, 15, 'cheek');
  expect('tongueMad.tongue2', 17, 14, 'fur');
  expect('tongueMad.tongue2', 16, 19, 'pink');
  expect('tongueMad.tongue3', 16, 23, 'pink');
  for (const id of ['letter.write1', 'letter.write2']) {
    expect(id, 23, 25, 'fur');
    expect(id, 24, 28, 'brown');
    expect(id, 10, 25, 'brown');
    expect(id, 10, 27, undefined);
    expect(id, 23, 20, 'cheek');
  }
  expect('flying.enter6', 7, 12, 'blue');
  expect('flying.enter6', 3, 22, 'fur');
  expect('flying.enter6', 9, 22, 'brown');
  expect('flying.enter6', 15, 16, undefined);
  for (const id of ['piano.right', 'piano.left']) {
    assert.equal((masks[id].brown ?? []).length, 0, `Piano should stay monochrome: ${id}`);
  }
  expect('piano.right', 21, 13, undefined);
  expect('piano.right', 18, 12, undefined);
  for (const id of ['walk.stand', 'walk.walking1', 'walk.walking2']) {
    assert.equal((masks[id].cheek ?? []).length, 1, `One cheek mark per side pose: ${id}`);
  }
  expect('walk.stand', 22, 21, 'cheek');
  expect('walk.stand', 29, 16, undefined);
  expect('watchTV.stand1', 24, 23, 'cheek');
  expect('watchTV.stand2', 24, 23, 'cheek');
  expect('watchTV.jump', 24, 20, 'cheek');
  expect('watchTV.jump', 26, 17, 'fur');
  expect('reading.sand1', 16, 24, 'fur');
  expect('reading.nextPage', 15, 24, 'fur');
  for (const id of ['reading.sand1', 'reading.sand2', 'reading.nextPage']) {
    expect(id, 20, 22, 'cheek');
    assert.equal(masks[id].cheek.length, 1, `One face cheek in reading pose: ${id}`);
  }
  expect('eating.eatingToast', 17, 17, 'white');
  expect('eating.angryToast', 2, 21, 'white');
  expect('eating.eatingOnigiri', 8, 21, 'white');
  expect('eating.angryOnigiri', 7, 21, 'white');
  expect('eating.eatingChopsticks', 7, 21, 'white');
  expect('bath.bath1', 19, 15, 'cheek');
  expect('bath.bath1', 20, 19, 'blue');
  expect('bath.bath1', 13, 12, 'blue');
  expect('bath.bath1', 4, 19, 'ink');
  expect('bath.bath1', 12, 21, 'blue');
  expect('bath.bath1', 2, 21, 'ink');
  expect('bath.bath1', 12, 24, 'white');
  expect('bath.shower1', 2, 15, 'ink');
  expect('bath.shower1', 10, 5, 'blue');
  for (const id of ['bath.shower1', 'bath.shower2', 'bath.showerLook']) {
    assert.equal(masks[id].fur.some(p => p % 36 <= 8 && Math.floor(p / 36) <= 4), false,
      `Shower head must not be fur-colored: ${id}`);
  }
  expect('flyingKite.kiteLeftFast4', 34, 10, 'ink');
  validateSceneColors(frames, masks);
  validateDetailColors(frames, masks);
  validateFinalColors(frames, masks);

  // The glider is one drawing translated across the screen. Both source ink
  // and color/alpha membership must translate identically through every crop.
  const master = frames.get('flying.enter5');
  const shift = (points, offset) => points.flatMap(p => {
    const x = p % 36 + offset;
    return x >= 0 && x < 36 ? [Math.floor(p / 36) * 36 + x] : [];
  }).sort((a, b) => a - b);
  for (const [i, offset] of [32,24,16,8,0,-8,-16,-24,-31].entries()) {
    const id = `flying.enter${i + 1}`;
    assert.deepEqual([...frames.get(id).pixels].sort((a,b) => a-b), shift(master.pixels, offset));
    for (const [color, points] of Object.entries(masks[master.id])) {
      assert.deepEqual([...(masks[id][color] ?? [])].sort((a,b) => a-b),
        shift(points, offset), `Glider crop changed ${color}: ${id}`);
    }
  }
}
