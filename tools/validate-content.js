#!/usr/bin/env node
/**
 * Validates ios/DRILL/Resources/exercises.json.
 *
 * The important check is fidelity: every step's text must match the original
 * web app's ACTIVITIES literal in site/app/index.html character for character. The
 * migration adds timing metadata and nothing else — no rewording, no dropped
 * steps, no reordering.
 *
 * Also checks schema validity and reports where the hand-authored
 * estimatedMinutes disagrees with the time the steps actually account for.
 *
 * Usage: node tools/validate-content.js
 * Exits non-zero if any check fails.
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const JSON_PATH = path.join(ROOT, 'ios/DRILL/Resources/exercises.json');
const HTML_PATH = path.join(ROOT, 'site/app/index.html');

const TAGS = [
  'warmup', 'soccer', 'football', 'basketball', 'baseball', 'cardio', 'plyo', 'strength', 'balance', 'track',
  'stretch',
];
const MODES = ['stepped', 'openBlock'];
const UNITS = ['count', 'seconds', 'inches', 'feet'];
const ROLES = ['setup', 'form', 'cue', 'action'];
const MEDIA_KINDS = ['loop', 'clip'];
const ASSET_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

// index.html defines the drill as `passAndMove` but the schedule references it
// as `wallPassing` via an alias assignment. The JSON canonicalizes to one id.
const ID_ALIASES = { wallPassing: 'passAndMove' };

const errors = [];
const warnings = [];
const notes = [];
const loops = [];
const selfPaced = [];
const roleCounts = {};
const noMedia = [];

const fail = (m) => errors.push(m);
const warn = (m) => warnings.push(m);
const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;

/**
 * media.asset is a logical name the app resolves however it likes — bundled,
 * downloaded, streamed. Filenames, extensions and URLs are rejected so that
 * changing delivery never requires touching content.
 */
function validateMedia(m, where) {
  if (m === null) return;
  if (typeof m !== 'object') { fail(`${where}: media must be an object or null`); return; }
  if (typeof m.asset !== 'string' || !ASSET_RE.test(m.asset)) {
    fail(`${where}: media.asset must be a lowercase slug (got ${JSON.stringify(m.asset)})`);
  }
  if (/\.\w{2,4}$/.test(m.asset || '') || /[/:]/.test(m.asset || '')) {
    fail(`${where}: media.asset looks like a filename or URL — use a logical name so delivery can change`);
  }
  if (!MEDIA_KINDS.includes(m.kind)) {
    fail(`${where}: media.kind must be one of ${MEDIA_KINDS.join(', ')}`);
  }
}

// ── Extract the original ACTIVITIES literal from site/app/index.html ─────────────────

function extractOriginalActivities(html) {
  const marker = 'const ACTIVITIES = ';
  const start = html.indexOf(marker);
  if (start === -1) throw new Error('Could not find `const ACTIVITIES = ` in site/app/index.html');

  // Brace-match from the opening { to its partner, ignoring braces inside
  // string literals (step text contains none, but be safe).
  const open = html.indexOf('{', start);
  let depth = 0, i = open, inStr = null;
  for (; i < html.length; i++) {
    const c = html[i];
    if (inStr) {
      if (c === '\\') { i++; continue; }
      if (c === inStr) inStr = null;
      continue;
    }
    if (c === '"' || c === "'" || c === '`') { inStr = c; continue; }
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) break; }
  }
  if (depth !== 0) throw new Error('Unbalanced braces reading ACTIVITIES');

  const literal = html.slice(open, i + 1);
  return Function('"use strict"; return (' + literal + ');')();
}

// ── Timing validation ───────────────────────────────────────────────────────

function validateTiming(t, where, stepIndex, stepCount) {
  if (t === null) return { timed: 0, kind: 'none' };
  if (typeof t !== 'object') { fail(`${where}: timing must be an object or null`); return { timed: 0 }; }

  const posInt = (v, f) => {
    if (!Number.isInteger(v) || v <= 0) fail(`${where}: ${f} must be a positive integer, got ${JSON.stringify(v)}`);
  };

  switch (t.type) {
    case 'work': {
      posInt(t.seconds, 'seconds');
      return { timed: t.seconds || 0, kind: 'work' };
    }
    case 'reps': {
      posInt(t.count, 'count');
      if (t.each !== null && typeof t.each !== 'string') fail(`${where}: each must be a string or null`);
      // Reps are self-paced; allow ~3s per rep for the duration estimate.
      const sides = t.each ? 2 : 1;
      return { timed: (t.count || 0) * 3 * sides, kind: 'reps' };
    }
    case 'interval': {
      // An interval describes work that happens WITHIN this step. If the work
      // is described in earlier steps and this step only says "rest and
      // repeat", it is a loop, not an interval — see the loop case below.
      if (t.work !== null && t.reps !== null) {
        fail(`${where}: interval cannot set both work and reps — pick time or count`);
      }
      if (t.work !== null) posInt(t.work, 'work');
      if (t.reps !== null) posInt(t.reps, 'reps');
      if (!Number.isInteger(t.rest) || t.rest < 0) fail(`${where}: rest must be a non-negative integer`);
      posInt(t.rounds, 'rounds');
      if (t.each !== null && typeof t.each !== 'string') fail(`${where}: each must be a string or null`);

      // Self-paced work inside the step is legal, but it is the exact shape
      // that hides a mis-modelled loop, so every instance gets surfaced for a
      // human to confirm the work really is described in THIS step.
      const SELF_PACED_ALLOWANCE = 30;
      if (t.work === null && t.reps === null) {
        if (t.rest === 0) {
          fail(`${where}: interval has no work, no reps and no rest — nothing to time`);
        }
        selfPaced.push(where);
      }
      const perRound = t.work !== null ? t.work
        : t.reps !== null ? t.reps * 3
        : SELF_PACED_ALLOWANCE;
      const rounds = t.rounds || 0;
      // Rest falls between rounds, not after the last one — except where the
      // step text explicitly describes a trailing rest (rounds === 1).
      const rests = rounds > 1 ? (rounds - 1) : 1;
      return { timed: perRound * rounds + (t.rest || 0) * rests, kind: 'interval' };
    }
    case 'loop': {
      // This step is the rest phase plus a jump back to an earlier step. The
      // work lives in steps repeatFrom..(this step - 1).
      posInt(t.repeatFrom, 'repeatFrom');
      posInt(t.rounds, 'rounds');
      posInt(t.restEvery, 'restEvery');
      if (!Number.isInteger(t.rest) || t.rest <= 0) {
        fail(`${where}: loop rest must be a positive integer (a loop with no rest is just a repeat count)`);
      }
      const here = stepIndex + 1;
      if (t.repeatFrom >= here) {
        fail(`${where}: repeatFrom (${t.repeatFrom}) must point at an earlier step than this one (${here})`);
      }
      if (t.repeatFrom > stepCount) {
        fail(`${where}: repeatFrom (${t.repeatFrom}) is past the end of the exercise`);
      }
      if (t.rounds % t.restEvery !== 0) {
        warn(`${where}: rounds (${t.rounds}) is not a multiple of restEvery (${t.restEvery}) — the last group is short`);
      }
      const bodySteps = here - t.repeatFrom;
      loops.push(`${where}: repeats steps ${t.repeatFrom}-${here - 1} (${plural(bodySteps, 'step')}) × ${t.rounds}, ${t.rest}s rest every ${t.restEvery}`);
      // The looped body is self-paced by construction; allow a nominal 30s per
      // round plus the actual rest time.
      const restCount = Math.floor(t.rounds / t.restEvery);
      return { timed: 30 * t.rounds + t.rest * Math.max(restCount - 1, 0), kind: 'loop' };
    }
    default:
      fail(`${where}: unknown timing type ${JSON.stringify(t.type)}`);
      return { timed: 0 };
  }
}

// ── Main ────────────────────────────────────────────────────────────────────

let doc, original;
try {
  doc = JSON.parse(fs.readFileSync(JSON_PATH, 'utf8'));
} catch (e) {
  console.error(`FATAL: could not parse ${JSON_PATH}\n  ${e.message}`);
  process.exit(1);
}
try {
  original = extractOriginalActivities(fs.readFileSync(HTML_PATH, 'utf8'));
} catch (e) {
  console.error(`FATAL: could not read original content from site/app/index.html\n  ${e.message}`);
  process.exit(1);
}

const exercises = doc.exercises || [];
const seenIds = new Set();
let steppedCount = 0, openCount = 0, timedSteps = 0, totalSteps = 0;

for (const ex of exercises) {
  const where = `${ex.id || '(no id)'}`;

  if (!ex.id) fail('An exercise is missing an id');
  if (seenIds.has(ex.id)) fail(`${where}: duplicate id`);
  seenIds.add(ex.id);

  if (!ex.name) fail(`${where}: missing name`);
  if (!TAGS.includes(ex.tag)) fail(`${where}: invalid tag ${JSON.stringify(ex.tag)}`);
  if (!MODES.includes(ex.mode)) fail(`${where}: invalid mode ${JSON.stringify(ex.mode)}`);
  if (!Number.isInteger(ex.estimatedMinutes) || ex.estimatedMinutes <= 0) {
    fail(`${where}: estimatedMinutes must be a positive integer`);
  }
  if (!Array.isArray(ex.steps) || ex.steps.length === 0) {
    fail(`${where}: steps must be a non-empty array`);
    continue;
  }

  if (ex.prMetric !== null) {
    const p = ex.prMetric;
    if (!p || !p.label) fail(`${where}: prMetric needs a label`);
    if (!UNITS.includes(p.unit)) fail(`${where}: prMetric.unit must be one of ${UNITS.join(', ')}`);
    if (typeof p.higherIsBetter !== 'boolean') fail(`${where}: prMetric.higherIsBetter must be a boolean`);
  }

  ex.mode === 'stepped' ? steppedCount++ : openCount++;

  // Fidelity: compare against the original step text. Exercises with no
  // counterpart in the retired web app are content that never existed there
  // (new sports added after the migration) — schema-validate them like
  // everything else, but there is nothing to compare verbatim against.
  const originalId = ID_ALIASES[ex.id] || ex.id;
  const orig = original[originalId];
  if (orig) {
    if (orig.name !== ex.name) {
      fail(`${where}: name changed — was ${JSON.stringify(orig.name)}, now ${JSON.stringify(ex.name)}`);
    }
    if (orig.tag !== ex.tag) {
      fail(`${where}: tag changed — was ${JSON.stringify(orig.tag)}, now ${JSON.stringify(ex.tag)}`);
    }
    if (orig.duration !== ex.displayDuration) {
      fail(`${where}: displayDuration changed — was ${JSON.stringify(orig.duration)}, now ${JSON.stringify(ex.displayDuration)}`);
    }
    if (orig.steps.length !== ex.steps.length) {
      fail(`${where}: step count changed — was ${orig.steps.length}, now ${ex.steps.length}`);
    } else {
      orig.steps.forEach((text, i) => {
        if (text !== ex.steps[i].text) {
          fail(
            `${where}: step ${i + 1} text changed\n` +
            `      was: ${JSON.stringify(text)}\n` +
            `      now: ${JSON.stringify(ex.steps[i].text)}`
          );
        }
      });
    }
  }

  // Timing validation + duration estimate.
  let derived = 0;
  ex.steps.forEach((step, i) => {
    totalSteps++;
    if (typeof step.text !== 'string' || !step.text.trim()) {
      fail(`${where} step ${i + 1}: text must be a non-empty string`);
    }
    if (!('timing' in step)) fail(`${where} step ${i + 1}: missing timing key (use null for untimed)`);

    if (!ROLES.includes(step.role)) {
      fail(`${where} step ${i + 1}: role must be one of ${ROLES.join(', ')} (got ${JSON.stringify(step.role)})`);
    }
    // Anything carrying a clock is work by definition; setup/form/cue never gate.
    if (step.timing !== null && step.role !== 'action') {
      fail(`${where} step ${i + 1}: has timing but role is '${step.role}' — timed steps must be action`);
    }
    if (!('media' in step)) fail(`${where} step ${i + 1}: missing media key (use null for none)`);
    validateMedia(step.media, `${where} step ${i + 1}`);
    roleCounts[step.role] = (roleCounts[step.role] || 0) + 1;
    const r = validateTiming(step.timing, `${where} step ${i + 1}`, i, ex.steps.length);
    if (step.timing !== null) timedSteps++;
    derived += r.timed;
  });

  if (ex.mode === 'stepped' && !ex.steps.some((s) => s.timing !== null)) {
    fail(`${where}: mode is 'stepped' but no step has timing — should this be 'openBlock'?`);
  }
  if (!('media' in ex)) fail(`${where}: missing media key (use null for none)`);
  validateMedia(ex.media, where);
  if (ex.media === null) noMedia.push(ex.id);

  // The walkthrough advances through action steps only. An exercise with none
  // would open and immediately finish.
  const actions = ex.steps.filter((s) => s.role === 'action').length;
  if (actions === 0) fail(`${where}: no action steps — the walkthrough would have nothing to do`);
  if (ex.mode === 'openBlock') {
    notes.push(`${where}: openBlock — whole-exercise ${ex.estimatedMinutes} min clock`);
  } else {
    const stated = ex.estimatedMinutes * 60;
    const ratio = derived / stated;
    const mins = (derived / 60).toFixed(1);
    if (derived > stated) {
      warn(`${where}: steps account for ${mins} min but estimatedMinutes is ${ex.estimatedMinutes} — session may run long`);
    } else if (ratio < 0.5) {
      notes.push(`${where}: steps account for ${mins} min of a stated ${ex.estimatedMinutes} min (rest is setup/self-paced work)`);
    }
  }
}

// Every original exercise must be carried over.
const carried = new Set([...seenIds].map((id) => ID_ALIASES[id] || id));
for (const id of Object.keys(original)) {
  if (!carried.has(id)) fail(`Original exercise '${id}' is missing from exercises.json`);
}

// ── Report ──────────────────────────────────────────────────────────────────

console.log('DRILL — content validation\n');
console.log(`  exercises      ${exercises.length}  (${steppedCount} stepped, ${openCount} openBlock)`);
console.log(`  steps          ${totalSteps}  (${timedSteps} timed, ${totalSteps - timedSteps} untimed)`);
console.log(`  roles          ${ROLES.map((r) => `${roleCounts[r] || 0} ${r}`).join(', ')}`);
const gates = exercises
  .filter((e) => e.mode === 'stepped')
  .reduce((n, e) => n + e.steps.filter((s) => s.role === 'action').length, 0);
console.log(`  walkthrough    ${gates} action steps across stepped exercises`);
console.log(`  media          ${exercises.length - noMedia.length}/${exercises.length} exercises have a demo asset`);
console.log(`  original ids   ${Object.keys(original).length} in site/app/index.html\n`);

if (loops.length) {
  console.log('Multi-step loops (work lives in the repeated steps, not the loop step):');
  for (const l of loops) console.log(`  ↻ ${l}`);
  console.log('');
}
if (selfPaced.length) {
  console.log('Self-paced intervals — CONFIRM the work is described in this step,');
  console.log('not an earlier one. If it is earlier, this should be a loop:');
  for (const s of selfPaced) console.log(`  ? ${s}`);
  console.log('');
}
if (notes.length) {
  console.log('Notes:');
  for (const n of notes) console.log(`  · ${n}`);
  console.log('');
}
if (warnings.length) {
  console.log('Warnings:');
  for (const w of warnings) console.log(`  ! ${w}`);
  console.log('');
}
if (errors.length) {
  console.log('Errors:');
  for (const e of errors) console.log(`  ✗ ${e}`);
  console.log(`\nFAILED — ${errors.length} error(s)`);
  process.exit(1);
}

console.log(`PASSED — all step text matches site/app/index.html verbatim${warnings.length ? `, ${warnings.length} warning(s)` : ''}`);
