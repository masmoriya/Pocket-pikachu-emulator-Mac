# Architecture

## Ownership and state

`Sources/WatchCore` is a Foundation-only Swift package. PetState owns schema-versioned progression, settings, activity, timestamps, bounded histories, and the reconciliation ledger. GameEngine is deterministic given records, dates, gift request IDs, and rolls. The app passes a random roll only at the interaction boundary.

`CompanionModel` loads one app-private Application Support store. Mutations operate on a candidate, save atomically, and only then publish UI state. Failed saves never display an uncommitted purchase. Corrupt originals are preserved; a valid backup can recover progress. Without a recoverable save the app presents Retry and blocks mutation. Unknown future schema versions are rejected. Version zero migration is explicitly defined; later schema changes must add tested migrations.

Widgets read a separate `PetSnapshot` JSON file in the App Group. They never load the engine, write gameplay, query HealthKit, or award currency. App reloads timelines only when meaningful snapshot values change; timelines request a 30-minute refresh, subject to system budget. If provisioning makes the App Group unavailable, app-private game saving remains functional.

## Step accounting

HealthKitStepProvider requests only stepCount read access. It queries a complete interval from UTC midnight six days ago through now (six to seven days), including boundary-overlapping samples. This is a bounded reconciliation window, not a claim of unlimited offline catch-up. Manual entries are excluded. More than 50,000 records fails the whole snapshot rather than silently truncating it. The provider and clock are injectable.

Each sample retains its UUID, source identity, interval, and count. Contributions are uniformly apportioned within intervals. A sweep partitions sample boundaries and chooses one contributor per interval: Watch first, then iPhone, then other sources, with stable source/UUID tie-breaking. Overlaps are never summed, including same-source overlaps. This conservative policy may differ from Apple's Health aggregate and user-selected Health source ordering.

The latest complete snapshot replaces the active ledger. Deleted/corrected samples change observed eligible steps. A monotonic credited high-water mark means a decrease creates step debt, never negative watts or reversed purchases; subsequent steps first repay that debt. Reappearing or replacement records cannot re-award the same net progress. Retired intervals freeze their last observed contribution. Corrections/backfills older than the bounded window are ignored. The persisted cursor records the snapshot timestamp; each sync intentionally rereads the bounded interval rather than trusting an incremental cursor.

No accessible records cannot distinguish no history, read revocation, or deletion of every record. In that case the app preserves the ledger and shows unavailable steps; it does not infer denial or grant rewards. A later nonempty complete snapshot reconciles against the preserved ledger. Time zone changes affect today's display only, while ledger windows stay UTC.

## Rendering and lifecycle

Atlas metadata and clips load once; original atlas images decode once per selected style and crops use a bounded cache. Sprite rendering uses nearest-neighbor scaling and original aspect ratio. The animation timeline schedules source frame boundaries, not a high-frequency display loop. Reduced luminance removes frame-by-frame playback and uses a system-scheduled, once-per-minute visible pose from the current loop. Intro and blank frames are excluded from ambient poses. Outside Always-On, inactive scenes remain static. Reduced-animation preference and system Reduce Motion keep a static pose. A separate every-minute system-time TimelineView supplies the clock. Ambient rendering does not mutate gameplay into sleeping.

All meaningful state changes save immediately; scene transitions publish presentation state without redundantly rewriting an already committed game file. There is no background game timer, workout session, networking, or persistent foreground workaround. Health data recorded while suspended is reconciled on resume. WatchCore does not depend on existing Mac-specific code or its separate saves.

## Configurable companion

GameSettings decodes original schema-1 saves with a 20-step rate; new settings default to one step per watt. Rate changes never re-credit an unchanged Health snapshot. Unconverted step counts carry across changes and convert once new eligible steps arrive. Clock minute updates and foreground reconciliation apply daily routines; manual activity selection pins playback until Live freely. No background schedule timer is introduced. Mac window/menu-bar, Codex-token filesystem, login, and desktop shell controls are not watch features.

The fullscreen layout uses a bounded geometry surface with controls in a separate top strip; menu presentation is a sheet with its own navigation stack, so it cannot be pushed outside the display by sprite layout. Layout version 1 upgrades the previously installed small sprite setting to full size once, then respects later size changes. Missing clock visibility defaults off. Daily step-goal ring uses the existing reconciled step count and preserves unavailable data as an em dash rather than claiming zero progress.

The latest layout reserves a compact top strip below the system clock for a 14-point ring, 11-point watts and a small menu glyph; the sprite fits the separate remaining region without any overlapping controls. The watchOS-owned time area is not replaced. Ambient updates follow [Apple TimelineView guidance](https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines); refresh timing remains system-controlled.
