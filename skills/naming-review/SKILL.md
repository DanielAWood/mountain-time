---
name: naming-review
description: "Review the function, variable, parameter, type, constant, schema, and test-helper names a change introduced. Recommends a rename only where the current name hides meaning, creates ambiguity, or misstates behavior. Use for /naming-review, or as the naming reviewer in a code-polish roster."
argument-hint: "[commit|range|branch|PR#|path — defaults to the working tree]"
---

# Naming Review

Review changed identifiers for the target: `$ARGUMENTS`.

Recommend renames only where the current name hides important meaning, creates ambiguity, or misstates behavior. A name that is merely short is not a finding.

## Establish Scope

1. Identify the requested commit, range, branch diff, staged diff, or working-tree change. For a single commit, compare against its first parent.
2. Run `git status --short` before reviewing. If the worktree holds later edits, inspect them separately and do not report names already corrected.
3. Build the candidate set from the diff's **added lines only**. A declaration is a candidate when the diff adds the line that declares it, or when the diff changes what that declaration holds or does. Widened use is not a candidate: a pre-existing declaration stays out of scope even when the change adds call sites, moves it, reindents it, or alters surrounding code.
4. Verify each candidate before reporting it. Run `git log -1 -S'<name>' -- <path>` or `git blame` on the declaration line and confirm the declaring commit is the one under review. Drop any candidate that predates it.
5. Read each candidate in its full scope and inspect representative call sites, types, return values, comments, and tests. Use surrounding code to judge a candidate, never to add one.
6. Use `rg` where available; fall back to `grep` or `find`.

## The Project's Lexicon

A name has to agree with the vocabulary the project already uses, not merely read well on its own. Establish the established terms before recommending anything.

Look for a documented lexicon: `UBIQUITOUS_LANGUAGE.md`, a glossary, a domain model doc, or the terminology section of `CLAUDE.md` or the README. Where one exists it is authoritative. A rename toward a synonym it rejected is a regression however much clearer it reads, and an identifier using a term the lexicon doesn't define is worth raising on its own.

Where nothing is documented, derive the lexicon from the code: how do the surrounding modules, types, and tests name this concept? Consistency with the term already in use beats a marginally better word. One term per concept is worth more than any individual name.

Report a name that collides with an established term even when the name is good in isolation, and say which term it collides with.

## Evaluate Names

Prioritize names that:

- Distinguish multiple concepts present in the same scope — an API cursor, a datastore cursor, and a domain frontier.
- Identify wrapper values accurately. If a library returns `{ data, error }`, do not name the wrapper as though it were the contained entity.
- State the domain noun rather than relying on generic names: `data`, `result`, `item`, `value`, `collected`, `keys`, `config`.
- State units, representation, or lifecycle where a mistake is plausible — epoch milliseconds versus seconds, a raw client versus a document client.
- Use verb-led names for actions, `is`/`has`/`can` for predicates, `create`/`build` for factories, and `to` for actual conversions.
- Describe collection contents and keying: `projectsById` rather than `byId`.
- Describe test-helper outcomes rather than mechanics: `createTestProject` or `listAllProjectIds` rather than `seed` or `pageAll`.
- Remain specific when exported or likely to share a wider namespace.

A misleading name is a stronger finding than a merely short one. A helper named `toIso` that only replaces `undefined` with `null` matters more than a tightly scoped `project`.

## Calibrate Recommendations

- Never report a name whose declaration predates the change under review. A pre-existing name is out of scope however poor it looks, and a nearby candidate does not pull it in. Where a pre-existing name genuinely obstructs reading a new one, say so as a note and leave it unreported.
- Accept short locals when their scope is small, their type is obvious, and no competing concept exists.
- Accept established domain terms and conventional callback names.
- Never introduce a synonym for a concept the codebase already names. Where the existing term is genuinely the worse word, say so as a note about the lexicon rather than renaming one site and leaving the codebase speaking two languages.
- Do not recommend longer names that only repeat enclosing class or function context.
- Do not mechanically flag every `result`, `page`, or `project`. Explain the concrete ambiguity each recommendation removes.
- Stay focused on naming. Mention a behavioral issue only where it proves a name is inaccurate.
- Do not edit code unless the caller asked for the renames to be applied.

## Compatibility Boundaries

A rename that crosses a boundary visible outside the codebase is not a cosmetic change and must not be presented as one. Report these separately and say plainly what else would have to change:

- A public API surface, an exported symbol other packages import.
- A serialized field, a persistence key, a wire or schema contract.
- Anything a consumer matches on by name — an event type, a config key, a CLI flag.

These need their own decision, and in a behavior-preserving review round they are deferrals rather than findings.

## Report Findings

Present high-confidence candidates first. For each:

1. The declaration, as `path:line`.
2. `currentName` → `suggestedName`.
3. One concrete reason based on the identifier's actual role.
4. The commit that introduced the declaration, as evidence the name is in scope. A candidate without this does not get reported.

Group related locals from one scope into one finding. Separate production-code candidates from lower-priority test-only candidates where it helps. Note names already corrected in the worktree, and say explicitly when no further candidates were found. End with any names considered but intentionally retained, where that shows the review was calibrated.
