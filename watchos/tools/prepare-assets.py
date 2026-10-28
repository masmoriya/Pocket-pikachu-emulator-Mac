#!/usr/bin/env python3
"""Copy original sprite atlases and emit/validate a pixel-free watch manifest."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'mac/Sources/PocketPikachu/Resources'
DESTINATION = ROOT / 'watchos/PocketPikachuWatch/Resources'
ALIASES = {
    'idle': 'like', 'walking': 'walk', 'sleeping': 'sleep-front',
    'eating': 'toast', 'greeting': 'loveHello', 'sad': 'mad', 'bathing': 'bath',
    'brushingTeeth': 'brush', 'studying': 'history', 'buildingBlocks': 'blocks',
    'kiteFlying': 'kite', 'yoYo': 'yoyo', 'giftReceiving': 'hearts',
    'friendshipIncrease': 'happy', 'leaving': 'left', 'returning': 'return',
}


def dimensions(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'Expected original PNG atlas'
    return struct.unpack('>II', data[16:24])


def prepare():
    original = json.loads((SOURCE / 'animations.json').read_text())
    width, height, columns = original['width'], original['height'], 16
    frames = [dict(id=frame['id'], category=frame['category'], index=index)
              for index, frame in enumerate(original['frames'])]
    manifest = dict(version=1, width=width, height=height, columns=columns,
                    sourceFrameCount=original['sourceFrameCount'], frames=frames,
                    clips=original['clips'], aliases=ALIASES)
    ids = {frame['id'] for frame in frames}
    assert len(ids) == len(frames) == original['sourceFrameCount'] + 1
    assert 'blank' in ids
    clips = {clip['id']: clip for clip in manifest['clips']}
    assert len(clips) == len(manifest['clips'])
    assert set(ALIASES.values()) <= clips.keys()
    for clip in clips.values():
        assert clip['steps'], f"Empty clip: {clip['id']}"
        assert 0 <= clip['loopStart'] < len(clip['steps'])
        for step in clip['steps']:
            assert step['frame'] in ids, f"Missing frame: {step['frame']}"
            assert math.isfinite(step['duration']) and step['duration'] > 0
    outputs = {'animations.json': (json.dumps(manifest, separators=(',', ':')) + '\n').encode()}
    for name in ('color-atlas.png', 'mono-atlas.png'):
        data = (SOURCE / name).read_bytes()
        size = dimensions(data)
        assert size == (columns * width, math.ceil(len(frames) / columns) * height)
        for frame in frames:
            x, y = frame['index'] % columns * width, frame['index'] // columns * height
            assert x + width <= size[0] and y + height <= size[1]
        outputs[name] = data
    return manifest, outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate without modifying assets')
    args = parser.parse_args()
    manifest, outputs = prepare()
    if not args.check:
        DESTINATION.mkdir(parents=True, exist_ok=True)
    for name, data in outputs.items():
        target = DESTINATION / name
        if args.check:
            assert target.read_bytes() == data, f'Stale watch resource: {name}'
        else:
            target.write_bytes(data)
        print(f'{name}: {len(data)} bytes; sha256 {hashlib.sha256(data).hexdigest()}')
    print(f"Validated {len(manifest['frames'])} frame coordinates, {len(manifest['clips'])} clips, "
          f"{sum(len(c['steps']) for c in manifest['clips'])} positive frame durations.")


if __name__ == '__main__':
    main()
