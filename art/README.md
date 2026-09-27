# Animation color workspace

`color-masks.json` maps each of the 335 character frame identifiers to exact pixel memberships in a shared palette. Original outline pixels are retained. Device-interface graphics remain monochrome and inspectable in the gallery.

`color-corrections.json` is the durable, editable source for frame-specific or group-specific overrides. A `regions` entry contains an inclusive `[left, top, right, bottom]` rectangle and palette color. It affects filled interior pixels unless `ink: true` is specified. A `pixels` entry can explicitly assign any frame pixel index (`y * 36 + x`) to a palette color.

`tools/author-color-masks.mjs` creates the first pass using enclosed regions, cropped-outline closure, authored prop palettes, cheek placement, and the explicit corrections. It does not use a model. This is not a substitute for artistic review: small faces and moving props need special attention.

`tools/authored-frame-colors.mjs` applies pose-specific standing, affectionate, tongue, letter-writing, and translated glider geometry. `tools/scene-colors.mjs` follows whole object contours for the duvet, bedding, pool, tub, books, furniture, piano keys, and Poké Ball. Title counters and air beneath the piano lid remain transparent. Facial marks are selected inside the fur, preventing cheeks on props and cropped tails.

The order is initial fill, authored poses, scene contours, detail corrections, final object colors, then explicit corrections. `tools/final-frame-colors.mjs` preserves furniture outlines, fills food and toothpaste contours, carries dropped-treat palettes, and handles the heart and Poké Ball colors. `tools/detail-colors.mjs` records the reviewed face marks, hand boundaries, furniture, and prop gaps from the gallery references. `tools/validate-detail-colors.mjs` checks these distinctions, including black eyes versus red cheeks. Screenshot annotations identify objects to review; their display coordinates are not source pixel coordinates. `tools/validate-color-art.mjs` and `tools/validate-scene-colors.mjs` check complete cheek squares, monochrome glyphs, white Poké Ball interiors, uniform object contours, and glider color/alpha consistency.

`review-1.png` through `review-5.png` show every character frame. Tile numbers map to `review-index.json`; `contact-sheet.png` is a compact group overview. `review.json` separates static inspection from final approval. All static sheets were inspected during implementation; no claim is made that all 65 clips have received complete motion/palette approval.

Regenerate from the repository root:

```sh
node 'tools/author-color-masks.mjs'
node 'tools/build-atlases.mjs'
node 'tools/validate-assets.mjs'
```

Review in the Mac gallery, using original/color comparisons and frame stepping. A clip should be approved only after checking every pose, entry, exit, loop boundary, tiny cheek details, props, and transparent-background silhouette. Do not mass-mark unreviewed frames as approved.
