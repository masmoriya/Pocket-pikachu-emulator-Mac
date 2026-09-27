# Verification record

Checked on an Apple Silicon Mac running macOS 26.5.2, using Swift 6.3.3.

## Automated checks

- `swift test --package-path 'mac'`: 22 tests passed at the last verification.
- Counter coverage: fresh baseline, repeated cumulative snapshots, restarts, concurrent sessions, direct forks, empty intermediate ancestors, missing-parent deferral, embedded ancestor metadata, subagent inherited opening snapshots, independent subagent counters, and cumulative resets with request-level evidence.
- Scanner coverage: unchanged files read zero bytes; persisted offsets survive scanner restart; untouched historical files are skipped at first setup; partial final records wait for completion; archive moves and file replacement retain logical counter identity.
- Product coverage: fractional steps, prospective conversion changes, watts, gift thresholds including the original 899-watt gap, fixed friendship, manual rest overrides, milestone boundaries, animation intro/loop timing, atomic persistence, corrupt-state preservation, and concurrent menu-bar preference compatibility.
- Asset validation: all 622 source frame arrays match the original data; every sequence reference and duration is valid; all 335 character masks preserve every original lit pixel.
- Both arm64 and x86_64 release targets compile. The universal app bundle is locally ad-hoc signed and passes `codesign --verify --deep --strict`.
- `git diff --check` passes. No repository-wide lint or type-check was run.

## Observed on the Mac

- Launched the packaged native app, opened settings, and connected to actual local Codex logs.
- New usage increased the token and step counters. Initial historical usage was not imported.
- Enabled the shell and always-on-top placement and inspected the resulting colored companion.
- Opened the native animation gallery and verified the original/color comparison and full activity inventory visually.
- Inspected all five static character contact sheets. Corrected cropped side outlines, prop colors, and several color placements. Full motion/palette approval remains pending.

The first real scan revealed roughly 31 GB of existing session history. Startup was revised to skip untouched pre-installation files and persist offsets. After that change, one observed save held three session counters and three file cursors in about 25 KiB. A running-app profile with the gallery available reported a 78.7 MB physical footprint, 94.1 MB peak. These are snapshots, not an idle battery benchmark. The gallery was subsequently changed to schedule only actual frame boundaries and to stop its timer when paused/closed.

## Remaining manual validation

- Complete motion/palette review of every clip, especially tiny side-profile cheeks and moving props; review flags deliberately remain unapproved.
- Test monitor disconnect/reconnect, multiple Spaces, click-through boundaries, drag persistence, and display sleep/wake across different Mac configurations.
- Measure idle CPU and battery impact with the final build, gallery closed, and a quiet token source; concurrent app interaction prevented a controlled idle measurement.
- Run the universal build on an Intel Mac and macOS 14; compilation does not establish device proof.
- Exercise launch-at-login from an installed app in Applications.
- Developer ID signing, notarization, and a clean-machine friend install need distribution credentials. This Mac had development identities but no Developer ID Application identity.
- Resolve source/artwork redistribution permissions before sharing a release. No publishing, token API calls, or external distribution was performed.

Concurrent menu-bar sprite and menu-bar-only changes were preserved throughout implementation.
