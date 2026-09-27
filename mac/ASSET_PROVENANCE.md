# Asset provenance

The original `anims.json`, `script.js`, and images remain in the repository and are the source of the extracted animations. Each manifest frame retains its original identifier and complete source pixel list; the rendered list clips indices exactly as the original 36 × 30 renderer does.

The upstream README describes this emulator as an unfinished, non-profit fan project reverse-engineered from the Pocket Pikachu toy. There is no tracked license file in the provided repository. Extraction and colorization do not establish permission to redistribute the source art or the Pokémon character. Resolve those permissions before sharing a packaged release with friends or publishing it. No external distribution was performed by this implementation.

The native Swift implementation and build tooling are new. CodexBar's public usage documentation and parser design were consulted for local Codex counter semantics; no CodexBar source code was vendored. The app does not require CodexBar to be installed.

References:

- https://github.com/steipete/CodexBar/blob/main/docs/codex.md
- https://github.com/steipete/CodexBar/blob/main/docs/codex-oauth.md
- https://github.com/steipete/CodexBar/blob/main/Sources/CodexBarCore/Vendored/CostUsage/CodexSubagentRolloutShape.swift

The native device shell and interactive controls are drawn with Swift/AppKit paths, gradients, and text. The native app icon uses the source-derived `standLove.helloRight` affectionate Pikachu frame, rasterized at nearest-neighbor scale over a solid blue background. Animation sprites continue to use the source-derived atlases described above.
