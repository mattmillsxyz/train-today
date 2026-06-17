# Train Today

Single-file HTML/JS app for a young multi-sport athlete. No frameworks, no build step.

## Stack
- Pure HTML/CSS/JS in a single `index.html` file
- No dependencies, no build process — open in any browser
- PWA-ready: `apple-touch-icon.png`, `theme-color`, `apple-mobile-web-app-*` meta tags
- Deployed at https://train-today.netlify.app/

## Activities
Soccer drills, football, track, strength, cardio, plyometrics. Each activity has a name, duration, tag, and numbered step-by-step instructions.

## Schedule
10-week rotating plan defined in `weekPatterns`. Each week is Mon-Sun. The schedule cycles forever from the epoch date defined in `EPOCH`.

## Layout
- `#app` is centered, max-width 600px, with 12px side/bottom padding
- `.header-wrap` is the sticky container (dark background, `top: 0`, `z-index: 10`). It holds `.header` (green, rounded top corners). This two-layer structure prevents the task list from peeking through the rounded corners on scroll.
- `.activity-item:last-child` has rounded bottom corners to bookend the card look
- `apple-mobile-web-app-status-bar-style` is set to `black` (not `black-translucent`) so the iOS status bar stays solid, not transparent

## Key files
- `index.html` — entire app
- `favicon.png` — 256x256 browser favicon
- `apple-touch-icon.png` — 180x180 iOS home screen icon
- `train-today-app-screenshot.png` — used in README and OpenGraph tags

## Customizing
To add an exercise: add an entry to `ACTIVITIES` in the script block, then reference it in a `dayWorkouts` entry.

To change the schedule: edit `weekPatterns`. Each row is one week (Mon-Sun), each value is a key from `dayWorkouts`.
