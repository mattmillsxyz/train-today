# DRILL

Multi-sport training for young athletes. A native SwiftUI iPhone app plus a static
marketing site, both in this repo.

App Store name: **DRILL: Never Miss a Rep**, subtitle **Youth Multi-Sport Training**.
Home-screen name: **DRILL**. Bundle id `com.trainwithdrill.drill`. Site: `trainwithdrill.com`.

## Layout

| Path | What |
|---|---|
| `ios/DRILL.xcodeproj` | Xcode project. Two targets: `DRILL`, `DRILLTests`. |
| `ios/DRILL/` | App sources: `Models/`, `Views/`, `Services/`, `Resources/`. |
| `ios/DRILLTests/` | Unit tests. |
| `site/` | Marketing site, deployed at the domain root. Publish directory is `site`; no build step. |
| `site/app/` | The retired vanilla-JS web app. Still served for anyone who bookmarked it, but nothing on the site links to it. Also the fidelity reference for `validate-content.js`. |
| `tools/` | Content validation and page generation. Plain Node, no dependencies. |
| `docs/ios-migration-plan.md` | The plan this was built from. |

## Building

```sh
cd ios
xcodebuild -project DRILL.xcodeproj -scheme DRILL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project DRILL.xcodeproj -scheme DRILL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

No package manager and no third-party dependencies — first-party frameworks only.
Deployment target iOS 17.0 (SwiftData, `@Observable`).

The project uses **synchronized file groups** (`PBXFileSystemSynchronizedRootGroup`),
so adding a Swift file to `ios/DRILL/` is all that is needed. There is no
`project.pbxproj` edit and no file list to keep in step.

## Content

`ios/DRILL/Resources/exercises.json` is the single source for all 39 exercises and
203 steps. Nothing else in the repo holds a copy.

The 33 exercises migrated from the web app keep their step text **verbatim**; only
metadata was added, and the validator still proves it character for character. The
6 basketball and baseball drills were written for the app and have no counterpart
there, so the validator schema-checks them and skips the fidelity comparison.

```sh
node tools/validate-content.js            # schema + proves migrated step text still matches site/app/index.html
node tools/timing-report.js > review.html # human review of every timing decision
node tools/build-site-exercises.js        # regenerates site/exercises.html from the JSON
```

Run the validator after any content change, and the site generator too, or the public
library page goes stale.

Each step carries a `role` (`setup`, `form`, `cue`, `action`) and a nullable `timing`.
Only `action` steps advance the walkthrough — that is what takes the 27 stepped
exercises from 138 screens down to 68. Timings are `work`, `reps`, `interval` (work and
rest inside one step) or `loop` (this step is the rest phase plus a jump back to an
earlier step).

## Architecture notes

- **`PlanGenerator`** replaces the web app's hardcoded 10-week rotation. It composes each
  day as warmup → drills weighted to the chosen sports → strength/plyo finisher →
  cooldown, from a seeded PRNG over `(seed, weekIndex, weekday)`. It must stay
  deterministic: **never iterate a `Set` to build an exercise pool** — Swift gives two
  sets with the same elements no guaranteed order, and that silently broke determinism
  once. `ExerciseLibrary.exercises(taggedAnyOf:)` sorts for exactly this reason.
- **`Walkthrough`** expands an exercise into `WalkPhase`s; `WalkthroughEngine` runs them
  against an absolute deadline so the clock never drifts.
- **Storage:** SwiftData (`CompletionRecord`, `PersonalRecord`, `EarnedBadge`) behind
  `TrainingStore`, which reads everything into memory once. Plan settings are JSON in
  `UserDefaults` via `SettingsStore`.
- **Streaks are forgiving on purpose:** rest days never break one, and today does not
  break one until the day is over. See `ProgressCalculator`.
- **No network calls anywhere.** No accounts, no analytics, no third-party SDKs, no
  HealthKit. The App Store privacy label is "Data Not Collected", and that has to stay
  true by construction rather than by policy.

## Screens

Today (the day's session) · Calendar (month grid, tap a day to open it) · Progress
(streak, stats, badges, records) · Settings. `AppState` holds the selected date and
tab, because tapping a day in Calendar has to do both.

## Visual language

Ported from the web app and unchanged: `--green #22D68A` header on a dark ground,
rounded card stack, uppercase colored tag under each exercise name, numbered green step
circles. Tokens live in `ios/DRILL/Views/Theme.swift` and `site/style.css` — keep the
two in step. The app follows the system appearance and has no theme toggle of its own.

## Customizing

To add an exercise: add an entry to `exercises.json`, then run the validator and the
site generator. The plan generator picks it up from its `tag` automatically — there is
no schedule table to edit.
