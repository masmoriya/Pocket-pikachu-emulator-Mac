# Installation

1. Install Xcode 26.5 or newer with its matching watchOS SDK and a macOS release supported by that Xcode. This implementation was compiled using the installed Xcode noted in KNOWN_LIMITATIONS. Deployment minimum is watchOS 26.0.
2. Confirm the actual Apple Watch model and installed OS in Settings → General → About. Connect its paired iPhone, trust the Mac, and enable Developer Mode on the watch when prompted. In Xcode → Window → Devices and Simulators, confirm the watch is online and paired before deployment.
3. Open `PocketPikachuWatch.xcodeproj`. Set `DEVELOPMENT_TEAM` and a unique `WATCH_BUNDLE_IDENTIFIER` in `Config/Base.xcconfig`. Keep the widget identifier as the app identifier plus `.widgets`.
4. Configure HealthKit for the app and one registered App Group for both app and widget. Set `APP_GROUP_IDENTIFIER` in `Config/Base.xcconfig`; both entitlements and both `PocketAppGroup` Info.plist values inherit it. This checkout uses `group.com.filmclusive.pocketpikachu.watch` with the user-selected FILMCLUSIVE INC. team.
5. Select PocketPikachuWatch and the physical watch destination. Use automatic signing. Build and Run. No App Store, TestFlight, or companion iPhone app is required.
6. Open Settings inside the app → Connect Health. Grant step read access if desired. If nothing appears, inspect Health permissions; the app cannot determine whether read access was denied. Clock and pet work without step data.
7. Edit a compatible native watch face and select Pocket Pikachu in a supported complication slot. For Smart Stack, add the rectangular widget where available. Tap it to open the clock.

Apple controls capability eligibility and provisioning by account type and platform. Select your actual team in Xcode to verify HealthKit and App Group support. A free Personal Team may require frequent reprovisioning and may not provision every required entitlement; the full feature set is not verified on a free account. No runtime subscription or paid service is introduced. Do not remove capabilities and then assume walking or shared complications still work.

If signing expires, renew provisioning and install over the same bundle ID to retain data. Deleting the app or changing its bundle ID can lose access to its save. Preserve device data before reinstalling. If Xcode cannot find the watch, unlock it, keep it near its paired phone, and check pairing/Developer Mode. If there is no simulator runtime, install one in Xcode Settings → Components before choosing a watch simulator.

Always-On availability, update cadence, and Return to Clock are system-controlled. Configure Return to Clock manually in watch Settings → General → Return to Clock. The app cannot install an arbitrary animated system watch face.

Apple references: [standalone watch apps](https://developer.apple.com/documentation/bundleresources/information-property-list/wkwatchonly), [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [capability eligibility](https://developer.apple.com/help/account/capabilities/capabilities-overview), [reduced luminance](https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced).
