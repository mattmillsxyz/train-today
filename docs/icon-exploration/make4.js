#!/usr/bin/env node
// Wordmark icons. Five letters in a square is the whole problem, so every one
// of these is a heavy condensed face pushed close to the tile edges.

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const INK = '#0D0D0D';
const GREEN = '#22D68A';
const GREEN_DEEP = '#0FA968';

const AVENIR = 'Avenir Next Condensed Heavy';
const FUTURA = 'Futura';

const wrap = (bg, body, defs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>${defs}</defs>
<rect width="1024" height="1024" fill="${bg}"/>
${body}
</svg>`;

/** DRILL as one line, centred, optionally sheared forward. */
const word = ({
  family = AVENIR,
  weight = 'normal',
  size = 300,
  tracking = -6,
  fill = INK,
  y = 620,
  skew = 0,
  x = 512,
  text = 'DRILL',
} = {}) =>
  `<g transform="translate(${x} 0) skewX(${skew}) translate(${-x} 0)">
    <text x="${x}" y="${y}" font-family="${family}" font-weight="${weight}" font-size="${size}"
      letter-spacing="${tracking}" text-anchor="middle" fill="${fill}">${text}</text>
  </g>`;

const c = {};

// W1 — upright, black on green, filling the tile.
c['W1-upright-green'] = wrap(GREEN, word({ size: 330, tracking: -10, y: 626 }));

// W2 — the same, sheared forward. Speed by posture alone.
c['W2-italic-green'] = wrap(GREEN, word({ size: 330, tracking: -10, y: 626, skew: -12 }));

// W3 — Futura Condensed ExtraBold, upright.
c['W3-futura-green'] = wrap(
  GREEN,
  word({ family: FUTURA, weight: 'bold', size: 320, tracking: -4, y: 622 })
);

// W4 — sheared, green on the app's near-black.
c['W4-italic-dark'] = wrap(INK, word({ size: 330, tracking: -10, y: 626, skew: -12, fill: GREEN }));

// W5 — speed lines trailing the word.
c['W5-speedlines'] = wrap(
  INK,
  `<g transform="translate(512 0) skewX(-12) translate(-512 0)">
    <rect x="96" y="404" width="240" height="42" rx="21" fill="${GREEN_DEEP}"/>
    <rect x="60" y="492" width="300" height="42" rx="21" fill="${GREEN_DEEP}"/>
    <rect x="112" y="580" width="210" height="42" rx="21" fill="${GREEN_DEEP}"/>
  </g>
  ${word({ size: 290, tracking: -8, y: 612, skew: -12, fill: GREEN, x: 566 })}`
);

// W6 — sheared word split by a diagonal, the halves offset. Motion as a glitch.
c['W6-shear-split'] = wrap(
  GREEN,
  `<defs>
    <clipPath id="top"><rect x="0" y="0" width="1024" height="512"/></clipPath>
    <clipPath id="bot"><rect x="0" y="512" width="1024" height="512"/></clipPath>
  </defs>
  <g clip-path="url(#top)">${word({ size: 330, tracking: -10, y: 626, skew: -12, x: 556 })}</g>
  <g clip-path="url(#bot)">${word({ size: 330, tracking: -10, y: 626, skew: -12, x: 468 })}</g>`
);

// W7 — the word sitting on a lane bar.
c['W7-lane-bar'] = wrap(
  INK,
  `${word({ size: 300, tracking: -10, y: 560, skew: -12, fill: GREEN })}
  <g transform="translate(512 0) skewX(-12) translate(-512 0)">
    <rect x="150" y="640" width="724" height="54" rx="27" fill="${GREEN}"/>
    <rect x="150" y="726" width="470" height="54" rx="27" fill="${GREEN_DEEP}"/>
  </g>`
);

// W8 — the I becomes a cone, so the mark still says what the app is.
{
  const cone = `<g transform="translate(516 0)">
    <path d="M 0 396 L 74 610 L -74 610 Z" fill="${INK}" stroke="${INK}" stroke-width="34" stroke-linejoin="round"/>
    <rect x="-104" y="626" width="208" height="42" rx="21" fill="${INK}"/>
  </g>`;
  c['W8-cone-i'] = wrap(
    GREEN,
    `<text x="470" y="626" font-family="${AVENIR}" font-size="330" letter-spacing="-10"
      text-anchor="end" fill="${INK}">DR</text>
    ${cone}
    <text x="586" y="626" font-family="${AVENIR}" font-size="330" letter-spacing="-10"
      text-anchor="start" fill="${INK}">LL</text>`
  );
}

for (const [name, svg] of Object.entries(c)) {
  fs.writeFileSync(path.join(OUT, `r4-${name}.svg`), svg);
}
console.log(Object.keys(c).join('\n'));
