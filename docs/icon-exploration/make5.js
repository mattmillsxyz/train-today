#!/usr/bin/env node
// Round five: Futura Condensed ExtraBold throughout — it was the only face with
// enough weight to read as athletic rather than merely condensed.

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const INK = '#0D0D0D';
const GREEN = '#22D68A';
const GREEN_DEEP = '#0C9C5F';

const wrap = (bg, body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<rect width="1024" height="1024" fill="${bg}"/>
${body}
</svg>`;

/**
 * DRILL, centred. `squeeze` condenses horizontally so the point size — and so
 * the stroke weight — can go up without the word running off the tile.
 */
const word = ({ size = 350, tracking = -6, fill = INK, y = 634, skew = 0, squeeze = 1, x = 512 } = {}) =>
  `<g transform="translate(${x} 0) skewX(${skew}) translate(${-x} 0)">
    <g transform="translate(${x} 0) scale(${squeeze} 1) translate(${-x} 0)">
      <text x="${x}" y="${y}" font-family="Futura" font-weight="bold" font-size="${size}"
        letter-spacing="${tracking}" text-anchor="middle" fill="${fill}">DRILL</text>
    </g>
  </g>`;

const c = {};

// F1 — upright, as heavy as the tile allows.
c['F1-upright'] = wrap(GREEN, word({ size: 340, tracking: -4 }));

// F2 — sheared forward.
c['F2-italic'] = wrap(GREEN, word({ size: 340, tracking: -4, skew: -12 }));

// F3 — sheared, green on the app's near-black.
c['F3-italic-dark'] = wrap(INK, word({ size: 340, tracking: -4, skew: -12, fill: GREEN }));

// F4 — squeezed harder so the point size can go up: taller, heavier letters.
c['F4-squeezed'] = wrap(GREEN, word({ size: 430, tracking: -14, skew: -12, squeeze: 0.78, y: 660 }));

// F5 — speed lines, kept clear of the D this time.
c['F5-speedlines'] = wrap(
  INK,
  `<g transform="translate(512 0) skewX(-12) translate(-512 0)">
    <rect x="70" y="392" width="150" height="38" rx="19" fill="${GREEN_DEEP}"/>
    <rect x="40" y="474" width="196" height="38" rx="19" fill="${GREEN_DEEP}"/>
    <rect x="82" y="556" width="132" height="38" rx="19" fill="${GREEN_DEEP}"/>
  </g>
  ${word({ size: 320, tracking: -6, skew: -12, fill: GREEN, x: 600, y: 620 })}`
);

// F6 — the word over lane bars.
c['F6-lane-bars'] = wrap(
  GREEN,
  `${word({ size: 320, tracking: -4, skew: -12, y: 566 })}
  <g transform="translate(512 0) skewX(-12) translate(-512 0)">
    <rect x="164" y="632" width="696" height="48" rx="24" fill="${INK}"/>
    <rect x="164" y="716" width="432" height="48" rx="24" fill="${INK}" opacity="0.45"/>
  </g>`
);

// F7 — jersey-number treatment: an offset shadow in the deeper green.
c['F7-jersey'] = wrap(
  GREEN,
  `${word({ size: 340, tracking: -4, skew: -12, fill: GREEN_DEEP, x: 512, y: 634 }).replace(
    '<g transform="translate(512 0) skewX(-12)',
    '<g transform="translate(26 22) translate(512 0) skewX(-12)'
  )}
  ${word({ size: 340, tracking: -4, skew: -12 })}`
);

// F8 — squeezed and dark, the inverse of F4.
c['F8-squeezed-dark'] = wrap(
  INK,
  word({ size: 430, tracking: -14, skew: -12, squeeze: 0.78, y: 660, fill: GREEN })
);

for (const [name, svg] of Object.entries(c)) {
  fs.writeFileSync(path.join(OUT, `r5-${name}.svg`), svg);
}
console.log(Object.keys(c).join('\n'));
