# Verification and limitations

## Local evidence (2026-10-27)

- Source atlas conversion validated all 623 cells (622 original plus blank), 65 clips, and 561 positive frame durations. Both bundled atlases match source bytes.
- Foundation animation regression runner passed 3,574 assertions over the actual manifest, including intro loops, finite completion, mood restoration, and invalid inputs.
- Unsigned native app and embedded widget build passed for the arm64 watch simulator SDK. Bundle inspection confirmed minimum watchOS 26.0, standalone flag, both App Group values, and both target resource copies. This is compilation/bundle proof, not simulator execution.
- Unsigned native device build also passed. Both app and embedded widget binaries contain arm64 and arm64_32 slices, including the architecture required by Series 6. The follow-up device build is signed with FILMCLUSIVE INC. and installation is verified.
- All 25 real XCTest cases passed through `tools/run-core-tests.py` using the active Swift 6 compiler (6 clock, 5 gameplay, 5 persistence, 9 reconciliation). Execution took 0.428 seconds on the host; the 50,000-record overlap case took 0.379 seconds. This is not a Series 6 performance measurement.
- Normal `swift test` stalled in Apple's SDK stat-cache I/O and was stopped. The direct compiler fallback builds the unchanged production module and XCTest files, asserts the expected test count, and checks success. SwiftPM's own runner remains unverified.
- The installed environment has Xcode 27.1 and watchOS 27.0 SDK. Deployment minimum remains watchOS 26.0. There is no installed watch simulator runtime.
- Follow-up verified physical Apple Watch Series 6 (Watch6,3), watchOS 26.5, Developer Mode enabled. FILMCLUSIVE INC. signed build installed successfully over the network. Initial launch was blocked by the watch passcode lock; no device was erased.

## Required hardware checks

The user's explicit instruction allowed complications before the PRD's physical-P0 gate. That exception does not provide runtime proof. Signed installation is now verified on Series 6. Remaining runtime checks:

- Cold/warm launch, restart app/watch, and confirm retained progress.
- Verify frame placement, touch targets, scrolling, gift reaction, readable time, and VoiceOver at supported text sizes.
- Raise/lower wrist: confirm static ambient sprite, visible minute clock, restored animation, and system Return to Clock behavior.
- Exercise Health authorization, inaccessible/empty data, delayed Watch/iPhone samples, corrections, and real walking rewards. Unit fixtures prove reconciliation logic; they do not prove live Health ingestion.
- Add each supported complication and Smart Stack layout; verify shared snapshots and tap-to-open.
- Profile warm launch against the 2-second target, active/ambient CPU, memory, and daily battery impact using Instruments. No measured battery or warm-launch claim is made.

## Deliberate constraints

- This is a supported watch application, not an installable custom system watch face. watchOS may suspend it or return to the system clock.
- Health rewards reconcile only the latest six-to-seven-day UTC window. Older unobserved walking/backfills are not imported. Source priority is deterministic Watch → iPhone → other; uniform sample apportionment is conservative and can differ from Health's displayed total.
- Corrections create step debt against future rewards; previously spent watts are never reclaimed. Empty Health responses preserve the prior ledger because read revocation is indistinguishable from an empty store.
- No background Health polling or continuous pet simulation runs. Records collected while suspended are reconciled when reopened or manually synced.
- Clock/activities work without Health access. Shared widgets require correct App Group provisioning. Missing group access must not corrupt app-private saves; a widget with no snapshot prompts Open app.
- Signing and free Personal Team capability support remain unverified. Apple controls provisioning eligibility; if the selected team cannot provision HealthKit/App Groups, the full PRD cannot be satisfied by bypassing those requirements.
- Deleting the watch app deletes its private save. Reinstall over the same identifier to preserve it. Corrupt saves are preserved and a valid backup is recovered; unrecoverable or future-schema saves block mutation rather than silently resetting.
- Existing Mac/browser source was not edited by this implementation. Their full runtime regression suites were not run; they do not import this standalone project.

## Settings follow-up

30 core XCTest cases pass, including legacy-save migration, configurable rate changes, duplicate snapshots, partial remainders, and schedule rollover/manual override. Animation regression now passes 3,577 assertions, including repeated finite selections. Device-specific Debug builds use ONLY_ACTIVE_ARCH to match the local Swift package architecture on Series 6. Device Hub cannot remotely display watchOS 26.5; its screen-sharing feature requires watchOS 27 or later, so visual/device interaction checks need the watch user.
