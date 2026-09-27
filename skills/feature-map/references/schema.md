# Feature map schema

A feature map has two layers:

- **Nav map** (`map.yaml`): a graph of **locations** (where a user can be) and **transitions** (how a user moves between them), plus the **fixtures** that set up state a user cannot change in-app.
- **Feature catalog** (`catalog/<feature>.md`): user-facing **features**, each made of **scenarios**, each made of **steps** (action + expected result).

```
verify-<app>/features/
├── README.md              # conventions, proof rules, feature index
├── map.yaml
└── catalog/<feature>.md
```

The map is written for the user's point of view. It names screens, dialogs, prompts, and commands a user touches, never source files, components, or internal APIs.

## map.yaml

```yaml
harness: <prefix>               # command prefix of every location and transition run:; see Harness

fixtures:
  <fixture-name>:
    description: <what state this establishes, user POV>
    requires: [<fixture-name>]  # optional; fixtures that must be set up first
    setup: <command> | [<command>, ...]
    teardown: <command> | [<command>, ...]

locations:
  "<surface>:<view>[<state>]":
    description: <one line, user POV>
    entry: true                 # optional; where a surface's launch lands you
    requires: [<fixture-name>]  # optional
    arrive:
      run: <command>            # read-only check that you are here
      expect: <observable result>
    unverified: <reason>        # optional; see Verification

transitions:
  - from: "<location-id>"
    to: "<location-id>"
    action: <what the user does, user POV>
    run: <command> | [<command>, ...]
    effect: none | local | external
    requires: [<fixture-name>]  # optional
    unverified: <reason>        # optional

  - from: "<location-id>"      # a step only a human can do; see Human steps
    to: "<location-id>"
    action: <what the user does, user POV>
    actor: human
    instruction: <what to ask the human to do>
    effect: none | local | external
```

### Harness

`harness` is the prefix every location and transition `run:` starts with. For a CLI harness it's the command (`control-notes`). For a tool-call harness with no command line (MCP browser tools), the verify skill's SKILL.md § Drive defines pseudo-commands (`chrome click button "Sign out"`) with a table mapping each to its tool call, and `harness` is their shared prefix (`chrome`).

Fixture `setup` and `teardown` may instead call the verify skill's helper scripts, since fixtures often run outside the UI harness.

### Location IDs

`<surface>:<view>` with an optional `[<state>]`. Use kebab-case, and quote every ID in YAML.

Quote any value that contains `: `, or starts with `[`, `{`, `*`, `&`, `!`, `|`, `>`, `'`, `"`, `%`, `@` or a backtick. Otherwise YAML misparses it, and JSON-shaped expectations such as `"email": "x"` are the common case. Use single quotes around values that contain double quotes.

- **surface:** what the user touches: `web`, `cli`, `desktop`, `api`, `mobile`, or a repo-specific name when an app has two of a kind.
- **view:** a screen, route, dialog, panel, REPL mode, or prompt.
- **state:** add it only when the state changes what the user can see or do there. `web:note-editor[new]` and `web:note-editor[existing]` differ (only one has Delete). `web:home` with 3 notes versus 4 notes does not.

### Entry locations

Each surface has exactly one `entry: true` location, where the verify skill's Launch step leaves a user (the sign-in page, a signed-out CLI prompt). It is the root for routing. You reach it by launching, not by a transition. Launch doesn't sign in or otherwise change in-app state. Anything a user does after launch, including signing in to a CLI, is a transition.

### State: transitions versus fixtures

- **Transition:** state a user can change inside the app, such as signing in, creating a record, opening a dialog, or an admin toggling a flag in settings.
- **Fixture:** state a user cannot change in-app, such as seed data, the account's role, an env flag, or a license tier. Locations, transitions, scenarios, and other fixtures that depend on it list it in `requires`. Set fixtures up before routing, each after the fixtures it requires, and tear them down in reverse order during cleanup. No cycles.

### Human steps

Some transitions only a human can do, such as signing in on a hosted third-party page (SSO, OAuth, email codes), where an agent must not enter credentials. Mark them `actor: human` with an `instruction:` in place of `run:`. To walk one, ask the user to follow the instruction, then check the destination's `arrive` yourself. A human step that arrives counts as verified. Human steps are exempt from the harness prefix.

Every human step costs a user interruption on every run. Keep them few (ideally one sign-in per run) and route around them where a `none` path exists.

### Arrival checks

`arrive` lives on the location, so every transition into it uses the same check. `run` must be read-only. `expect` names something the user can see: a heading, a dialog name, a prompt string, a JSON field. It never names a CSS path or a sleep.

`run` may be retried for a bounded time (say up to 10 seconds) while the app settles, such as a loading screen after navigation. Retry the check; never add a fixed sleep. Prefer role and accessible-name queries. When the harness can't query by role, a selector in `run` is acceptable; `expect` still describes what the user sees.

### Effects

| effect | meaning | when building the map |
| --- | --- | --- |
| `none` | navigation only, no stored change | walk freely |
| `local` | changes app data the run owns | walk only under a disposable fixture; the location it leads to should offer a way to undo it, or, in an app with no undo, the fixture's teardown undoes it |
| `external` | leaves the system: email, payment, third-party API, push | never walk; record as `unverified: external effect` |

A step that stays in-system but spends money (an LLM call, an SMS quota) is still `local` or `none`, but walking it needs the user's consent first. Note the cost in `action`.

When routing, prefer `none` edges. Take a `local` edge only when no `none` route exists, and never take an `external` edge unless the task is to verify that effect.

### Way back

Every location must have a route back to its surface's entry without relaunching. Return paths are ordinary transitions: Escape, a Back or Cancel control, browser back, a nav link, sign out.

### Verification

Every location and transition is confirmed by driving it. Anything you could not confirm stays in the map with an `unverified` reason, such as `external effect`, `needs hardware key`, or `arrive check times out; see Gotchas in search.md`. Never drop it and never mark it as verified.

## catalog/<feature>.md

```markdown
---
feature: <feature-id>
starts_at: ["<location-id>", ...]
requires: [<fixture-name>, ...]
---

# <Feature title>

<One paragraph: what the user can do, user POV.>

## Scenario: <name>

- **Given** at `<location-id>`, <any extra precondition>
- **When** <user action>. Run `<command>`.
- **Then** <expected result>. Check `<command>`.

## Gotchas

- <traps that waste or invalidate a run>
```

- `feature` is kebab-case and matches the filename.
- `starts_at` lists every location where the feature begins. List a location on each surface that offers the feature. A proof that covers only one of them is incomplete.
- A scenario proves one behavior. It starts at a `starts_at` location (or a location reachable from one), alternates When/Then steps, and ends with a Then that captures proof.
- Steps restate commands. They do not reference transitions. Moving to another location mid-scenario is fine: use the same command the map's transition uses, and check the destination's `arrive`.
- A scenario that could not be driven carries `(unverified: <reason>)` after its heading. This includes states the UI handles but a user can't cause (a save failure with no way to trigger it): write the scenario and mark it `(unverified: no user-reachable trigger)`.
- A step only a human can do is written **When** (human) <instruction>.
- Gotchas also hold observations that aren't failures: unexplained noise, cosmetic quirks, known limitations.
