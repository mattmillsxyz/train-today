#!/usr/bin/env node
// Round six. Same face, with the shear taken about the word's optical centre so
// it stops walking off the left edge of the tile.

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const INK = '#0D0D0D';
const GREEN = '#22D68A';
const GREEN_DEEP = '#0C9C5F';
const GREEN_LIT = '#3AEBA0';

const wrap = (bg, body, defs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>${defs}</defs>
<rect width="1024" height="1024" fill="${bg}"/>
${body}
</svg>`;

/**
 * `skewX` displaces x by `-tan(angle) · y`, so shearing about the origin drags
 * the whole word sideways by ~135px at this baseline. Shearing about the word's
 * optical centre (`cy`) keeps it put.
 */
const word = ({
  size = 430,
  tracking = -14,
  fill = INK,
  y = 656,
  skew = -12,
  squeeze = 0.78,
  cx = 512,
  cy = 510,
  dx = 0,
  dy = 0,
} = {}) =>
  `<g transform="translate(${dx} ${dy}) translate(${cx} ${cy}) skewX(${skew}) scale(${squeeze} 1) translate(${-cx} ${-cy})">
    <text x="${cx}" y="${y}" font-family="Futura" font-weight="bold" font-size="${size}"
      letter-spacing="${tracking}" text-anchor="middle" fill="${fill}">DRILL</text>
  </g>`;

const c = {};

// G1 — upright and square-on. The safe one.
c['G1-upright'] = wrap(GREEN, word({ skew: 0, squeeze: 0.82, size: 420, tracking: -10 }));

// G2 — sheared, black on green.
c['G2-italic-green'] = wrap(GREEN, word({}));

// G3 — sheared, green on the app's near-black.
c['G3-italic-dark'] = wrap(INK, word({ fill: GREEN }));

// G4 — jersey numbering: an offset shadow in the deeper green.
c['G4-jersey'] = wrap(GREEN, `${word({ fill: GREEN_DEEP, dx: 26, dy: 22 })}\n${word({})}`);

// G5 — the tile itself cut on the diagonal, two greens.
c['G5-split-tile'] = wrap(
  GREEN,
  `<path d="M 0 1024 L 1024 0 L 1024 1024 Z" fill="${GREEN_LIT}"/>
  ${word({})}`
);

// G6 — speed lines, this time entirely inside the tile.
c['G6-speedlines'] = wrap(
  INK,
  `<g transform="translate(512 510) skewX(-12) translate(-512 -510)">
    <rect x="104" y="392" width="132" height="34" rx="17" fill="${GREEN_DEEP}"/>
    <rect x="78" y="470" width="172" height="34" rx="17" fill="${GREEN_DEEP}"/>
    <rect x="114" y="548" width="116" height="34" rx="17" fill="${GREEN_DEEP}"/>
  </g>
  ${word({ fill: GREEN, size: 380, squeeze: 0.74, cx: 600, tracking: -12, y: 640 })}`
);

for (const [name, svg] of Object.entries(c)) {
  fs.writeFileSync(path.join(OUT, `r6-${name}.svg`), svg);
}
console.log(Object.keys(c).join('\n'));
