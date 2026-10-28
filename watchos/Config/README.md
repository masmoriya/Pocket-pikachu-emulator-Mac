# Native watch project configuration

Open `watchos/PocketPikachuWatch.xcodeproj` and select the shared `PocketPikachuWatch` scheme. The app is a standalone, single-target watchOS application; the widget extension embeds directly into its PlugIns directory. There is no iPhone companion target.

Set `DEVELOPMENT_TEAM` and, if needed, `WATCH_BUNDLE_IDENTIFIER` in `Base.xcconfig`. Automatic signing uses the root identifier for the app and adds `.widgets` for the extension. Both targets require the registered App Group `group.com.pocketpikachu.watch`. Set APP_GROUP_IDENTIFIER in Base.xcconfig to change the group for both entitlement files and shared snapshot readers. Only the app requests HealthKit access, with a step-reading purpose string; the widget reads the shared snapshot.

The deployment target is watchOS 26.0. `SDKROOT = watchos` selects the installed SDK, including watchOS 27 in Xcode 27.1. A simulator runtime or physical Watch is separately required for execution. Signing and HealthKit permissions still require device verification.

Xcode filesystem synchronized groups automatically include Swift files and recognized resources from `PocketPikachuWatch`, `PocketPikachuWidgets`, and `Shared`. The app receives its own directory plus `Shared`; the extension receives its own directory plus `Shared`. Atlas PNGs and `animations.json` under the app's `Resources` directory are bundled by Xcode. New source files require no project regeneration. Keep unrelated documentation or scripts outside these synchronized source directories.

The widget has explicit resource references to the app's `color-atlas.png` and `animations.json`. Its Copy Bundle Resources phase places both at its bundle root for the widget sprite reader. The images remain a single source on disk.

The local Swift package at `watchos/Package.swift` supplies `WatchCore` to the app only. The widget has no package dependency. Core tests remain Swift package tests and are not a native scheme test target.

`python3 'watchos/tools/generate-project.py'` deterministically recreates the project, scheme, property lists, entitlement files, and base configuration without external dependencies. It overwrites those generated files, including local signing edits, so preserve deliberate configuration changes before regenerating. This README is not generated.

The URL scheme `pocketpikachu` is registered for the app; its Swift URL handler is responsible for routing `pocketpikachu://clock`.
