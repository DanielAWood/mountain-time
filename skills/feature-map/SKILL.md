---
name: feature-map
description: "Create or update the user-POV feature map in a project's verify-<app> skill: a nav map (locations, transitions, fixtures) that tells an agent how to reach any screen or state, plus a catalog of scenarios that prove features work. Use for /feature-map, when create-verification-skill builds its map, after building or changing a user-facing feature, or when a map route or scenario fails."
argument-hint: "[create|update] [feature|location|path|PR#|branch|--full]"
---

# Feature map

A developer who builds an app carries a mental map of it: which screens exist, how to get from one to another, what state unlocks what, and how to tell a feature works. This skill writes that map down for agents and keeps it accurate, so that an agent verifying its own work can route to any location and prove any feature without rediscovering the app.

You write for an agent that will read the map cold, mid-task, having never seen the app. Everything is from the user's point of view: screens, dialogs, prompts, and commands a user touches. Never include source files, components, or internal APIs.

The map lives in `verify-<app>/features/`: `map.yaml` (locations, transitions, fixtures), `catalog/<feature>.md` (scenarios), and `README.md` (routing and proof rules). Read [`references/schema.md`](references/schema.md) before writing anything. [`references/example/`](references/example/) is a complete map for a small notes app; match its shape and level of detail.

## 1. Locate the target

Find the project's verification skill: `<skills-dir>/verify-<app>/SKILL.md`, where `<skills-dir>` is `.claude/skills/`, `.cursor/skills/`, `.agents/skills/`, or the running agent's equivalent. Every `run:` in the map uses that skill's harness commands, and every drive uses its Launch, Doctor, and Cleanup.

- No verification skill: stop and tell the user to run `create-verification-skill` first.
- Several: ask which one. Don't guess.

## 2. Pick the mode

From the invocation arguments or request (`$ARGUMENTS`):

- `create` or `update` given: use it. `create` stops if `features/map.yaml` already exists; point at `update`. `update` stops if it doesn't; point at `create`.
- Neither given: no `features/map.yaml` means **create**, and an existing one means **update**.

Then read the mode's file and follow it. It calls back to the shared sections below.

- **create:** [`references/create.md`](references/create.md). Discover the app, walk every transition, write scenarios for the top features.
- **update:** [`references/update.md`](references/update.md). Targeted pass after a change, or `--full` audit.

## Edit scope

Edit only `verify-<app>/features/`. Never edit product code, the verify skill's SKILL.md, or its harness. A harness that can't drive something the app does is reported, not fixed here.

## Walking

A map entry nobody has walked is a guess. To walk a transition: confirm you're at `from` with its `arrive` check, run `run`, then check `to`'s `arrive`. On a match, remove `unverified`. On a mismatch, classify it first (see **Classifying a mismatch**). Fix only map drift (wrong handle, wrong destination, a missing state qualifier), then walk it again.

- Respect `effect`. Walk `none` freely. Walk `local` only under a disposable fixture, and confirm the location it leads to offers a way to undo it (in an app with no undo, the fixture's teardown is the undo). Never walk `external`: set `unverified: external effect (<what it sends>)`.
- Ask the user before walking anything that spends money, such as LLM calls or SMS quota, even when it's `local`.
- Human steps (`actor: human`): ask the user to follow the `instruction`, then check `to`'s `arrive` yourself.
- A transition that only works through a workaround handle (a coordinate click where a role click fails) is walked. Record the handle that worked, and report the harness gap.
- A walk that turns up an unknown location or transition: add it and walk it too.
- After 2–3 honest attempts, whatever still fails gets a specific `unverified` reason. Never drop it, and never mark it verified.

## Classifying a mismatch

When the map and the app disagree, decide which one is wrong:

- **Map drift:** the app works and the map describes it wrongly or not at all. Fix the map.
- **Harness gap:** the app works but the harness can't drive it. Record it as `unverified: harness gap (<what>)` and report it.
- **Product bug:** the app is broken. Mark the entry `unverified: product bug (<what>)`, keep describing the intended behavior, and report it. Don't rewrite the map to match broken behavior, and don't delete a feature because it broke.

This applies in both modes, to failed transitions and failed scenario steps alike. A new map must not record broken behavior either.

Something odd that isn't a failure (unexplained noise, a cosmetic quirk, a known limitation) goes in the feature's Gotchas, not in this classification.

## Driving rules

Follow the verify skill's launch model: one long-lived instance driven one step at a time for servers and UIs, or a fresh isolated session per drive for short-lived CLIs. For the whole run, whatever fails:

- Run Doctor before the first drive, after any failed drive, and on each fresh session. When Doctor can't see the problem (a stuck UI on a healthy process), reset to an entry location or relaunch.
- Set up fixtures in dependency order and tear them down in reverse.
- Evidence survives every cleanup. Check it at its named location rather than assuming.
- Clean up what a failed drive left behind before the next attempt. Never kill by process name; kill only what you started.
- Harness hazards you find while driving (handles that change on reload, tool timeouts, coordinate frames) belong in the verify skill's SKILL.md § Drive. Edit scope keeps them out of your hands: list them in the report, and `create-verification-skill` folds them in.

## Map checklist

Before reporting, check the whole map, not just what you changed, and fix anything that fails. Most checks are mechanical:

```bash
node <this skill's dir>/scripts/check-map.mjs <verify-app>/features
```

It needs Node and fetches the `yaml` package through `npx` on first run. It checks that everything parses, every reference resolves, fixture `requires` have no cycles, each surface has one entry, every location is reachable and has a way back, `effect` values, `unverified` reasons, `arrive` completeness, harness prefixes, the README index, and obvious source paths. Exit 0 means every mechanical check passed.

If Node isn't available, check those items by hand. Either way, check these yourself:

- [ ] `harness` matches the harness the verify skill's SKILL.md names (for a tool-call harness, its pseudo-command table).
- [ ] Every `arrive.run` is read-only and every `expect` is something a user can see.
- [ ] Every `arrive.run` and Then check fails when its handle matches nothing (absent ≠ unchanged).
- [ ] No component names or internal APIs anywhere in the map (the script only catches source paths).
- [ ] "Mapped without scenarios" in the README lists the notable features that have no catalog file.
