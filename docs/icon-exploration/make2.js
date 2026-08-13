#!/usr/bin/env node
// Round two: the cone concept, refined. Squatter body (an agility cone, not a
// traffic cone), and variations on stripe, ground and colour direction.

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const INK = '#0D0D0D';
const GREEN = '#22D68A';
const GREEN_DEEP = '#0FA968';

const wrap = (bg, body, defs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>${defs}</defs>
<rect width="1024" height="1024" fill="${bg}"/>
${body}
</svg>`;

let uid = 0;

/**
 * A squat agility cone. `stripes` are y-centres in user space; each is cut out
 * of the cone in the background colour, so it reads as reflective tape rather
 * than as a separate shape.
 */
function cone(fg, bg, { stripes = [], scale = 1, dy = 0, slab = true } = {}) {
  const id = `m${uid++}`;
  const body = 'M 512 264 L 706 712 L 318 712 Z';
  const t = `translate(0 ${dy}) translate(512 540) scale(${scale}) translate(-512 -540)`;
  const cuts = stripes
    .map((y) => `<rect x="150" y="${y}" width="724" height="74" fill="${bg}"/>`)
    .join('\n    ');
  return {
    defs: stripes.length
      ? `<mask id="${id}"><rect width="1024" height="1024" fill="black"/>
      <g transform="${t}"><path d="${body}" fill="white" stroke="white" stroke-width="64" stroke-linejoin="round"/></g></mask>`
      : '',
    body: `<g transform="${t}">
    <path d="${body}" fill="${fg}" stroke="${fg}" stroke-width="64" stroke-linejoin="round"/>
    ${slab ? `<rect x="186" y="738" width="652" height="98" rx="49" fill="${fg}"/>` : ''}
  </g>
  ${stripes.length ? `<g mask="url(#${id})">${cuts}</g>` : ''}`,
  };
}

const c = {};

// A — one stripe, mid body, green on ink.
{
  const k = cone(GREEN, INK, { stripes: [500] });
  c['A-mid-stripe-dark'] = wrap(INK, k.body, k.defs);
}
// B — the same, inverted to a green tile.
{
  const k = cone(INK, GREEN, { stripes: [500] });
  c['B-mid-stripe-green'] = wrap(GREEN, k.body, k.defs);
}
// C — no stripe at all. The purest silhouette.
{
  const k = cone(GREEN, INK, {});
  c['C-plain-dark'] = wrap(INK, k.body, k.defs);
}
// D — no stripe, green tile.
{
  const k = cone(INK, GREEN, {});
  c['D-plain-green'] = wrap(GREEN, k.body, k.defs);
}
// E — stripe low, where a real cone's tape sits.
{
  const k = cone(GREEN, INK, { stripes: [578] });
  c['E-low-stripe-dark'] = wrap(INK, k.body, k.defs);
}
// F — cone over a motion sweep: the turn a shuttle run makes around it.
{
  const k = cone(GREEN, INK, { stripes: [500], scale: 0.86, dy: -26 });
  c['F-cone-sweep'] = wrap(
    INK,
    `<path d="M 150 760 C 150 560 330 470 512 470 C 694 470 874 560 874 760"
     fill="none" stroke="${GREEN_DEEP}" stroke-width="56" stroke-linecap="round"/>
  ${k.body}`,
    k.defs
  );
}
// G — the agility ladder, bolder and less perspectival.
{
  const rungs = [0, 1, 2, 3]
    .map((i) => {
      const t = i / 3;
      const y = 800 - t * 520;
      const half = 250 - t * 96;
      return `<line x1="${512 - half}" y1="${y}" x2="${512 + half}" y2="${y}"
      stroke="${GREEN}" stroke-width="58" stroke-linecap="round"/>`;
    })
    .join('\n  ');
  c['G-ladder'] = wrap(
    INK,
    `<line x1="262" y1="800" x2="416" y2="280" stroke="${GREEN}" stroke-width="58" stroke-linecap="round"/>
  <line x1="762" y1="800" x2="608" y2="280" stroke="${GREEN}" stroke-width="58" stroke-linecap="round"/>
  ${rungs}`
  );
}
// H — a D whose counter is the cone.
{
  c['H-d-cone'] = wrap(
    GREEN,
    `<path d="M 286 226 L 286 798 L 500 798 C 706 798 812 668 812 512 C 812 356 706 226 500 226 Z" fill="${INK}"/>
  <path d="M 520 372 L 646 654 L 394 654 Z" fill="${GREEN}" stroke="${GREEN}" stroke-width="44" stroke-linejoin="round"/>`
  );
}

for (const [name, svg] of Object.entries(c)) {
  fs.writeFileSync(path.join(OUT, `r2-${name}.svg`), svg);
}
console.log(Object.keys(c).join('\n'));
