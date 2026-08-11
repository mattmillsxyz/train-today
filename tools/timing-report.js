#!/usr/bin/env node
/**
 * Renders a review page from exercises.json: every timing decision paired with
 * the original step prose it came from, so the timings can be checked without
 * reading JSON.
 *
 * Usage: node tools/timing-report.js > /path/to/report.html
 */

const fs = require('fs');
const path = require('path');

const doc = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../ios/TrainToday/Resources/exercises.json'), 'utf8')
);

// Places where the prose was ambiguous and a call had to be made. Keyed by
// `${exerciseId}:${stepNumber}`, or `${exerciseId}` for whole-exercise calls.
const JUDGEMENT_CALLS = {
  'sprintIntervals:5': 'Prose says "8 sprints, rest 45s after every 2". Loops the sprint-and-walk-back pair 8 times, resting after every second one.',
  'trackSprints:5': 'Same shape as Sprint Intervals: the sprint-and-walk-back pair 6 times, 60s rest after every second one.',
  'calfRaises:2': 'The "rest 30 seconds between each set" instruction lives in step 5 but applies to steps 2-4. Attached a trailing 30s rest to each variation.',
  'coneDribbling:4': 'The 3 sets come from the "12 min · 3 sets" duration label — the step text alone only says "repeat".',
  'footballAgility:4': 'The loop spans steps 2-3, but step 3 is a cue rather than an action, so it never gates a round — it shows during the work instead. No reorder needed after all.',
  'singleLegBalance:4': '"10 seconds on each foot" — 2 rounds with no rest between, so it flows straight from one foot to the other.',
  'strideDrills:5': 'The only self-paced interval left: the bounds are described in this same step, so it stays an interval rather than a loop.',
  'cariocaSteps': 'Left as an open block despite the "4 passes" count — it is travel-based technique practice, not a timed set.',
};

const TAG_ORDER = ['warmup', 'soccer', 'football', 'cardio', 'plyo', 'strength', 'balance', 'track', 'stretch'];
const TAG_LABEL = {
  warmup: 'Warmup', soccer: 'Soccer', football: 'Football', cardio: 'Cardio',
  plyo: 'Plyometrics', strength: 'Strength', balance: 'Balance & Agility',
  track: 'Track', stretch: 'Stretching',
};

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;

/** Human-readable rendering of a timing object. */
function describe(t) {
  if (t === null) return null;
  switch (t.type) {
    case 'work':
      return { kind: 'countdown', label: fmtSecs(t.seconds) };
    case 'reps':
      return { kind: 'count', label: `${t.count} reps${t.each ? ` each ${t.each}` : ''}` };
    case 'interval': {
      const work = t.work !== null ? fmtSecs(t.work)
        : t.reps !== null ? `${t.reps} reps${t.each ? ` each ${t.each}` : ''}`
        : 'self-paced';
      const rest = t.rest > 0 ? `${fmtSecs(t.rest)} rest` : 'no rest';
      // A single round is just "work then rest" — the "1×" adds nothing.
      const rounds = t.rounds > 1 ? `${t.rounds}× · ` : '';
      return { kind: 'interval', label: `${rounds}${work} · ${rest}` };
    }
    case 'loop': {
      const every = t.restEvery > 1 ? ` every ${t.restEvery}` : '';
      return {
        kind: 'loop',
        label: `${fmtSecs(t.rest)} rest${every} → back to step ${t.repeatFrom} · ${t.rounds} rounds`,
      };
    }
  }
}

function fmtSecs(s) {
  if (s % 60 === 0 && s >= 60) return `${s / 60} min`;
  return `${s}s`;
}

// ── Tally ───────────────────────────────────────────────────────────────────

const exercises = doc.exercises;
const totalSteps = exercises.reduce((n, e) => n + e.steps.length, 0);
const timedSteps = exercises.reduce((n, e) => n + e.steps.filter((s) => s.timing !== null).length, 0);
const openBlocks = exercises.filter((e) => e.mode === 'openBlock');
const flagged = [];

for (const ex of exercises) {
  if (JUDGEMENT_CALLS[ex.id]) flagged.push({ ex, step: null, note: JUDGEMENT_CALLS[ex.id] });
  ex.steps.forEach((s, i) => {
    const key = `${ex.id}:${i + 1}`;
    if (JUDGEMENT_CALLS[key]) flagged.push({ ex, step: i + 1, stepObj: s, note: JUDGEMENT_CALLS[key] });
  });
}

// ── Render ──────────────────────────────────────────────────────────────────

/** Step numbers (1-based) that sit inside a loop body, mapped to their loop. */
function loopBodies(ex) {
  const inBody = new Map();
  ex.steps.forEach((s, i) => {
    if (s.timing && s.timing.type === 'loop') {
      for (let n = s.timing.repeatFrom; n <= i; n++) inBody.set(n, s.timing);
    }
  });
  return inBody;
}

function renderStep(ex, step, i, inBody) {
  const n = i + 1;
  const d = describe(step.timing);
  const note = JUDGEMENT_CALLS[`${ex.id}:${n}`];
  const loop = inBody.get(n);
  const cls = ['step', `step--${step.role}`];
  if (loop) cls.push('step--looped');
  const isAction = step.role === 'action';
  return `
        <li class="${cls.join(' ')}">
          <span class="step__n">${n}</span>
          <div class="step__body">
            <p class="step__text">${esc(step.text)}</p>
            <span class="roles">
              <span class="role role--${step.role}">${step.role}</span>
              ${loop ? `<span class="looped">↻ repeats ${loop.rounds}×</span>` : ''}
            </span>
            ${note ? `<p class="step__note">${esc(note)}</p>` : ''}
          </div>
          ${d
            ? `<span class="timing timing--${d.kind}">${esc(d.label)}</span>`
            : isAction
              ? `<span class="timing timing--none">tap to advance</span>`
              : `<span class="timing timing--off">not a gate</span>`}
        </li>`;
}

function renderExercise(ex) {
  const inBody = loopBodies(ex);
  const actions = ex.steps.filter((s) => s.role === 'action').length;
  return `
      <article class="ex" id="${esc(ex.id)}">
        <header class="ex__head">
          <h3 class="ex__name">${esc(ex.name)}</h3>
          <div class="ex__meta">
            <span class="chip chip--${esc(ex.mode)}">${ex.mode === 'stepped' ? 'Stepped' : 'Open block'}</span>
            <span class="ex__dur">${esc(ex.displayDuration)}</span>
            <span class="ex__count">${ex.mode === 'stepped'
              ? `${actions} of ${ex.steps.length} steps in the walkthrough`
              : `${ex.steps.length} steps shown alongside`}</span>
          </div>
          ${ex.prMetric ? `<p class="ex__pr">Tracks a record — ${esc(ex.prMetric.label)} <span>(${esc(ex.prMetric.unit)}, ${ex.prMetric.higherIsBetter ? 'higher' : 'lower'} is better)</span></p>` : ''}
          ${JUDGEMENT_CALLS[ex.id] ? `<p class="step__note">${esc(JUDGEMENT_CALLS[ex.id])}</p>` : ''}
        </header>
        <ol class="steps">${ex.steps.map((s, i) => renderStep(ex, s, i, inBody)).join('')}
        </ol>
      </article>`;
}

const stepped = exercises.filter((e) => e.mode === 'stepped');
const steppedCount = stepped.length;
const steppedStepCount = stepped.reduce((n, e) => n + e.steps.length, 0);
const gateCount = stepped.reduce((n, e) => n + e.steps.filter((s) => s.role === 'action').length, 0);
const withMedia = exercises.filter((e) => e.media !== null).length;

const ROLE_BLURB = [
  ['setup', 'gather equipment and mark out space — shown before the timer starts'],
  ['form', 'how the movement works — reference on the get-ready screen, reachable mid-set'],
  ['cue', 'coaching reminder — shown and spoken during the work, never a gate'],
  ['action', 'the real work — the only role that advances the walkthrough'],
];

const byTag = TAG_ORDER.map((tag) => ({
  tag,
  items: exercises.filter((e) => e.tag === tag),
})).filter((g) => g.items.length);

const html = `<title>Train Today — Timing Review</title>
<style>
  :root {
    --green: #16a869;
    --green-bright: #22D68A;
    --amber: #B87A00;
    --ink: #12211b;
    --ink-soft: #5a6b64;
    --ink-faint: #8a9994;
    --ground: #f2f5f3;
    --card: #ffffff;
    --rule: #dfe6e2;
    --rule-soft: #eaf0ed;
    --chip-bg: #e6f4ed;
    --note-bg: #fdf6e6;
    --loop-bg: #e2edf8;
    --loop-ink: #1f5c96;
    --loop-tint: #f6fafd;
    --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --green: #22D68A;
      --green-bright: #22D68A;
      --amber: #F0A500;
      --ink: #eef2f0;
      --ink-soft: #97a5a0;
      --ink-faint: #6d7a75;
      --ground: #0d0d0d;
      --card: #161616;
      --rule: #262b29;
      --rule-soft: #1e2321;
      --chip-bg: #0d2e1f;
      --note-bg: #241d0c;
      --loop-bg: #10273a;
      --loop-ink: #6fb4f0;
      --loop-tint: #111820;
    }
  }
  :root[data-theme="dark"] {
    --green: #22D68A;
    --green-bright: #22D68A;
    --amber: #F0A500;
    --ink: #eef2f0;
    --ink-soft: #97a5a0;
    --ink-faint: #6d7a75;
    --ground: #0d0d0d;
    --card: #161616;
    --rule: #262b29;
    --rule-soft: #1e2321;
    --chip-bg: #0d2e1f;
    --note-bg: #241d0c;
    --loop-bg: #10273a;
    --loop-ink: #6fb4f0;
    --loop-tint: #111820;
  }

  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--ground);
    color: var(--ink);
    font-family: var(--sans);
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
  }
  .wrap {
    max-width: 780px;
    margin: 0 auto;
    padding: 0 16px 72px;
    display: flex;
    flex-direction: column;
    gap: 40px;
  }

  /* Masthead */
  .mast {
    background: var(--green-bright);
    color: #0d2e1f;
    border-radius: 0 0 20px 20px;
    padding: 32px 24px 26px;
    margin: 0 -16px;
  }
  .mast h1 {
    margin: 0;
    font-size: clamp(26px, 6vw, 34px);
    font-weight: 700;
    letter-spacing: -0.5px;
    text-wrap: balance;
  }
  .mast p { margin: 6px 0 0; font-size: 16px; opacity: 0.75; max-width: 54ch; }
  .tally {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 28px;
    margin-top: 20px;
    padding-top: 18px;
    border-top: 1px solid rgba(0,0,0,0.14);
  }
  .tally div { display: flex; flex-direction: column; }
  .tally dt { font-size: 12px; text-transform: uppercase; letter-spacing: 0.6px; opacity: 0.7; }
  .tally dd {
    margin: 0;
    font-family: var(--mono);
    font-size: 21px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }

  section { display: flex; flex-direction: column; gap: 16px; }
  h2 {
    margin: 0;
    font-size: 13px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: var(--green);
  }
  .lede { margin: -6px 0 0; color: var(--ink-soft); font-size: 15px; max-width: 62ch; }

  /* Flagged calls */
  .calls { display: flex; flex-direction: column; gap: 10px; }
  .call {
    background: var(--note-bg);
    border: 1px solid color-mix(in srgb, var(--amber) 28%, transparent);
    border-radius: 12px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  .call__where {
    font-size: 12px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.6px;
    color: var(--amber);
  }
  .call__quote { margin: 0; font-size: 15px; color: var(--ink); }
  .call__note { margin: 0; font-size: 14px; color: var(--ink-soft); }
  .call__timing {
    align-self: flex-start;
    font-family: var(--mono);
    font-size: 13px;
    font-variant-numeric: tabular-nums;
    background: var(--card);
    border: 1px solid var(--rule);
    border-radius: 999px;
    padding: 3px 10px;
  }

  /* Exercise cards */
  .group { display: flex; flex-direction: column; gap: 12px; }
  .ex {
    background: var(--card);
    border: 1px solid var(--rule);
    border-radius: 14px;
    overflow: hidden;
  }
  .ex__head {
    padding: 14px 16px 12px;
    border-bottom: 1px solid var(--rule-soft);
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .ex__name { margin: 0; font-size: 18px; font-weight: 600; letter-spacing: -0.2px; }
  .ex__meta { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; font-size: 13px; color: var(--ink-soft); }
  .chip {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 2px 8px;
    border-radius: 999px;
    background: var(--chip-bg);
    color: var(--green);
  }
  .chip--openBlock { background: transparent; border: 1px solid var(--rule); color: var(--ink-faint); }
  .ex__dur, .ex__count { font-family: var(--mono); font-variant-numeric: tabular-nums; font-size: 12px; }
  .ex__count { color: var(--ink-faint); }
  .ex__pr { margin: 2px 0 0; font-size: 13px; color: var(--ink-soft); }
  .ex__pr span { color: var(--ink-faint); }

  .steps { list-style: none; margin: 0; padding: 0; counter-reset: none; }
  .step {
    display: grid;
    grid-template-columns: 22px 1fr auto;
    gap: 4px 10px;
    align-items: start;
    padding: 11px 16px;
    border-bottom: 1px solid var(--rule-soft);
  }
  .step:last-child { border-bottom: none; }
  .step__n {
    font-family: var(--mono);
    font-size: 12px;
    font-variant-numeric: tabular-nums;
    color: var(--ink-faint);
    padding-top: 2px;
  }
  .step__body { min-width: 0; display: flex; flex-direction: column; gap: 5px; }
  .step__text { margin: 0; font-size: 15px; }
  .step--untimed .step__text { color: var(--ink-soft); }
  .step__note {
    margin: 0;
    font-size: 13px;
    line-height: 1.45;
    color: var(--ink-soft);
    background: var(--note-bg);
    border-radius: 8px;
    padding: 7px 10px;
  }
  .timing {
    font-family: var(--mono);
    font-size: 12px;
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    padding: 3px 9px;
    border-radius: 999px;
    background: var(--chip-bg);
    color: var(--green);
    font-weight: 600;
  }
  .timing--none {
    background: transparent;
    border: 1px solid var(--rule);
    color: var(--ink-faint);
    font-weight: 400;
  }
  .timing--loop { background: var(--loop-bg); color: var(--loop-ink); }
  .timing--off {
    background: transparent;
    color: var(--ink-faint);
    border: 1px dashed var(--rule);
    font-weight: 400;
  }
  .roles { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .role {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: 0.7px;
    text-transform: uppercase;
    padding: 1px 6px;
    border-radius: 4px;
    border: 1px solid transparent;
  }
  .role--action { background: var(--chip-bg); color: var(--green); font-weight: 600; }
  .role--setup  { border-color: var(--rule); color: var(--ink-faint); }
  .role--form   { border-color: var(--rule); color: var(--ink-faint); }
  .role--cue    { background: var(--note-bg); color: var(--amber); }
  /* Non-action steps never gate the walkthrough — recede them. */
  .step--setup .step__text,
  .step--form .step__text,
  .step--cue .step__text { color: var(--ink-soft); }
  .step--looped { background: var(--loop-tint); }
  .looped {
    align-self: flex-start;
    font-family: var(--mono);
    font-size: 11px;
    letter-spacing: 0.3px;
    color: var(--loop-ink);
  }
  @media (max-width: 560px) {
    .step { grid-template-columns: 22px 1fr; }
    .timing { grid-column: 2; justify-self: start; }
  }
</style>

<div class="wrap">
  <header class="mast">
    <h1>Timing review</h1>
    <p>Every step of the exercise library, paired with the role and countdown behaviour assigned to it. Step text is unchanged from the web app — only metadata was added.</p>
    <dl class="tally">
      <div><dt>Exercises</dt><dd>${exercises.length}</dd></div>
      <div><dt>Steps</dt><dd>${totalSteps}</dd></div>
      <div><dt>Timed</dt><dd>${timedSteps}</dd></div>
      <div><dt>Walkthrough</dt><dd>${gateCount}</dd></div>
      <div><dt>Demo clips</dt><dd>${withMedia}/${exercises.length}</dd></div>
      <div><dt>Need a call</dt><dd>${flagged.length}</dd></div>
    </dl>
  </header>

  <section>
    <h2>What the walkthrough actually shows</h2>
    <p class="lede">Only <strong>action</strong> steps advance the walkthrough. Setup is gathered on the get-ready screen, form is reference he reads before starting, and cues appear during the work rather than blocking it. Across the ${steppedCount} stepped exercises that is <strong>${gateCount} screens instead of ${steppedStepCount}</strong>.</p>
    <div class="calls">
      <div class="call" style="background:transparent;border-color:var(--rule)">
        <p class="call__note">${ROLE_BLURB.map(([r, t]) => `<span class="role role--${r}">${r}</span> ${esc(t)}`).join('<br>')}</p>
      </div>
    </div>
  </section>

  <section>
    <h2>Worth your eyes first</h2>
    <p class="lede">${flagged.length} places where the original wording was ambiguous and I had to pick a reading. Everything else followed directly from the text.</p>
    <div class="calls">
      ${flagged.map((f) => {
        const d = f.stepObj ? describe(f.stepObj.timing) : null;
        return `<div class="call">
        <span class="call__where">${esc(f.ex.name)}${f.step ? ` · step ${f.step}` : ''}</span>
        ${f.stepObj ? `<p class="call__quote">“${esc(f.stepObj.text)}”</p>` : ''}
        ${d ? `<span class="call__timing">${esc(d.label)}</span>` : ''}
        <p class="call__note">${esc(f.note)}</p>
      </div>`;
      }).join('\n      ')}
    </div>
  </section>

  <section>
    <h2>Open blocks</h2>
    <p class="lede">${openBlocks.length} drills are open practice rather than structured sets — stepping a timer through them would burn the whole drill in seconds. These keep the single whole-exercise clock the web app uses today, with the steps listed alongside.</p>
    <div class="calls">
      <div class="call" style="background:transparent;border-color:var(--rule)">
        <p class="call__note">${openBlocks.map((e) => `${esc(e.name)} <span style="opacity:.6">${esc(e.displayDuration)}</span>`).join(' · ')}</p>
      </div>
    </div>
  </section>

  ${byTag.map((g) => `<section class="group">
    <h2>${esc(TAG_LABEL[g.tag])}</h2>
    ${g.items.map(renderExercise).join('')}
  </section>`).join('\n  ')}
</div>
`;

process.stdout.write(html);
