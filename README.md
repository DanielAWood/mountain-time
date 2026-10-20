# mountain-time

Agent skills and hooks by Dan Wood. Skills install with [`npx skills`](https://github.com/vercel-labs/skills) into Claude Code, Codex, Cursor, OpenCode, and others; hooks are Claude Code only.

## Install

```bash
# pick interactively
npx skills add DanielAWood/mountain-time

# one skill, globally, into Claude Code
npx skills add DanielAWood/mountain-time --skill prose-review -g -a claude-code

# list without installing
npx skills add DanielAWood/mountain-time --list
```

Update later with `npx skills update`.

### Claude Code plugin

```
/plugin marketplace add DanielAWood/mountain-time
/plugin install mountain-time@mountain-time
```

Skills are namespaced as plugins (`/mountain-time:prose-review`). Pick one install method per machine to avoid duplicates.

`mountain-time` is the skills. Each hook ships as its own plugin, listed under [Hooks](#hooks), so installing the skills never registers a hook.

## Skills

| Skill | Description |
| --- | --- |
| [prose-review](skills/prose-review/SKILL.md) | Review comments, docstrings, and docs — delete the ones that don't earn their place, fix the rest. Args: `[path\|PR#\|branch] [--fix]` |
| [create-verification-skill](skills/create-verification-skill/SKILL.md) | Generate a project-local `verify-<app>` skill that launches and drives the real app like a user and captures proof. Builds its feature map via `feature-map`, so install both. Slash command only (`/create-verification-skill`); agents won't invoke it on their own. |
| [feature-map](skills/feature-map/SKILL.md) | Create or update the user-POV map in a `verify-<app>` skill: locations and transitions to reach any screen or state, plus feature scenarios that prove behavior. Args: `[create\|update] [feature\|location\|path\|PR#\|branch\|--full]` |
| [task-shepherd](skills/task-shepherd/SKILL.md) | Shepherd a unit of work (e.g. a GitHub issue) to done: one long-lived implementation agent, then rounds of fresh review agents, with you (or the shepherd, with `--unsupervised`) deciding every finding. Review skills are configurable (e.g. `thermo-nuclear-code-quality-review`, `prose-review`); first run asks and saves them to `.agents/task-shepherd-config.md` (project or `~/`), outside the skill dir so updates keep it. Claude Code only (uses subagents); slash command only. Args: `[--unsupervised] <issue-url\|task>` |

## Hooks

### herdr-autoname

Keeps each [Herdr](https://herdr.dev) agent pane named for the session's **current phase** of work rather than its opening request — `whiteboard` → `implementation` → `review-1` → `review-1-fixes` → `review-2`. The workspace name carries the subject, so a glance down the sidebar says what every agent is doing right now.

```
/plugin marketplace add DanielAWood/mountain-time
/plugin install herdr-autoname@mountain-time
```

Requires `herdr`, `jq`, `python3`, and `claude` on `PATH`. **Does nothing unless `HERDR_ENV=1`** — outside Herdr it exits in milliseconds on the first check, so it is inert if you install it and don't use Herdr.

How it works: it runs on `UserPromptSubmit` (so the name is right well before a long turn ends) and on `Stop` (to catch phases that begin without a prompt, like a looped review skill starting its next round). Both triggers take one code path. The label comes from a stripped-down headless `claude` call — no MCP servers, replaced system prompt, no tools — which takes a few seconds, so the hook never does that inline: it validates, detaches a worker, and returns. It keeps no state; the phase is re-read off the transcript tail each time, so a manual rename is transient by design.

| Variable | Default | Effect |
| --- | --- | --- |
| `HERDR_AUTONAME_MODEL` | `claude-sonnet-5` | Labelling model. Haiku is cheaper but read a meta session as `testing` where Sonnet read `implementation` |
| `HERDR_AUTONAME_DEBUG` | unset | Set to `1` to trace why nothing happened, to `$TMPDIR/herdr-autoname.log` |

Every failure path is a silent `exit 0` — hook mode never writes to stdout, because `UserPromptSubmit` stdout is injected into the model's context. So if names aren't changing, set `HERDR_AUTONAME_DEBUG=1`; every exit logs its reason.

To see exactly what the labeller is handed for a session, run the evidence script on its transcript:

```bash
herdr-autoname/scripts/herdr-autoname-evidence.py ~/.claude/projects/<project>/<session>.jsonl
```

#### Installing without the plugin

`npx skills` installs skills only. To wire the hook up by hand, copy both scripts — they must stay in the same directory, since the shell script finds its helper via `dirname "$0"` — and register it by **absolute** path for the same reason:

```bash
cp herdr-autoname/scripts/herdr-autoname*.{sh,py} ~/.claude/hooks/
```

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "sh '/Users/you/.claude/hooks/herdr-autoname.sh'" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "sh '/Users/you/.claude/hooks/herdr-autoname.sh'" }] }
    ]
  }
}
```

## Layout

```
skills/<name>/SKILL.md   # one directory per skill; extra files (scripts, references) go alongside
herdr-autoname/          # the hook, as its own plugin
  .claude-plugin/plugin.json
  hooks/hooks.json       # registers UserPromptSubmit + Stop
  scripts/               # herdr-autoname.sh and the evidence helper it calls
```

New skills must also be added to the `skills` array in `.claude-plugin/marketplace.json`.

`SKILL.md` needs YAML frontmatter with `name` (lowercase, hyphens, matches directory) and `description` (what it does and when to use it — agents use this to decide when to trigger).

## Developing

```bash
# scaffold a new skill
(cd skills && npx skills init my-skill)

# install a snapshot of the working copy (npx skills copies; re-run after edits)
npx skills add . -g -a claude-code

# or link one skill so edits apply live (Claude Code shown)
ln -s "$PWD/skills/feature-map" ~/.claude/skills/feature-map

# check both manifests before pushing
claude plugin validate ./herdr-autoname --strict
claude plugin validate .
```

## License

MIT
