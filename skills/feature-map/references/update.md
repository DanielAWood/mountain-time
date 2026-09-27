# Update mode

A feature map starts going out of date the moment the app changes. Update mode brings it back in line with the app.

## Scope

From the invocation arguments or request, after the mode word:

- **empty**: uncommitted changes plus the current branch's diff against its base. This is targeted mode.
- **a feature ID, location ID, path, PR number, or branch**: that slice. Targeted mode.
- **`--full`**: the whole map. Full mode.

In targeted mode, read the code only to learn which user-facing surfaces changed. What you write to the map is still user-POV only.

## Outcomes

End with exactly one outcome, and say which:

- **clean**: everything in scope was driven and matched. No edits.
- **changed**: proven edits are in the working tree. Commit or open a PR only if the user asks.
- **blocked**: coverage couldn't finish. Say exactly what blocked it and what was covered.

## 1. Work out what's affected

**Targeted:** from the diff or the named slice, list which user-facing surfaces were added, changed, or removed: routes, dialogs, commands, controls, shortcuts, state gates, labels. Map each one to:

- existing locations and transitions whose handles, destinations, or `arrive` checks may have changed
- catalog features whose `starts_at` or scenarios touch those locations
- new locations, transitions, fixtures, or features that the map lacks
- removed surfaces whose locations and transitions must go

Add each affected location's neighbors (its inbound and outbound transitions) so that routes through it get re-walked too.

**Full:** everything. Also check the map for problems it has regardless of what changed: catalog files missing from the README index or listed there but gone, and surfaces in the app that the map lacks. Require a concrete user-facing handle (a route, a button label, a command) before calling a surface missing.

If the agent supports subagents, full mode can fan out one read-only subagent per catalog feature or per surface, run in parallel. Each reports, from the code, what the user can do there and any likely drift, with citations. Subagents never drive the app and never edit files. The coordinator does all the driving.

## 2. Draft the edits

Edit `map.yaml` and the catalog following the schema:

- Mark new or changed locations and transitions `unverified: not yet walked`.
- A new state gate follows the schema's rule: a user can change it in-app → transition. A user can't → fixture.
- Removed surfaces: delete their locations and transitions, then fix every reference to them (`from`, `to`, `starts_at`, scenario Givens).
- A new user-facing feature gets a catalog file if it's among the app's most important features. Otherwise, list it under "Mapped without scenarios" in the README.
- In full mode, add scenarios for features listed under "Mapped without scenarios" only when the user asks.

## 3. Drive it

Driving is required even when the code looks unchanged. Launch, run Doctor, and set up fixtures per the SKILL.md's **Driving rules**.

1. Walk every in-scope transition, following **Walking**.
2. Run every in-scope catalog scenario, and capture proof as the features README requires.

## 4. Check, clean up, and report

Run the SKILL.md's **Map checklist** over the whole map, not just the edits. Removing a location can strand another location's only way back. Run the verify skill's Cleanup and the fixture teardowns, keep proof artifacts, and re-read every changed file. Report:

- the outcome (clean, changed, or blocked) and the scope covered
- the map edits: added, changed, and removed locations, transitions, fixtures, and scenarios
- every `unverified` item with its reason, new ones first
- product bugs and harness gaps, each with the step that exposed it
- harness hazards for the verify skill's SKILL.md § Drive (you can't edit it; the user or `create-verification-skill` does)
