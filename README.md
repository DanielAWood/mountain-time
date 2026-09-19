# mountain-time

Agent skills by Dan Wood. Installable with [`npx skills`](https://github.com/vercel-labs/skills) into Claude Code, Codex, Cursor, OpenCode, and others.

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

## Skills

| Skill | Description |
| --- | --- |
| [prose-review](skills/prose-review/SKILL.md) | Review comments, docstrings, and docs — delete the ones that don't earn their place, fix the rest. Args: `[path\|PR#\|branch] [--fix]` |

## Layout

```
skills/<name>/SKILL.md   # one directory per skill; extra files (scripts, references) go alongside
```

New skills must also be added to the `skills` array in `.claude-plugin/marketplace.json`.

`SKILL.md` needs YAML frontmatter with `name` (lowercase, hyphens, matches directory) and `description` (what it does and when to use it — agents use this to decide when to trigger).

## Developing

```bash
# scaffold a new skill
(cd skills && npx skills init my-skill)

# install from the working copy, symlinked, so edits apply live
npx skills add . -g -a claude-code
```

## License

MIT
