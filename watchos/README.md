# Pocket Pikachu for Apple Watch

Standalone SwiftUI watch app, minimum watchOS 26.0. No iPhone companion, account, network, analytics, or backend. It uses the repository's original artwork and rules without changing the Mac or browser applications.

Open `PocketPikachuWatch.xcodeproj` and select the PocketPikachuWatch scheme. See [installation](INSTALLATION.md) for signing and device setup.

The launch screen puts full-width animated Pikachu first, with a daily step-goal ring and optional watts. The clock is off by default and can be enabled in Settings. Tap Pikachu to cycle activities (or greet when cycling is disabled); the 44-point ellipsis opens a separate menu sheet with activities, gifts, watts, settings, and an explicit Close button. Digital Crown scrolls native lists and the gift picker. Wrist-down presentation removes animation scheduling and hides secondary information. Return to Clock remains controlled by watchOS.

Settings include an optional clock, editable daily step goal, system/12/24-hour time, color/monochrome, haptics, visible counters, reduced animation, and Health connection. Connect Health explicitly requests step-reading access only. Opening the app or selecting Sync steps reconciles recorded walking. No invented steps appear when Health data is unavailable.

Choose 1, 5, 10, 20, 50, or 100 eligible steps per watt in Settings. New installs use 1; earlier saves retain 20. Partial progress persists and converts at the selected rate only when new eligible steps arrive. Initial balance is 50 watts, matching the existing emulator. Gifts use the source friendship points and reaction bands. Free activities do not spend watts. There is no suspension/inactivity penalty. Friendship selection, tap-to-cycle, all original animations, sprite size, and editable daily schedules mirror the watch-compatible Mac controls. Fresh installs start with the current Mac preferences: color, tap cycling, free play, Loves you, and large sprites. Existing saves are preserved. Source walking rules do not directly add friendship points; walking funds friendship-building gifts.

Read-only circular, inline, and rectangular complications display the last shared snapshot and open the app. Rectangular presentation also supports Smart Stack placement where offered by watchOS. They do not continuously animate.

## Local verification

```sh
swift test --package-path 'watchos'
# If SwiftPM stalls in SDK cache setup on this host:
python3 'watchos/tools/run-core-tests.py'
python3 'watchos/tools/prepare-assets.py' --check
sh 'watchos/tools/run-animation-tests.sh'
xcodebuild -project 'watchos/PocketPikachuWatch.xcodeproj' -scheme 'PocketPikachuWatch' -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Run from repository root. See [architecture](ARCHITECTURE.md), [asset provenance](ASSETS.md), and [verification limits](KNOWN_LIMITATIONS.md). This is an ordinary watch app, not a replacement system watch face. Existing Pokémon artwork remains subject to its owners' rights; this implementation adds no redistribution license.
