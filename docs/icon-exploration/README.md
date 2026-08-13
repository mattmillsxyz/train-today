# App icon exploration

**Status: closed — superseded.** None of these shipped. The icon is now the supplied
DRILL wordmark; see [`brand/`](../../brand/README.md). This directory is kept only as a
record of what was tried and why, and the font-licensing caveat below no longer applies
since the final mark is artwork rather than type.

Each `make*.js` writes 1024×1024 SVGs into its own directory; render and review with:

```sh
cd docs/icon-exploration && node make6.js
for f in r6-*.svg; do rsvg-convert -w 1024 -h 1024 "$f" -o "${f%.svg}.png"; done
```

The contact sheets show each candidate squircle-masked at review size and again at
true home-screen size, because 60pt is where these decisions are actually made.

## Where it got to

| Round | What was tried | Outcome |
|---|---|---|
| 1 | Cone, cone + weave, agility ladder, three cones, chevrons, D monogram | The training cone is the strongest concept. Weave path read as scattered dots; ladder read as a railway track; three cones turned to mush; chevrons read as a generic UI affordance. |
| 2 | Squat cone: stripe placement, colour direction, motion arc | The reflective stripe is load-bearing — without it the shape reads as a mountain or a play button. The motion arc read as a rainbow. |
| 3 | Striped cone vs. a D whose counter is a cone | Both work at 1024. At 60pt the D's counter collapses and it becomes a plain letter that says nothing about the product. |
| 4 | Wordmarks in Avenir Next Condensed Heavy | Too light to read as athletic. Replacing the I with a cone lost the letter — it read "DRΛLL". |
| 5 | Wordmarks in Futura Condensed ExtraBold | Right weight. But the shear was taken about the origin, so the word walked off the left edge. |
| 6 | Same, sheared about the word's optical centre | Fixed. Upright, sheared, jersey-shadow, split-tile and speed-line variants all render correctly. **Not yet reviewed or chosen.** |

## Before anything ships

- **Licensing.** Rounds 4–6 are set in fonts bundled with macOS (Avenir, Futura). Those
  licences do not cover use as a logo or trademark. The final wordmark needs either a
  display face licensed for the purpose, an SIL OFL face (Anton, Archivo Black, Oswald,
  Barlow Condensed all qualify), or letterforms drawn from scratch. The mockups here
  are for choosing a direction, not for shipping.
- The App Store icon must be 1024×1024, opaque, and square — iOS applies the squircle.
- Whatever wins, check it at 60pt against a home screen of real apps, not on its own.
