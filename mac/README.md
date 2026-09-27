# Pocket Pikachu for Mac

A local native companion based on the existing Pocket Pikachu web emulator. The web project is unchanged.

## Run

From the repository root:

```sh
python3 'tools/package-mac.py'
open 'dist/Pocket Pikachu.app'
```

Requires macOS 14 or later. Building requires the Xcode command-line tools, Swift 5.9+, Node.js, and Python 3. The app itself needs none of these runtimes. The packaged executable contains Apple Silicon and Intel slices.

For development:

```sh
swift run --package-path 'mac' PocketPikachu
```

The local build is ad-hoc signed, not notarized. Do not distribute it as a notarized release. See `ASSET_PROVENANCE.md` before redistributing artwork.

## Use

- Click Pikachu for petting, feeding, gifts, friendship, and activity selection. Drag him to move him.
- Shell buttons: D-pad left/right cycles activities, up pets, down feeds. The upper round button opens controls; the lower round button resumes “Live freely.” The left oval opens steps/watts/gifts, the right oval opens the gallery, and the small button opens settings. Hover for labels; buttons support accessibility and pressed feedback.
- Use the paw menu-bar item to show/hide him, open the gallery/settings, or quit.
- Settings switches between the shell and transparent pet, monochrome/color, integer scales, and desktop/always-on-top placement. The shell is drawn entirely in Swift with transparent edges and a live LCD; drag the case to move it. No Shake button is shown.
- “Live freely” chooses activities automatically. Manual activities repeat until changed. Friendship stays exactly as chosen.
- Feeding is followed by brushing. New live token usage wakes an autonomous sleeping pet. Inactivity settles him after 15 minutes and puts him to sleep after 30 minutes.
- Gifts cost 0–999 watts and use the original reaction bands; they do not change friendship. Animations are never locked behind currency.
- Keyboard shortcuts while the app is active: Command-Shift-P for pet controls, Command-Shift-A for the gallery, Command-comma for settings.
- The gallery supports original/color comparison, playback, frame stepping, and inspection of all source frames, including unused poses and device interface art.

The appearance settings also preserve the concurrently added menu-bar sprite option.

## Usage and privacy

The default source is `$CODEX_HOME`, or `~/.codex`. Choose another home in Settings if necessary. Reads local `event_msg/token_count` metadata from active and archived Codex sessions. It never reads authentication credentials or calls a model or usage API. Conversation content is not retained, logged, uploaded, or included in the saved state.

Input plus output tokens count. Cached input is already included in input; reasoning output is already included in output. A fresh installation does not import existing history. Usage recorded after setup while the app is closed catches up on reopening.

Defaults: 1,000 tokens per step, 20 steps per watt, 50 starting watts. Changing the conversion preserves existing steps and fractional progress and applies the new rate only to future tokens. Milestone celebrations occur at powers of ten starting at 1,000 steps, without interrupting an activity or replaying offline celebrations.

Untouched pre-installation files are not read. Changed files are streamed; persisted byte offsets avoid full rescans after restarting. Only needed fork ancestors are loaded. Missing direct-fork ancestry defers rewards instead of guessing. Unrecognized/corrupt usage records surface a status message while the pet keeps living.

State is stored atomically in `~/Library/Application Support/PocketPikachu/state.json` with owner-only file permissions. Rewards, metadata counters, and file offsets are committed together. A corrupt or newer-version state file is preserved and tracking pauses instead of resetting progress. Changing the selected Codex home creates a fresh baseline while preserving earned steps/watts.

## Assets

- 622 exact source frames: 335 character frames and 287 device/interface frames.
- 65 playable clips, extracted by executing original choreography against a deterministic virtual clock, plus source-derived interaction clips.
- Original 36 × 30 coordinates, transparent PNG atlases, and a portable JSON manifest.
- Color masks exist for every character frame. This is a first color pass; complete motion/palette approval is still outstanding. See `art/review.json` and `art/README.md`.

Regenerate assets:

```sh
node 'tools/extract-animations.mjs'
node 'tools/author-color-masks.mjs'
node 'tools/build-atlases.mjs'
node 'tools/validate-assets.mjs'
```

`author-color-masks.mjs` deliberately replaces generated color masks from the editable corrections file; edit `art/color-corrections.json` for durable changes. Packaging regenerates the animation manifest and atlases but does not overwrite masks or review decisions.

## Verify

```sh
swift test --package-path 'mac'
node 'tools/validate-assets.mjs'
git diff --check
```

See `VERIFICATION.md` for observed results and remaining manual checks. No repository-wide lint or type-check is needed.

## Distribution

With a valid Developer ID Application identity and an existing notarytool Keychain profile:

```sh
python3 'tools/package-mac.py' --identity 'Developer ID Application: Your Name (TEAMID)' --notary-profile 'your-existing-profile'
```

This signs, submits the archive for notarization, staples the result, and produces `dist/PocketPikachu.zip`. The script does not create accounts, configure credentials, or publish/share the archive. Without those flags it produces a local ad-hoc-signed build.
