# Sprite assets and playback

The watch reuses the existing repository artwork. It introduces no replacement art.
The source manifest and both PNGs were verified byte-for-byte against base commit
`ca9ca247691464af1e15ff263ecbce29262ccf64`. Uncommitted macOS sequences are not inputs.

Inputs under `mac/Sources/PocketPikachu/Resources/`:

- `animations.json`: 622 source frames plus the explicit utility `blank` frame.
- `color-atlas.png`: SHA-256 `ca046531e3a0b6e03081b1b327697abdfc77237b179bc42f7739dbb47955dedc`.
- `mono-atlas.png`: SHA-256 `609bcdf877d70f25799e604997a4c203eb249c5503366725f1601e13094af1c9`.

Each atlas is 576 × 1170 pixels: 16 columns of 36 × 30 pixel cells, in manifest
frame order. Frame `i` starts at `(i % 16 × 36, i / 16 × 30)`, using integer division.
There are 39 rows and one unused cell. `blank` remains index 622.
The source contains 335 character and 287 interface frames; utility blank adds one.
Artwork provenance, color masks, and review status remain in the existing `art/`
resources and `tools/build-atlases.mjs`. Color atlas reuse does not imply every
source color mask has been reviewed or that redistribution rights are granted.

## Reproduction and checks

From the repository root:

```sh
python3 'watchos/tools/prepare-assets.py'
python3 'watchos/tools/prepare-assets.py' --check
```

The preparation script reads only the original manifest and atlases. It copies both
PNGs unchanged and strips per-frame pixel arrays from the watch manifest, replacing
them with explicit original indices. Original clip metadata, frame IDs, step order,
durations, loop flags, and loop starts are retained. No dirty `sequences.json` is
read. The result is 74,091 bytes of JSON plus 76,230 bytes of compressed PNGs.

`--check` validates all 623 coordinates against PNG dimensions, unique frame and
clip IDs, all 561 positive finite step durations, loop start bounds, alias targets,
and exact generated file bytes. It does not render or prove device performance.

## Requested state mappings

All 65 original clips are available using their original IDs. These aliases make
PRD state names usable directly in `PikachuSpriteView`:

| Requested state | Existing clip | Meaning |
| --- | --- | --- |
| idle | like | Content standing |
| walking | walk | Walking |
| sleeping | sleep-front | Front sleeping pose |
| eating | toast | Eating toast; onigiri and rice are also available |
| greeting | loveHello | Finite affectionate hello |
| happy | happy | Finite happy steps |
| sad | mad | Existing upset pose; no distinct sad clip |
| bathing | bath | Bathing; shower is also available |
| brushingTeeth | brush | Brushing teeth |
| reading | reading | Reading |
| studying | history | Studying history; maths and english also available |
| buildingBlocks | blocks | Building blocks |
| kiteFlying | kite | Flying a kite |
| yoYo | yoyo | Playing yo-yo |
| giftReceiving | hearts | Existing heart reaction; no dedicated gift-opening clip |
| friendshipIncrease | happy | Existing happy reaction |
| leaving | left | Existing away state; no newly invented departure transition |
| returning | return | Finite coming-back animation |

`love`, `like`, `neutral`, `mad`, and `left` remain the original friendship poses.
Unknown IDs safely resolve to `like`. Finite animations visually return to the
`idleAnimationID` supplied by the application (default `idle`, which resolves to
`like`), preserving the current friendship pose. Gameplay state remains the
application's responsibility. To replay the same clip
as a new interaction, give the sprite view a new SwiftUI identity for that event.

## Native playback and memory

`PikachuSpriteView(animationID:colored:isActive:reducedMotion:)` displays native
ImageIO atlas crops. Color defaults to enabled. Mono uses the source alpha mask
with white template rendering so original dark ink remains visible on the black
watch background. Both styles preserve original geometry with nearest-neighbor
interpolation and proportional scaling.

Run `sh 'watchos/tools/run-animation-tests.sh'` for isolated host regressions using
the production Foundation playback files and real bundled manifest. No Xcode
project or SwiftUI compilation is required. The runner checks all frame and
sequence positions, timing bounds, intro loops, finite mood restoration, unknown
clips, replay/reset samples, and rejection of zero durations.

`AnimationEngine.sample(elapsed:)` is a deterministic pure function. It honors
per-step duration and intro-only steps before `loopStart`, supports interruption
by replacing the animation ID, and samples idle after finite completion. A custom
SwiftUI timeline schedules source frame boundaries (shortest source duration is
0.1 seconds), rather than a display-refresh publisher. Paused elapsed time is kept
by the view. No animation timeline exists in an inactive scene, reduced luminance,
or system/app reduced-motion state. Ambient mode freezes the current activity;
it does not mutate gameplay into sleeping.

Only the selected style is decoded. Switching style releases the previous atlas
and clears cached crops. One 576 × 1170 RGBA atlas has a nominal 2,695,680-byte
(2.57 MiB) pixel backing. The `NSCache` limit is 128 crops / 552,960 nominal bytes
(0.53 MiB), with eviction under memory pressure. Core Graphics crops may share
atlas backing; these numbers are budget estimates, not measured allocations.
ImageIO/SwiftUI overhead and transient decode allocations require actual profiling.
No full-atlas decode is performed per frame. Hardware battery usage, visual
sharpness, first-launch timing, and Always-On wake behavior remain device checks.
