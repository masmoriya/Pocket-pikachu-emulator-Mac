# Animation color workspace

`color-masks.json` maps each of the 335 character frame identifiers to exact pixel memberships in a shared palette. Original outline pixels are retained. Device-interface graphics remain monochrome and inspectable in the gallery.

`color-corrections.json` is the durable, editable source for frame-specific or group-specific overrides. A `regions` entry contains an inclusive `[left, top, right, bottom]` rectangle and palette color. It affects filled interior pixels unless `ink: true` is specified. A `pixels` entry can explicitly assign any frame pixel index (`y * 36 + x`) to a palette color.

`tools/author-color-masks.mjs` creates the first pass using enclosed regions, cropped-outline closure, authored prop palettes, cheek placement, and the explicit corrections. It does not use a model. This is not a substitute for artistic review: small faces and moving props need special attention.

`tools/authored-frame-colors.mjs` applies the final, pose-specific geometry for standing, affectionate, tongue, letter-writing, and glider frames. These overrides use original ink marks, contour-bounded regions, and translated glider crops. Edit these definitions for those poses; they take precedence over the initial pass and correction rectangles. `tools/validate-color-art.mjs` checks source-sized cheeks and stripes, prop boundaries, tongue colors, and glider color/alpha consistency during asset validation.

`review-1.png` through `review-5.png` show every character frame. Tile numbers map to `review-index.json`; `contact-sheet.png` is a compact group overview. `review.json` separates static inspection from final approval. All static sheets were inspected during implementation; no claim is made that all 65 clips have received complete motion/palette approval.

Regenerate from the repository root:

```sh
node 'tools/author-color-masks.mjs'
node 'tools/build-atlases.mjs'
node 'tools/validate-assets.mjs'
```

Review in the Mac gallery, using original/color comparisons and frame stepping. A clip should be approved only after checking every pose, entry, exit, loop boundary, tiny cheek details, props, and transparent-background silhouette. Do not mass-mark unreviewed frames as approved.
