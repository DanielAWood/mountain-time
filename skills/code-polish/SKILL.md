---
name: code-polish
description: "Single entry point for the surface pass: runs every prose, comment, and naming review over one scope, collates them into one report, and applies only changes that cannot alter behavior. Use for /code-polish, as the final clarity round after structural review is finished, or when the code is right and only how it reads is left."
argument-hint: "[path|commit|range|branch|PR#] [--fix]"
---

# Code Polish

Finish the surface. Every finding here changes how the code *reads* — comment wording, doc prose, identifier names — and none of them change what it does. This is the last pass, run once, after structural review has stopped producing findings.

The order matters and is not a preference. Carving removes material; polishing works the final surface. Polish a form that is still wrong and the work is wasted when the form changes. So if a finding here needs a code change to fix properly, it is not a polish finding — it goes in **Deferred** and the structural review owns it.

## Target

Scope comes from the invocation arguments or request (`$ARGUMENTS`):

- empty → uncommitted changes plus the current branch's diff vs its base
- a path → that file or directory tree
- a commit, range, branch, or PR number → that diff; for a single commit, compare against its first parent
- `--fix` anywhere in the args → apply the collated findings after reporting; otherwise report only

Resolve the scope **once**, and give every reviewer the same scope plus the same base revision. Without a shared base a reviewer cannot tell what the change introduced from what was already there, and the findings stop lining up. Never hand a reviewer bare paths with no base revision.

## Roster

Read the first of these that exists:

- `<repo root>/.agents/code-polish-roster.md`
- `code-polish-roster.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

One entry per line, naming what to invoke:

```
- skill: prose-review
- skill: naming-review
- skill: comment-slayer --prose-only
```

`skill:` and `agent:` name something installed in the harness. `file:` is a path to an instruction file the reviewer reads and follows exactly — use it for a review that lives as a slash command, a prompt file, or anything the harness won't let a reviewer invoke directly. Trailing arguments pass through to the entry.

With no roster file, run those three defaults. Check each entry resolves; if one doesn't, say so and carry on with the rest — never silently substitute another.

**A roster file replaces the defaults; it does not extend them.** The first file that exists is the whole roster, so a project or personal roster written before a default was added silently drops it, and the pass goes on looking complete. Before running, diff the resolved roster against the three defaults above and **name every default it omits** — say which review therefore goes unrun this round, and that adding a line to the resolved roster file is what fixes it.

`comment-slayer --prose-only` suppresses its structural flags, which `code-carve` has already dealt with, and leaves its prose verdicts.

Reviewers with overlapping remits are wanted here, not a problem to fix. `prose-review` is calibrated and `comment-slayer` deletes harder; the two disagreeing about the same comment is the signal, and **Collate** resolves it.

## Run the reviews

Where the harness has subagents, launch every roster entry **concurrently in a single message**. Where it doesn't, run them in sequence. Either way each reviewer gets:

1. The exact scope and the resolved base revision.
2. Its own instruction file, and the instruction to follow that file exactly.
3. **Report-only framing: do not edit, stage, or commit** — even where its own instructions offer a fix mode. This skill applies the edits, so that overlapping findings are reconciled before anything is written.
4. The project's documented vocabulary, where it has one — `UBIQUITOUS_LANGUAGE.md`, a glossary, or the terminology section of `CLAUDE.md`. A reviewer without it recommends names and wording that read well and quietly disagree with the rest of the codebase.
5. A request to say plainly when it finds nothing.

## Collate

Present one report grouped by reviewer, preserving each finding's `path:line`, the current text, and the proposed change. Say plainly when a reviewer returned nothing.

Then reconcile across reviewers:

- **Same line, two verdicts** — report once, and take the stronger verdict. Deletion outranks rewriting; a comment that does not earn its place is not improved by better wording.
- **Same line, contradictory verdicts** — one reviewer deletes what another rewrites, or two propose different names. Present it as one decision with both arguments, and do not apply either until it is settled.
- **A rename and a prose finding on the same symbol** — one decision, not two. A better name often deletes the comment that explained the worse one.

## Deferred

Some findings surface here but cannot be fixed here. List them separately, apply none of them, and name the structural review as their owner:

- A comment that only exists because the code is not self-evident. The prose is the symptom; the code is the defect.
- A lint or type suppression that is hiding something real.
- A name that is wrong because the abstraction behind it is wrong. Renaming it makes the code read fluently about the wrong concept.
- A rename that crosses a compatibility boundary — a public API, a serialized field, a persistence key, a wire contract. These are visible outside the codebase, so they are not behavior-preserving and need their own decision.

Deferred findings are the honest signal that the structural pass finished early. Say so plainly rather than quietly polishing over them.

## Fix Mode

With `--fix`, apply the collated findings, in this order:

1. **Renames first.** A rename changes every reference, not just the declaration. Run the project's typecheck and test suite afterward and report the result.
2. **Then prose.** Re-judge every prose finding against the renamed code before applying it: a rename frequently turns a surviving comment into a redundant one, and that comment should now be deleted rather than rewritten.

Structural safeguards — the diff must contain nothing but surface changes:

- A prose finding may only change comment, docstring, and doc lines. Deleting a whole-line comment removes the line entirely, including its indentation and newline; deleting a trailing comment leaves the code line with its trailing whitespace stripped.
- A rename may only change the identifier's own tokens. Nothing else on those lines moves.
- Preserve surrounding structure exactly: indentation of every remaining line, blank-line spacing, trailing newline, existing line endings. Never re-wrap, re-indent, or re-order code to close a gap.
- After applying, read the diff. Every changed line must be a comment, a doc line, or a line where only an identifier token changed. Revert anything else.
- Tests and typecheck must pass. A polish pass that breaks them has changed behavior and the change is wrong by definition, not merely in need of a fixup.

Report what was applied, what was deferred, and what is still unsettled.

## Do Not

- Do not restructure, extract, inline, or re-order code. Not even where it would obviously be better — that is the structural review's call, and making it here destroys the guarantee that this pass is behavior-preserving.
- Do not add comments to raise coverage. Fewer, denser comments is the target.
- Do not rewrite a bad comment into a slightly better bad comment. Delete it.
- Do not report a name or a comment that the change under review did not introduce or touch.
- Do not loop. This pass runs once; renames and deletions converge in a single round, and a second pass mostly re-litigates wording.
