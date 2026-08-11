#!/usr/bin/env node
/**
 * Validates ios/TrainToday/Resources/exercises.json.
 *
 * The important check is fidelity: every step's text must match the original
 * web app's ACTIVITIES literal in index.html character for character. The
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
const JSON_PATH = path.join(ROOT, 'ios/TrainToday/Resources/exercises.json');
const HTML_PATH = path.join(ROOT, 'index.html');

const TAGS = ['warmup', 'soccer', 'football', 'cardio', 'plyo', 'strength', 'balance', 'track', 'stretch'];
const MODES = ['stepped', 'openBlock'];
const UNITS = ['count', 'seconds', 'inches', 'feet'];

// index.html defines the drill as `passAndMove` but the schedule references it
// as `wallPassing` via an alias assignment. The JSON canonicalizes to one id.
const ID_ALIASES = { wallPassing: 'passAndMove' };

const errors = [];
const warnings = [];
const notes = [];

const fail = (m) => errors.push(m);
const warn = (m) => warnings.push(m);

// ── Extract the original ACTIVITIES literal from index.html ─────────────────

function extractOriginalActivities(html) {
  const marker = 'const ACTIVITIES = ';
  const start = html.indexOf(marker);
  if (start === -1) throw new Error('Could not find `const ACTIVITIES = ` in index.html');

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

function validateTiming(t, where) {
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
      // work and reps may BOTH be null: a self-paced work phase (sprint a
      // distance, run one ladder pass) that the athlete taps to end, followed
      // by a rest countdown. Common here — many drills are distance-based.
      if (t.work !== null && t.reps !== null) {
        fail(`${where}: interval cannot set both work and reps — pick time or count`);
      }
      if (t.work !== null) posInt(t.work, 'work');
      if (t.reps !== null) posInt(t.reps, 'reps');
      if (t.work === null && t.reps === null && t.rest === 0) {
        fail(`${where}: interval is entirely untimed (self-paced work, no rest) — use null timing instead`);
      }
      if (!Number.isInteger(t.rest) || t.rest < 0) fail(`${where}: rest must be a non-negative integer`);
      posInt(t.rounds, 'rounds');
      if (t.each !== null && typeof t.each !== 'string') fail(`${where}: each must be a string or null`);
      // Self-paced rounds get a nominal 30s allowance so the duration estimate
      // isn't wildly low; it's a sanity check, not a scheduling input.
      const SELF_PACED_ALLOWANCE = 30;
      const perRound = t.work !== null ? t.work
        : t.reps !== null ? t.reps * 3
        : SELF_PACED_ALLOWANCE;
      const rounds = t.rounds || 0;
      // Rest falls between rounds, not after the last one — except where the
      // step text explicitly describes a trailing rest (rounds === 1).
      const rests = rounds > 1 ? (rounds - 1) : 1;
      return { timed: perRound * rounds + (t.rest || 0) * rests, kind: 'interval' };
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
  console.error(`FATAL: could not read original content from index.html\n  ${e.message}`);
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

  // Fidelity: compare against the original step text.
  const originalId = ID_ALIASES[ex.id] || ex.id;
  const orig = original[originalId];
  if (!orig) {
    fail(`${where}: no matching exercise in index.html (looked for '${originalId}')`);
  } else {
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
    const r = validateTiming(step.timing, `${where} step ${i + 1}`);
    if (step.timing !== null) timedSteps++;
    derived += r.timed;
  });

  if (ex.mode === 'stepped' && !ex.steps.some((s) => s.timing !== null)) {
    fail(`${where}: mode is 'stepped' but no step has timing — should this be 'openBlock'?`);
  }
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

console.log('Train Today — content validation\n');
console.log(`  exercises      ${exercises.length}  (${steppedCount} stepped, ${openCount} openBlock)`);
console.log(`  steps          ${totalSteps}  (${timedSteps} timed, ${totalSteps - timedSteps} tap-to-advance)`);
console.log(`  original ids   ${Object.keys(original).length} in index.html\n`);

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

console.log(`PASSED — all step text matches index.html verbatim${warnings.length ? `, ${warnings.length} warning(s)` : ''}`);
