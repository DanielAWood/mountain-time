# Create mode

Builds a map from nothing: the full nav map, plus scenarios for up to 5 features that matter most.

A `features/` directory in another shape (for example, one markdown file per feature with no `map.yaml`) is input, not something to preserve. Mine it for entry points, commands, and gotchas, then replace it.

## 1. Discover candidates from the repo

List every candidate before driving anything:

- **Surfaces:** which of web, CLI, desktop, API, or mobile the verify skill drives, and where Launch leaves the user on each (the entry locations).
- **Locations:** routes and pages, modals and dialogs, drawers and panels, menus, wizard steps, CLI commands and subcommands, REPL or TUI modes. Look in route tables, command definitions, menu configs, docs, and existing e2e specs.
- **Transitions:** links, buttons, menu items, keyboard shortcuts, deep links, redirects after an action, and back, cancel, or close controls.
- **State gates:** anything that changes what a user can see or do: auth, role, feature flags, plan tier, empty versus populated data, dirty versus saved. Classify each gate with the schema's rule: a user can change it in-app → transition. A user can't → fixture. Sign-in on a hosted third-party page (SSO, OAuth, email codes) is usually a human step; plan for it up front.
- **Features:** user-facing capabilities, from nav labels, docs, READMEs, and changelogs.

Draft `map.yaml` from this list. Mark every entry `unverified: not yet walked`.

## 2. Walk the map

Launch, run Doctor, and set up fixtures per the SKILL.md's **Driving rules**. Starting from each entry location, walk outward breadth-first, following **Walking**. After each failed attempt that leaves the app in an unknown state, run the verify skill's Cleanup and relaunch.

## 3. Write the catalog

Choose up to 5 features that matter most (fewer if the app has fewer): core purpose, heaviest use, highest risk. A feature whose every scenario needs a human step goes under "Mapped without scenarios" instead. For each, write `catalog/<feature>.md` per the schema:

- `starts_at` lists the location on every surface that offers the feature.
- Write scenarios for the main path, the important alternates (cancel, empty, error states the user can see), and each surface.
- Every Then names an observable result and a check command. The last Then in each scenario captures proof.
- Drive every scenario once. A step you couldn't drive gets `(unverified: <reason>)` on its scenario heading.
- Gotchas are traps you actually hit or saw in the code: focus-sensitive shortcuts, debounce, defaults that hide data, output formats.

The rest of the map stays scenario-free. Update mode adds scenarios later.

## 4. Write the README

Write `features/README.md` in the shape of the example's README: how to use the map, baseline (launch, doctor, fixtures, whose instance to drive), routing rules, proof rules, the feature index, and "Mapped without scenarios." The proof rules live here and not in the verify skill's SKILL.md, so an agent loads them only when it proves a feature.

## 5. Check, clean up, and report

Run the SKILL.md's **Map checklist**. Run the verify skill's Cleanup and the fixture teardowns, and keep proof artifacts. Report:

- counts of locations, transitions, and fixtures, and how many are verified
- every `unverified` item with its reason
- product bugs and harness gaps, each with the step that exposed it
- harness hazards for the verify skill's SKILL.md § Drive
- human steps, and what each asks the user to do
- the catalog features and their scenarios
- the notable features that are mapped but have no scenarios yet, as candidates for the next pass
