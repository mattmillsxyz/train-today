#!/usr/bin/env node
// Renders DRILL app-icon candidates as 1024 SVGs for review.

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const INK = '#0D0D0D';
const GREEN = '#22D68A';
const GREEN_DEEP = '#12B873';

const wrap = (bg, body, defs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>${defs}</defs>
<rect width="1024" height="1024" fill="${bg}"/>
${body}
</svg>`;

// ── The cone: a rounded triangle over a base slab, with a reflective stripe ──
function cone(fg, bg, { stripe = true, scale = 1, dx = 0, dy = 0, stripeY = 470 } = {}) {
  const id = `m${Math.random().toString(36).slice(2, 8)}`;
  const body = `M 512 186 L 664 752 L 360 752 Z`;
  const t = `translate(${dx} ${dy}) translate(512 560) scale(${scale}) translate(-512 -560)`;
  return {
    defs: stripe
      ? `<mask id="${id}"><rect width="1024" height="1024" fill="black"/>
         <g transform="${t}"><path d="${body}" fill="white" stroke="white" stroke-width="58" stroke-linejoin="round"/></g></mask>`
      : '',
    body: `<g transform="${t}">
  <path d="${body}" fill="${fg}" stroke="${fg}" stroke-width="58" stroke-linejoin="round"/>
  <rect x="176" y="776" width="672" height="92" rx="46" fill="${fg}"/>
</g>
${stripe ? `<g mask="url(#${id})"><rect x="180" y="${stripeY}" width="664" height="86" fill="${bg}"/></g>` : ''}`,
  };
}

const candidates = {};

// 1. Cone, green on the app's near-black.
{
  const c = cone(GREEN, INK);
  candidates['1-cone-dark'] = wrap(INK, c.body, c.defs);
}

// 2. Cone, inverted: the icon becomes a green tile on the home screen.
{
  const c = cone(INK, GREEN);
  candidates['2-cone-green'] = wrap(GREEN, c.body, c.defs);
}

// 3. Cone with the weave path a dribbling drill actually traces.
{
  const c = cone(GREEN, INK, { scale: 0.78, dy: -40 });
  candidates['3-cone-weave'] = wrap(
    INK,
    `<path d="M 168 806 C 300 806 300 690 424 690 C 548 690 548 806 672 806 C 796 806 796 690 900 690"
       fill="none" stroke="${GREEN_DEEP}" stroke-width="46" stroke-linecap="round"
       stroke-dasharray="6 92" opacity="0.95"/>
     ${c.body}`,
    c.defs
  );
}

// 4. Agility ladder, seen down its length.
{
  const rungs = [0, 1, 2, 3, 4]
    .map((i) => {
      const t = i / 4;
      const y = 828 - t * 520;
      const half = 236 - t * 118;
      return `<line x1="${512 - half}" y1="${y}" x2="${512 + half}" y2="${y}"
        stroke="${GREEN}" stroke-width="48" stroke-linecap="round"/>`;
    })
    .join('\n  ');
  candidates['4-ladder'] = wrap(
    INK,
    `<line x1="276" y1="828" x2="394" y2="308" stroke="${GREEN}" stroke-width="48" stroke-linecap="round"/>
  <line x1="748" y1="828" x2="630" y2="308" stroke="${GREEN}" stroke-width="48" stroke-linecap="round"/>
  ${rungs}`
  );
}

// 5. Three cones — a drill is never one cone.
{
  const a = cone(GREEN, INK, { scale: 0.34, dx: -286, dy: 78, stripe: false });
  const b = cone(GREEN, INK, { scale: 0.46, dx: 0, dy: 20, stripe: false });
  const c = cone(GREEN, INK, { scale: 0.34, dx: 286, dy: 78, stripe: false });
  candidates['5-cones-three'] = wrap(INK, `${a.body}\n${b.body}\n${c.body}`);
}

// 6. Chevrons: reps stacking up.
{
  const chev = (y, half, w) =>
    `<path d="M ${512 - half} ${y + half * 0.62} L 512 ${y} L ${512 + half} ${y + half * 0.62}"
      fill="none" stroke="${GREEN}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
  candidates['6-chevrons'] = wrap(INK, `${chev(250, 232, 70)}\n${chev(470, 232, 70)}\n${chev(690, 232, 70)}`);
}

// 7. A D built from the cone's silhouette.
{
  candidates['7-d-mark'] = wrap(
    GREEN,
    `<path d="M 316 232 L 316 792 L 512 792 C 700 792 802 660 802 512 C 802 364 700 232 512 232 Z"
       fill="${INK}"/>
     <rect x="316" y="470" width="486" height="84" fill="${GREEN}"/>
     <path d="M 316 232 L 316 792 L 512 792 C 700 792 802 660 802 512 C 802 364 700 232 512 232 Z"
       fill="none" stroke="${INK}" stroke-width="0"/>
     <path d="M 452 366 L 452 658 L 512 658 C 592 658 636 600 636 512 C 636 424 592 366 512 366 Z"
       fill="${GREEN}"/>`
  );
}

// 8. Cone rendered as a bold single mark with a wide safe margin — the small-size test.
{
  const c = cone(INK, GREEN, { scale: 0.82, stripeY: 470 });
  candidates['8-cone-green-tight'] = wrap(GREEN, c.body, c.defs);
}

for (const [name, svg] of Object.entries(candidates)) {
  fs.writeFileSync(path.join(OUT, `${name}.svg`), svg);
}
console.log(Object.keys(candidates).join('\n'));
