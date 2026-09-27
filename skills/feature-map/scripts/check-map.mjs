#!/usr/bin/env node
// Mechanical checks for a feature map. Usage: check-map.mjs <features-dir>
// Parses YAML via `npx yaml` so the target repo needs no new dependency.
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const dir = process.argv[2];
if (!dir) {
  console.error("usage: check-map.mjs <features-dir>");
  process.exit(2);
}

const parseYaml = (text, label) => {
  const r = spawnSync("npx", ["-y", "yaml@2", "--json", "--single", "--strict"], { input: text, encoding: "utf8" });
  if (r.status !== 0) {
    console.error(`${label} does not parse:\n${r.stderr.trim()}`);
    process.exit(1);
  }
  return JSON.parse(r.stdout);
};

const mapText = readFileSync(join(dir, "map.yaml"), "utf8");
const m = parseYaml(mapText, "map.yaml");
const errs = [];
const L = m.locations ?? {};
const F = m.fixtures ?? {};
const T = m.transitions ?? [];
const surfaceOf = (id) => id.split(":")[0];
const edge = (t) => `${t.from} -> ${t.to}`;

if (!m.harness) errs.push("harness is missing");

for (const t of T) for (const k of ["from", "to"]) if (!L[t[k]]) errs.push(`${edge(t)}: ${k} is not a location`);

for (const [name, x] of [...Object.entries(L), ...T.map((t) => [edge(t), t]), ...Object.entries(F)])
  for (const r of x.requires ?? []) if (!F[r]) errs.push(`${name}: requires unknown fixture ${r}`);

const visiting = new Set(), done = new Set();
const visit = (f) => {
  if (done.has(f) || !F[f]) return;
  if (visiting.has(f)) return errs.push(`fixture cycle through ${f}`);
  visiting.add(f);
  (F[f].requires ?? []).forEach(visit);
  visiting.delete(f);
  done.add(f);
};
Object.keys(F).forEach(visit);

const reach = (start, forward) => {
  const seen = new Set([start]);
  const queue = [start];
  while (queue.length) {
    const cur = queue.shift();
    for (const t of T) {
      const [a, b] = forward ? [t.from, t.to] : [t.to, t.from];
      if (a === cur && !seen.has(b)) seen.add(b), queue.push(b);
    }
  }
  return seen;
};
for (const s of new Set(Object.keys(L).map(surfaceOf))) {
  const ids = Object.keys(L).filter((id) => surfaceOf(id) === s);
  const entries = ids.filter((id) => L[id].entry);
  if (entries.length !== 1) {
    errs.push(`surface ${s} has ${entries.length} entry locations`);
    continue;
  }
  const fwd = reach(entries[0], true), back = reach(entries[0], false);
  for (const id of ids) {
    if (!fwd.has(id)) errs.push(`${id}: unreachable from ${entries[0]}`);
    if (!back.has(id)) errs.push(`${id}: no way back to ${entries[0]}`);
  }
}

const harnessRun = (cmd) => cmd === m.harness || String(cmd).startsWith(`${m.harness} `);
for (const [id, l] of Object.entries(L)) {
  if (!l.arrive?.run || !l.arrive?.expect) errs.push(`${id}: arrive needs run and expect`);
  else if (!harnessRun(l.arrive.run)) errs.push(`${id}: arrive.run does not use harness ${m.harness}`);
}
for (const t of T) {
  if (!["none", "local", "external"].includes(t.effect)) errs.push(`${edge(t)}: effect must be none, local, or external`);
  if (t.effect === "external" && !t.unverified) errs.push(`${edge(t)}: external effect must be unverified`);
  if (t.actor === "human") {
    if (!t.instruction) errs.push(`${edge(t)}: human step needs instruction`);
  } else if (!t.run) errs.push(`${edge(t)}: run is missing`);
  else for (const r of [t.run].flat()) if (!harnessRun(r)) errs.push(`${edge(t)}: run does not use harness ${m.harness}: ${r}`);
}
for (const [name, x] of [...Object.entries(L), ...T.map((t) => [edge(t), t])]) {
  if (x.unverified !== undefined && !String(x.unverified).trim()) errs.push(`${name}: unverified needs a reason`);
  if (/not yet walked/.test(x.unverified ?? "")) errs.push(`${name}: still not yet walked`);
}

const catDir = join(dir, "catalog");
const cats = existsSync(catDir) ? readdirSync(catDir).filter((f) => f.endsWith(".md")).map((f) => f.slice(0, -3)) : [];
const readme = existsSync(join(dir, "README.md")) ? readFileSync(join(dir, "README.md"), "utf8") : "";
if (!readme) errs.push("README.md is missing");
if (readme && !/^## Mapped without scenarios/m.test(readme)) errs.push('README has no "Mapped without scenarios" section');
for (const c of cats) {
  if (!readme.includes(`catalog/${c}.md`)) errs.push(`README feature index is missing catalog/${c}.md`);
  const md = readFileSync(join(catDir, `${c}.md`), "utf8");
  const fm = parseYaml(md.split(/^---$/m)[1] ?? "", `catalog/${c}.md frontmatter`);
  if (fm.feature !== c) errs.push(`catalog/${c}.md: feature id does not match filename`);
  for (const s of fm.starts_at ?? []) if (!L[s]) errs.push(`catalog/${c}.md: starts_at ${s} is not a location`);
  for (const r of fm.requires ?? []) if (!F[r]) errs.push(`catalog/${c}.md: requires unknown fixture ${r}`);
  for (const g of md.matchAll(/\*\*Given\*\* at `([^`]+)`/g)) if (!L[g[1]]) errs.push(`catalog/${c}.md: Given ${g[1]} is not a location`);
}
for (const link of readme.matchAll(/\(catalog\/([^)]+)\.md\)/g)) if (!cats.includes(link[1])) errs.push(`README links missing catalog/${link[1]}.md`);

const srcHits = mapText.match(/\b(src|lib|app|packages)\/\S+|\S+\.(tsx?|jsx?|py|rb|go|rs|java|kt|swift)\b/g);
if (srcHits) errs.push(`map.yaml looks like it names source files: ${[...new Set(srcHits)].join(", ")}`);

const all = [...Object.values(L), ...T];
console.log(`locations ${Object.keys(L).length}, transitions ${T.length}, fixtures ${Object.keys(F).length}, unverified ${all.filter((x) => x.unverified).length}, human steps ${T.filter((t) => t.actor === "human").length}`);
if (errs.length) {
  console.log(errs.join("\n"));
  process.exit(1);
}
console.log("all mechanical checks pass");
