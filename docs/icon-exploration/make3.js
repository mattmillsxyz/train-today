#!/usr/bin/env node
// Round three: only the two directions that survived — the striped cone, and a
// D whose counter is the cone. Both colour directions, one and two stripes.

const fs = require('fs');
const path = require('path');

const OUT = __dirname;
const INK = '#0D0D0D';
const GREEN = '#22D68A';

const wrap = (bg, body, defs = '') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>${defs}</defs>
<rect width="1024" height="1024" fill="${bg}"/>
${body}
</svg>`;

let uid = 0;

function cone(fg, bg, { stripes = [], scale = 1, dy = 0 } = {}) {
  const id = `k${uid++}`;
  const body = 'M 512 258 L 712 706 L 312 706 Z';
  const t = `translate(0 ${dy}) translate(512 540) scale(${scale}) translate(-512 -540)`;
  const cuts = stripes.map(([y, h]) => `<rect x="140" y="${y}" width="744" height="${h}" fill="${bg}"/>`).join('');
  return {
    defs: stripes.length
      ? `<mask id="${id}"><rect width="1024" height="1024" fill="black"/>
      <g transform="${t}"><path d="${body}" fill="white" stroke="white" stroke-width="66" stroke-linejoin="round"/></g></mask>`
      : '',
    body: `<g transform="${t}">
    <path d="${body}" fill="${fg}" stroke="${fg}" stroke-width="66" stroke-linejoin="round"/>
    <rect x="180" y="734" width="664" height="100" rx="50" fill="${fg}"/>
  </g>
  ${stripes.length ? `<g mask="url(#${id})">${cuts}</g>` : ''}`,
  };
}

/** A bold D with a cone punched out as its counter. */
function dCone(fg, bg, { stripe = false } = {}) {
  const id = `d${uid++}`;
  const outer =
    'M 292 226 L 292 798 L 512 798 C 706 798 812 670 812 512 C 812 354 706 226 512 226 Z';
  const counter = 'M 556 392 L 664 636 L 448 636 Z';
  return {
    defs: stripe
      ? `<mask id="${id}"><rect width="1024" height="1024" fill="black"/>
      <path d="${counter}" fill="white" stroke="white" stroke-width="42" stroke-linejoin="round"/></mask>`
      : '',
    body: `<path d="${outer}" fill="${fg}"/>
  <path d="${counter}" fill="${bg}" stroke="${bg}" stroke-width="42" stroke-linejoin="round"/>
  ${stripe ? `<g mask="url(#${id})"><rect x="400" y="524" width="320" height="46" fill="${fg}"/></g>` : ''}`,
  };
}

const c = {};

{ const k = cone(GREEN, INK, { stripes: [[492, 76]] });       c['1-cone-dark-1s'] = wrap(INK, k.body, k.defs); }
{ const k = cone(GREEN, INK, { stripes: [[444, 60], [566, 60]] }); c['2-cone-dark-2s'] = wrap(INK, k.body, k.defs); }
{ const k = cone(INK, GREEN, { stripes: [[492, 76]] });       c['3-cone-green-1s'] = wrap(GREEN, k.body, k.defs); }
{ const k = cone(INK, GREEN, { stripes: [[444, 60], [566, 60]] }); c['4-cone-green-2s'] = wrap(GREEN, k.body, k.defs); }
{ const k = dCone(INK, GREEN);                 c['5-d-green'] = wrap(GREEN, k.body, k.defs); }
{ const k = dCone(GREEN, INK);                 c['6-d-dark'] = wrap(INK, k.body, k.defs); }
{ const k = dCone(INK, GREEN, { stripe: true }); c['7-d-green-striped'] = wrap(GREEN, k.body, k.defs); }
{ const k = dCone(GREEN, INK, { stripe: true }); c['8-d-dark-striped'] = wrap(INK, k.body, k.defs); }

for (const [name, svg] of Object.entries(c)) {
  fs.writeFileSync(path.join(OUT, `r3-${name}.svg`), svg);
}
console.log(Object.keys(c).join('\n'));
