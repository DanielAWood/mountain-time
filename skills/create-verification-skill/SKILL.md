---
name: create-verification-skill
description: "Generate a project-local verification skill that drives your app the way a user does — any language, framework, or platform. Use for /create-verification-skill, \"make a verification skill for this repo\", or when a project has no scripted way to prove UI/CLI/service behavior."
disable-model-invocation: true
---

# Create a verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as a project-local skill (`<skills-dir>/verify-<app>/`) tailored to the repo. You write the generator's output for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

`<skills-dir>` is the project skills directory of the agent running this skill: `.claude/skills/` for Claude Code, `.cursor/skills/` for Cursor, `.agents/skills/` for Codex; otherwise that agent's documented equivalent. If the repo already has a project skills directory, use it.

## 0. Check dependencies

The feature map in step 3 is built by the `feature-map` skill. Confirm it is installed before generating anything: it appears in your skill list, or its `SKILL.md` exists under `<skills-dir>/feature-map/` or the agent's global skills directory (`~/.claude/skills/` for Claude Code). If it isn't, stop and tell the user to install it; a verify skill without its map is half-built.

## 1. Interview the repo, not the user

Answer these from the codebase and only ask the user what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an API, a mobile app, a library? A repo can have several; pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data, auth.
- **Drive:** how can an agent interact with it programmatically? Existing harnesses first — Playwright/Cypress specs, expect scripts, PTY helpers, curl-able endpoints, a debug port. Only then pick a generic recipe: browser/CDP for web and Electron, a tmux/PTY harness for CLI/TUI, plain HTTP for services.
- **Observe:** what evidence can be captured? Screenshots, terminal transcripts, response bodies, logs, exit codes, DB state.
- **Isolate:** can two instances run side by side (ports, data dirs, profiles)? If not, say so in the generated skill: refusing to double-drive a shared instance beats corrupting the user's session. If the only slot (a pinned port, a single profile) is held by an instance you didn't start, ask the user before step 2. Don't drive it and don't kill it unless they say so. Driving it (adopting it) needs the user's explicit go-ahead, a Doctor pass that confirms it is this repo's app with the expected config, and a record that the run doesn't own the process, so Cleanup leaves it running.
- **Cost:** what does each action spend? Metered calls (LLM tokens, SMS, paid APIs) on every save or query shape how many scenarios are worth writing, and the walker must get the user's consent before spending. Record the cost per action in the generated skill.
- **Browser profile:** if the harness drives a browser, does it get an isolated profile, or does it share the user's (where the user may already be signed in)? Prefer an isolated one.

If the checkout doesn't build or start as-is, fix that first (or report it precisely) before generating; a skill written against a broken base teaches wrong steps. Agent shells often lack the user's toolchain activation (nvm, corepack, pyenv); if the repo pins a version, Launch activates it itself rather than trusting the ambient PATH. When an irrelevant missing asset blocks startup (a static dir the API never serves, a sample config), the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

## 2. Generate the skill

Write `<skills-dir>/verify-<app>/SKILL.md` with YAML frontmatter (`name: verify-<app>` and a `description` that names the app, the surface, and when to reach for it — without frontmatter the skill never registers) and these sections, each grounded in what the interview actually found (no placeholders left). Treat this as a draft: step 3's walk will teach you things (harness hazards, launch quirks, human steps) that you fold back in here.

- **Launch:** the exact command that starts the app for verification, and how to tell it's ready (a log line, a port answering, a prompt). Include teardown. Launch must not change in-app state: it leaves each surface where a fresh user starts (signed out, no dialogs open), because the feature map routes from there and treats sign-in as a step it takes itself. Test accounts and seed data are the map's fixtures, not part of Launch. If the harness has to share the user's browser profile and it opens signed in, Launch signs out and tells the user it did. For a short-lived CLI or TUI there is no server to keep alive: launch means build the binary (or install deps) once, then start each drive in its own isolated PTY or tmux session.
- **Doctor:** one read-only check that answers "is this instance worth driving?" — process up, right version/build, port owned by us (or adopted with the user's go-ahead), auth service reachable. If a surface depends on more than one backend entry point (a second API route, a streaming endpoint, a websocket, a queue), probe each one: a check that only hits the busiest path misses a partial outage. It never signs in or checks a specific account: test accounts are map fixtures, set up after Doctor runs. An agent runs this first whenever anything looks off.
- **Drive:** the harness recipe with real selectors/commands from this repo, not examples. Prefer stable handles (ARIA labels, data attributes, prompt strings, route paths) over coordinates and tab order. If the harness is tool calls with no command line (MCP browser tools), define short pseudo-commands (`chrome click button "Sign out"`) in a table mapping each to its tool call; the feature map uses their shared prefix as its `harness`. When the harness can't confirm focus before typing (focus and type are separate tool calls), the recipe reads the field's value back before submitting, so lost input fails loudly instead of silently. Harness hazards (handles that change on reload, tool timeouts, coordinate frames) are listed here.
- **Evidence:** what to capture for a proof (screenshots, ARIA snapshots, transcripts, response bodies, side-effect checks) and where it goes. Name the app's error channel (browser console, stderr, server log) and how to read it: every proof includes it, because unhandled rejections and runtime errors often never reach the screen. Say how each artifact reaches disk with this harness (a tool that returns a screenshot inline needs an explicit save step). The full proof standards live in `features/README.md`, written in step 3, so they load only when an agent proves a feature. Link to that README from here rather than repeating it.
- **Cleanup:** how to tear down instances the run created. Never kill by process name; kill what you started, and leave an adopted instance running. Cleanup removes instances and scratch state, never the evidence: proof artifacts survive the teardown, in a location the skill names.
- **Helpers:** any script the skill ships is executable and its invocation is shown in the skill body. A helper the reader has to reverse-engineer is not a helper.

Also write `verify-<app>/.gitignore` covering run state (PIDs, logs, scratch) and `artifacts/`, so the skill itself can be committed without its output.

## 3. Build the feature map

Invoke the `feature-map` skill in `create` mode against the skill you just generated. It writes `verify-<app>/features/`: a nav map (`map.yaml`) of locations and transitions an agent routes through, a catalog of feature scenarios that prove behavior, and a README with the routing and proof rules. It drives the harness from step 2 to confirm what it writes, so step 2's Launch, Doctor, and Drive must already work.

`feature-map` can't edit this skill's SKILL.md. Fold the harness hazards and launch quirks its report lists into step 2's sections. If the map has human steps, make sure the skill keeps them to a minimum (ideally one sign-in per run).

The map is the repo's maintained verification source. A proof that drives one convenient entry point is incomplete when the map lists others.

## 4. Prove the generated skill before handing it over

Run its own instructions end to end once: launch, doctor, route to ONE catalog feature with `map.yaml` and run its scenarios (one is enough; the map exists so later runs can cover the rest), capture evidence, clean up. If step 3's walk already did this with the final Launch, Drive, and Cleanup, it counts; then only re-run Cleanup and check the evidence. After cleanup, confirm the evidence still exists at the named location — a cleanup that eats the proof fails this step. Fix what fails, and run the generated cleanup after every failed iteration too, so broken attempts don't strand processes and ports. A generated skill that was never executed is a draft, not a deliverable.

## 5. Land it and offer the maintenance loop

The skill is the repo's verification source only once it's in the repo. Offer to commit `verify-<app>/` (the `.gitignore` keeps run state and artifacts out); commit only if the user agrees.

Point the user at `feature-map update`: run it after changing a user-facing feature (targeted), or with `--full` for a periodic audit. Suggest a cadence only if they ask.
