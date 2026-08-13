# Brand assets

`drill-wordmark-master.png` is the supplied artwork: 4096×4096, bilevel, a white
wordmark on transparency. `drill-wordmark-trimmed.png` is the same thing cropped to
the mark itself, 3164×846 — an aspect ratio of **3.74:1**, which every derivative
below is cut from and which the layout code hard-codes.

Everything is generated from those two files. There is no vector source; the master
is high enough resolution that nothing in the app, the icon or the site is resampling
up, so a trace would only lose fidelity. If a true vector is ever needed, trace the
master with `potrace` rather than redrawing it.

The mark is white on transparency on purpose: it is used as a **mask**, so each
surface paints its own colour through the artwork's alpha rather than shipping a
recoloured copy per context.

## Derivatives

| Output | Built from | Notes |
|---|---|---|
| `ios/DRILL/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | green mark on `#0D0D0D` | Mark at 88% of tile width. Opaque, square, 8-bit, no alpha — the App Store rejects all three. |
| `ios/DRILL/Assets.xcassets/Wordmark.imageset/` | white mark, 1x/2x/3x | Template-rendered; `WelcomePage` masks `Theme.green` through it. |
| `site/img/wordmark-white.png` | white mark, 1200px | The CSS mask. `.brand-word` paints `var(--text)`, `.hero-word` paints `var(--green)`. |
| `site/img/icon-1024.png`, `site/favicon.png`, `site/apple-touch-icon.png` | the app icon | Resized copies. |

There is deliberately no pre-coloured green PNG for the site: every surface masks the
white master, so a recoloured copy would be a second thing to keep in step.

## Regenerating

```sh
cd brand
magick drill-wordmark-trimmed.png -resize 3164x -alpha extract /tmp/a.png
magick -size 3164x846 xc:'#22D68A' /tmp/a.png -alpha off -compose CopyOpacity -composite /tmp/green.png
magick -size 1024x1024 xc:'#0D0D0D' \( /tmp/green.png -resize 901x \) -gravity center \
  -composite -alpha remove -alpha off -depth 8 -strip \
  PNG24:../ios/DRILL/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

## Why 88%

A 3.74:1 wordmark in a 1:1 tile is the whole design problem — fit it to the width and
it occupies only about a quarter of the height. 78%, 88% and 98% were all rendered and
checked at 60pt, the size that actually matters. 98% crowds the squircle, 78% wastes
the tile; 88% leaves roughly 60px of margin each side and still reads at 60pt.

The brand text beside the header icon was dropped when the icon became the wordmark —
showing both stuttered "DRILL DRILL". Same reason the hero's separate icon went.
