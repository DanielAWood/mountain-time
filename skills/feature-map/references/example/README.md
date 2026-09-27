# Notes feature map

How to reach and prove every user-facing feature of Notes. Read this file first, then open only what the task needs:

- **Getting somewhere:** `map.yaml`. Find the target location, then follow transitions back to an `entry: true` location for its surface.
- **Proving a feature:** `catalog/<feature>.md`. Route to one of its `starts_at` locations, then run its scenarios.

The format is defined by the `feature-map` skill's `references/schema.md`.

## Baseline

- Launch and tear down Notes with the steps in `../SKILL.md`. Launch leaves the browser at `web:sign-in` and a terminal at `cli:shell[signed-out]`.
- Run `control-notes doctor` before driving, and again whenever anything looks off.
- Set up the fixtures a location, transition, or scenario `requires` before routing to it, each after the fixtures it requires. Tear them down in reverse order during cleanup.
- Never drive an instance this run did not start.

## Routing

- Prefer `effect: none` transitions. Take `local` only when no `none` route exists. Never take `external` unless the task is to verify that effect.
- After every transition, run the destination's `arrive.run` and confirm `arrive.expect` before the next step.
- If an arrival check fails, stop and run `control-notes doctor`. Do not keep clicking forward.
- Items marked `unverified` have never been walked. Treat them as a lead, not a fact, and say so in the report.

## Proof

- Drive the real user path. Never use internal setters, test-only endpoints, or direct DB writes to reach a state.
- Capture the action and the resulting state, not only the final screen.
- Every proof includes the error channel: the browser console for UI, stderr for CLI. An error there fails the proof even when the screen looks right.
- UI proof: an ARIA snapshot and a screenshot with the Notes identity visible.
- CLI proof: the command, stdout, stderr, and exit code.
- Changes to stored data: confirm them from a second, read-only view (reopen from the list, or `notes list`). Check side effects (files written, rows inserted, messages sent) alongside what's visible.
- Mock only where a production boundary already isolates the external system.
- A synthetic trigger (a scripted click in the same batch as the action before it) is allowed only when the window is shorter than a harness round trip, such as Stop on a reply that finishes in seconds. Name it in the scenario and say why.
- For a dry-run or test mode, don't trust its name. Observe what it actually skips (files, network, git refs).
- Save artifacts under `artifacts/<feature>/`. Cleanup never deletes them.
- A feature is proven only when each of its `starts_at` locations has been exercised. Report any you skipped, with the command you tried and the precondition that wasn't met. Never report a skipped one as proven through another.

## Features

| Feature | Starts at | Covers |
| --- | --- | --- |
| [create-note](catalog/create-note.md) | `web:note-editor[new]`, `cli:shell` | browser and CLI create, cancel draft, persistence |
| [search](catalog/search.md) | `web:search-dialog`, `cli:shell` | title and body match, empty state, clear, CLI search |

## Mapped without scenarios

Locations in the map with no catalog feature yet: `web:share-dialog` (sharing), note deletion from `web:note-editor[existing]`.
