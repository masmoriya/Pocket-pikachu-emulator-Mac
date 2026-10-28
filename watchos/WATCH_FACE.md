# Pikachu on your watch face

Install the watch app using [Installation](INSTALLATION.md), then open it once.

1. Touch and hold your Apple Watch face and tap Edit.
2. Swipe to Complications, choose a compatible slot, and select Pocket Pikachu.
3. Press the Digital Crown to finish. Tap the complication to open the animated pet.

For a large Pikachu with step progress, use the rectangular slot on a Modular face. Circular slots show Pikachu inside your daily step-goal ring. Inline slots show saved steps and watts. The rectangular widget also works in Smart Stack where supported. An in-app guide is available under Menu → Watch face.

The complication uses the first frame of the app's saved activity and follows its Color and Daily step goal settings. Open the app to reconcile Health steps and publish changes. Complications are static snapshots: watchOS controls refresh timing and face colors. Missing step data shows a dash; the ring appears only when current-day steps and a valid goal are available. A preloaded midnight timeline entry drops yesterday's step count even when a later refresh is delayed. Saved watts and mood remain available. Private data is hidden when the system requests privacy redaction.

Apple's supported customization is a complication on a system face. The animated emulator runs inside the watch app; it cannot replace the system face or override Return to Clock. See [Apple's complications guidance](https://developer.apple.com/design/human-interface-guidelines/complications).

## Focused verification

```sh
python3 'watchos/tools/run-snapshot-tests.py'
python3 'watchos/tools/run-core-tests.py'
xcodebuild -project 'watchos/PocketPikachuWatch.xcodeproj' -scheme 'PocketPikachuWatch' -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The snapshot regression checks legacy decoding, round-trip persistence, unavailable steps, progress bounds, and midnight across daylight saving time. Compile and model checks do not prove the layout, tinting, privacy behavior, update delivery, or tap-to-open on a real face; those need an installed watch runtime or physical device.

Local verification on 2026-10-27: unsigned watch simulator app/widget build passed, all 31 core XCTest cases passed, and the shared snapshot regression passed. Bundle inspection confirmed the widget contains the monochrome atlas. No watch simulator runtime was installed, so this update has no visual runtime or physical-watch verification and was not installed on a device.
