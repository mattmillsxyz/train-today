# Train Today → DRILL, a native iOS app

## Where this stands

Working branch: `claude/exercises-steps-listing-uuzzxl`.

**Phases 0 through 7 are built and verified on the Mac.** The app compiles, runs in the simulator
and passes 60 unit tests; the marketing site renders clean at 320/390/768/1280 in both themes with
no horizontal overflow and no dead links. What remains is Phase 8: App Store assets, listing copy
and submission.

```sh
cd ios && xcodebuild -project DRILL.xcodeproj -scheme DRILL \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
node tools/validate-content.js            # schema + step text still matches the web app verbatim
node tools/build-site-exercises.js        # regenerates site/exercises.html
```

### Decisions taken after this plan was written

- **The app is called DRILL.** Home-screen name `DRILL`; App Store name
  *DRILL: Youth Sports Training*; subtitle *Soccer, football, track, strength*. Bundle id
  `com.trainwithdrill.drill`, domain `trainwithdrill.com`. The Xcode target, module, directories
  and tooling paths were all renamed to match. **Still to verify: that the App Store name is free.**
- **The week strip is gone; there is a Calendar tab.** Today is now just today's session. A
  scrollable Monday-first month grid colours every day by status — done, partly, scheduled,
  missed, rest — and tapping a day opens it on Today. The heat map that was planned for Progress
  was dropped as duplicative; Progress keeps the streak, the headline numbers, badges and records.
- **The onboarding welcome screen is full-bleed brand**, not a padded bullet list: near-black
  ground, green runner mark, DRILL wordmark at display size, feature cards animating in.

### Two things worth remembering

- **`Set` iteration order is not stable across instances in Swift.** Building an exercise pool by
  iterating a `Set<Tag>` made the generator non-deterministic — the same seed and date produced
  different sessions depending on when they were asked for. The year-long determinism property
  test caught it. `ExerciseLibrary.exercises(taggedAnyOf:)` now sorts, and a regression test pins it.
- **The session budget needs reserving up front.** Spending the whole budget on the focus sport
  first meant one 20-minute bike ride could eat the day, leaving an all-cardio session with no
  finisher. The generator now holds back the cheapest secondary drill and the cheapest finisher
  before it spends anything.

### Walkthrough design (agreed after the plan below was written)

Reading a step at a time means holding the phone, which an 8-12 year old mid-drill cannot do. The
`role` field is what fixes it — only `action` steps advance the walkthrough, taking the 25 stepped
exercises from 129 screens to 64 (Push-Ups: five screens to one).

- **Get-ready screen** — `setup` steps and the `form` reference, before the timer starts. Start button.
- **Walkthrough** — `action` steps only. `cue` steps show during the work, never gate it.
- **Speak each step** via `AVSpeechSynthesizer` — first-party, offline. The main reason he can put
  the phone down.
- **Auto-advance every timed step**; only genuinely self-paced actions wait for a tap.
- **Whole screen is the tap target** when a tap is needed.
- **Live Activity moved into v1** — Lock Screen countdown is the honest fix for a phone in a pocket
  during sprints, not the ambient nicety it was filed as.

## Context

`index.html` is a single-file vanilla JS app that serves one young athlete a daily workout from a
hardcoded 10-week rotation. It has proved useful over a summer of real use, and that use surfaced
four gaps: the plan is fixed for everyone, the timer only counts the whole exercise, there are no
reminders, and nothing is tracked across days. The exercise content itself is good and stays — the
step-by-step instructions written for an 8-12 year old are the app's real asset.

The outcome: a native SwiftUI app on the public App Store. The web app is retired and its domain
becomes a small marketing site carrying the landing page, privacy policy, terms, and support page
that App Store submission requires. Same voice, same green, same card layout in the app — this is a
migration and an expansion, not a redesign.

**Decisions locked:** Native SwiftUI, zero third-party dependencies · Public App Store ·
`ios/` directory in this repo · Web app deprecated, replaced by marketing site ·
**No HealthKit** — streak and progress tracking is local to the app · Audio cues + haptics baseline.

### v1 scope vs. deferred

| In v1 | Deferred to v1.1 |
|---|---|
| Configurable plan + onboarding | Live Activity / Dynamic Island timer |
| Per-step countdown timers | Home screen widget |
| Reminder notifications | Apple Health integration |
| Streaks, badges, local progress | |
| Personal records | |

Live Activity and the widget both need a Widget Extension target plus App Group plumbing — a chunk of
infrastructure for two ambient features. Both are much easier once the timer engine is settled, and
neither blocks a useful v1. Easy to pull forward if you'd rather have them at launch.

---

## The one real risk

**Content restructuring is the largest single task.** Per-step countdowns require every step to carry
timing metadata, and the current steps are prose that bundles work, rest, and rounds into one sentence
("Do 10, rest 30 seconds, repeat 3 sets"). That's ~33 exercises × ~5 steps ≈ 170 steps to annotate.
Approach: mechanical first pass by regex, then hand-correction, then **your review** — it's your son's
actual training content and the timings should be right. Do this early; everything downstream reads
this model.

Also verify early: that the App Store name is free. *(Superseded — the app is now called DRILL;
see the decisions at the top. The check itself is still outstanding.)*

*(Dropping HealthKit removed the other week-1 risk — child accounts under Family Sharing have
restrictions around Health data that would have needed verifying on his actual device before the
progress feature could be designed around it. Local tracking sidesteps this entirely.)*

---

## Sequencing note: don't deprecate early

He uses the web app daily. Retire it only once the iOS app is actually on his phone — otherwise
there's a gap where he has no tool. Keep the working app deployed at a subpath (`/app/`) while the
marketing site goes up at the root, and delete it after the App Store release.

---

## Data model

The current shape (`index.html:563`) is `{ name, duration: "6 min · 3×10", tag, steps: [String] }`.
The duration string is human prose that `parseDurationMin` already has to `parseInt` its way out of.
Replace both with structured data:

```swift
struct Exercise: Codable, Identifiable {
    let id: String              // "jugglingBasic" — preserve existing keys
    let name: String
    let tag: Tag                // soccer, football, track, strength, cardio, plyo, balance, warmup, stretch
    let estimatedMinutes: Int
    let steps: [Step]
    let prMetric: PRMetric?     // juggling streak, broad jump distance, cone-dribble time…
}

struct Step: Codable {
    let text: String
    let timing: Timing?         // nil = read-and-do, tap to advance
}

enum Timing: Codable {
    case work(seconds: Int)                                  // "Jog in place for 1 minute"
    case reps(count: Int, perSide: Bool)                     // "swing each leg 10 times"
    case interval(work: Int?, reps: Int?, rest: Int, rounds: Int)  // "Do 10, rest 30s, 3 sets"
}
```

`Timing` is what drives the per-step timer: `.work` counts down, `.reps` shows a tap-to-advance
counter with no clock, `.interval` walks rounds and counts down only the rest phases (and the work
phase when it's time-based, as in "Hold 30 seconds. Rest 20 seconds. Repeat 3 times").
`estimatedMinutes` is now derived from the steps rather than parsed back out of a display string.

`ios/DRILL/Resources/exercises.json` is the sole home for this content. With the web app retired
there's nothing to sync it to — the earlier plan's `tools/sync-content.js` is no longer needed.

---

## Replacing the fixed schedule

`weekPatterns` (`index.html:992`) and `dayWorkouts` (`index.html:1006`) are hardcoded — 10 weeks,
every day, one athlete. Replace with a generator driven by onboarding settings:

```swift
struct PlanSettings {
    var sports: Set<Tag>        // chosen in onboarding
    var daysPerWeek: Int
    var sessionMinutes: Int
    var seed: UInt64            // fixed at onboarding
}
```

`PlanGenerator.session(for: Date, settings:)` composes a day the same way the existing `dayWorkouts`
entries do, because that structure already works: **warmup → 3-4 main drills weighted to the chosen
sports → a strength/plyo finisher → cooldown**. Every current entry follows exactly this shape
(`dynamicWarmup` first, `coolDownStretch`/`hipMobility` last).

Two properties matter:

- **Deterministic.** Seeded PRNG over `(seed, weekIndex, dayIndex)`, so the same inputs always yield
  the same session. The plan must not reshuffle when he reopens the app mid-workout.
- **Regenerates cleanly.** Changing sports in Settings changes future sessions; completed history is
  keyed by `(date, exerciseID)` and is unaffected.

Constraints in the generator: no drill repeats on consecutive days, sports rotate rather than
clustering, and the session lands within `sessionMinutes`.

---

## Screens

Reuse the existing visual language throughout — `--green #22D68A` header on a dark ground, rounded
card stack, uppercase colored tag under each exercise name, numbered step circles.

| Screen | Notes |
|---|---|
| **Onboarding** | Welcome → name → **sport picker** (large tappable cards, the existing emoji set) → days/week + session length → reminder setup → first-week preview. Notification permission fires in context, never on launch. |
| **Today** | Port of the current view: header, week strip, progress bar, expandable exercise cards. |
| **Timer** | Per-step countdown. Full-screen green, as now, but walking steps rather than one clock. |
| **Progress** | Streak, calendar heat map, badge shelf, PR list. |
| **Settings** | Change sports/days/length, reminder config, re-run onboarding. |

### Timer detail (feature #2)

The current timer (`index.html:1381`) takes one duration for the whole exercise and lists steps
statically beside it. The new one advances through steps: current step large and centered, next step
previewed below, countdown ring for `.work` and rest phases, a tap-to-advance button for `.reps`
steps, round counter ("Set 2 of 3") for `.interval`. Audio cue + haptic on every phase transition so
he doesn't have to watch the screen mid-drill — this is why it matters that sprint drills say
"sprint 40 yards and walk back". Keep `playCompleteSound`'s three-buzzer finish; it works.

### Reminders (feature #3)

Local notifications via `UNUserNotificationCenter` — **no backend, no server, no push certificates**.
One repeating `UNCalendarNotificationTrigger` per selected weekday (≤7 pending, far under the 64
limit). The config UI is day-of-week chips plus a time picker, styled off the existing `.week-strip`
day cells.

### Progress, streaks, badges, PRs (feature #4)

- **Store:** SwiftData for workout history and PRs; `@AppStorage` for settings. First-party, no
  dependencies, and gives the streak/calendar/PR queries for free.
- **Streaks:** day counter with a calendar heat map. Deliberately forgiving — a missed day shouldn't
  feel punitive to a 9-year-old. Consider a "rest day doesn't break the streak" rule tied to the
  configured days/week, since the plan already assumes he isn't training seven days.
- **Badges:** ~12, concrete and reachable — first workout, 7-day streak, 30-day streak, 100 workouts,
  every-sport week, PR milestones.
- **PRs:** the content already asks for this. "Count your best streak! Write it down and try to beat
  it tomorrow" (juggling), "Mark where you landed. Try to beat your distance" (broad jumps), "time
  yourself and try to beat your record" (cone dribbling). The `prMetric` field turns those prompts
  into a logged number with a history sparkline — the app becomes the place he writes it down.

---

## Marketing site

Replaces the web app at `train-today.netlify.app`. Static HTML, no build step, same deploy — matching
the existing repo ethos. Three of these pages exist to satisfy App Store submission, which requires a
**support URL** and a **privacy policy URL** as mandatory fields.

| Page | Purpose |
|---|---|
| `index.html` | Landing: what it is, who it's for, screenshots, App Store link |
| `privacy.html` | **Required by App Store.** Short and true: no accounts, no tracking, nothing leaves the device |
| `terms.html` | Terms of use, including the "check with a parent, stop if it hurts" safety language |
| `support.html` | **Required by App Store.** Contact route + a few FAQs |
| `exercises.html` | Keep it — restyled as a public library showcase. Good proof of substance and good SEO: "every exercise, with full instructions" |

The current app HTML moves to `/app/` during the transition and is deleted after launch.

---

## App Store compliance

The app's architecture clears most of this by design: **no accounts, no network calls, no analytics,
no third-party SDKs, and — now that HealthKit is out — no sensitive data of any kind. Nothing leaves
the device.**

- **Privacy Nutrition Label:** "Data Not Collected." True as designed — keep it true.
- **COPPA:** an app directed at children needs parental consent *for data collection*. Collecting
  nothing is the cleanest possible position.
- **Kids Category:** recommend *not* opting in. It bans third-party analytics and ads (fine, we have
  none) but adds parental-gate requirements and review friction. Ship as 4+ without the category.
- **Guideline 1.4.1 (physical harm):** brief safety note in onboarding — check with a parent, stop if
  something hurts — plus the same in terms and the store description. Sensible for an 8-12 audience
  independent of the guideline.
- **Assets:** 1024×1024 App Store icon needed; the existing `favicon.png` (256) and
  `apple-touch-icon.png` (180) are too small to upscale. Plus screenshots per device class.

Deployment target **iOS 17.0** — needed for SwiftData, and broad enough in 2026.

---

## Build order

0. ✅ **Foundations** — Xcode project under `ios/`, iOS 17 target, 1024 app icon.
1. ✅ **Content migration** — `exercises.json` with structured steps, validation script, review pass.
2. ✅ **Marketing site** — landing, privacy, terms, support, generated exercises showcase.
3. ✅ **Plan generator + Today** — replaces the fixed rotation; deterministic and property-tested.
4. ✅ **Per-step timer** — phase expansion, speech, haptics, the three-buzzer finish.
5. ✅ **Onboarding + Settings** — including the redesigned welcome screen.
6. ✅ **Reminders** — one repeating local trigger per training day.
7. ✅ **Streaks, badges, PRs, progress** — plus the Calendar tab.
8. ⬜ **App Store prep** — screenshots per device class, listing copy, submission.

### What Phase 8 still needs

- **Verify the App Store name is free** before anything else.
- **A real 1024 icon — the current one is rejected and must not ship.** It is the old web app's
  runner glyph upscaled from the 256px favicon, and it is essentially the watchOS Workout icon.
  Exploration so far, with contact sheets and the scripts that generated them, is in
  [`docs/icon-exploration/`](icon-exploration/README.md); the live direction is a DRILL wordmark
  in a heavy condensed face. Note the font-licensing constraint recorded there.
- Screenshots per device class, listing copy, the privacy questionnaire (answer: Data Not
  Collected), age rating 4+, and the support/privacy URLs — both live on the site already.
- Point `trainwithdrill.com` at the site and confirm `/app/` still serves the old web app.

---

## Files

**New:**
- `ios/DRILL.xcodeproj` and `ios/DRILL/` — `Models/` (`Exercise`, `PlanGenerator`,
  `PlanSettings`), `Views/` (`Onboarding`, `Today`, `Timer`, `Progress`, `Settings`),
  `Services/` (`NotificationService`, `Store`), `Resources/exercises.json`
- `site/` — marketing site: `index.html`, `privacy.html`, `terms.html`, `support.html`,
  `exercises.html`
- `tools/validate-content.js` — asserts every step parses to a valid `Timing` or explicit `nil`

**Retired:**
- Current `index.html` — moves to `/app/` during transition, deleted after App Store release
- Current `exercises.html` — content reused for the marketing showcase page

**Modified:**
- `CLAUDE.md`, `README.md` — document the iOS app and the marketing site, drop the single-file
  web app framing

**Reused as-is:** the exercise library content and voice, the color tokens and card layout, the
`dayWorkouts` session shape (warmup → drills → finisher → cooldown), and `playCompleteSound`'s
three-buzzer finish.

---

## Verification

**In this container:**
- **Content:** `tools/validate-content.js` asserts every step parses into a valid `Timing` or an
  explicit `nil`, and that no exercise's derived `estimatedMinutes` drifts far from its old
  `duration` string. Then read the generated steps against the originals — a side-by-side diff of
  old prose → new structured timing for your review.
- **Marketing site:** render every page headless at phone and desktop widths, screenshot both
  themes, confirm no horizontal scroll and no dead links.

**On your Mac:**
- **Generator:** unit tests for determinism (same seed+date → same session across runs), no
  consecutive-day drill repeats, sports honored, duration within budget. Property test across a
  simulated year for each sport combination.
- **Timer:** step through a `.interval` exercise (Plank Hold: 3 × 30s work / 20s rest) and confirm
  round counting, cues, and haptics. Confirm `.reps` steps show no countdown.
- **Notifications:** schedule for the next minute on device, confirm delivery, confirm repeat, and
  confirm changing settings clears stale triggers.
- **End-to-end:** fresh install → onboarding → generated plan → complete a full session → streak
  increments, badge fires, PR logs.
