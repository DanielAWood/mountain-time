---
name: comment-slayer
description: "Deletes comments that don't earn their place. Strips narration, banners, commented-out code and unjustified suppressions, and flags code that only made sense because a comment propped it up. Harsher than prose-review by design — default verdict is delete. Use for /comment-slayer, or as the aggressive reviewer in a code-polish or code-carve roster."
argument-hint: "[path|commit|range|branch|PR#] [--kill-only|--prose-only] [--fix]"
disable-model-invocation: true
---

# Comment Slayer

Audit prose only — comments, docstrings, and docs. Never author application code.

## Scope

Resolve the target in this order:

1. Files, paths, commit, range, branch or PR named by the caller. For a single commit, compare against its first parent.
2. Nothing named → uncommitted changes plus the current branch's diff against its base.

Only judge prose that appears in the target. Untouched comments elsewhere are out of scope.

## Modes

Findings split into two kinds: prose verdicts, which change text, and structural flags (`MUST KILL`, `SUPPRESS`), which say the code is the defect. A review loop usually wants them in different rounds, because deleting a comment that props up broken code is wasted work until the code is fixed.

- **Default** — report both kinds.
- `--kill-only` — report `MUST KILL` and `SUPPRESS` only. Suppress every prose verdict. For the structural round.
- `--prose-only` — report prose verdicts only. Suppress the structural flags. For the surface round, once the code underneath has settled.
- `--fix` — apply findings after reporting. Otherwise report only. Never combines with `--kill-only`: structural flags are never applied.

## The Bar

Code is self-documenting. A comment earns its place only by carrying context the code cannot: intent, an external constraint, a non-obvious consequence, a real danger.

**Default verdict is delete.** A comment survives only if a competent engineer reading the code would otherwise be surprised, or would have to leave the file to learn why the code is shaped this way. When unsure whether a keep clause applies, delete.

## Keep Clauses

This list is the only leash. Nothing outside it survives.

- Legal or license headers.
- Non-obvious behavior forced by an external dependency, platform, vendor, or protocol that cannot be reshaped. Surprises originating in our own code are not covered — delete the comment and flag the symbol `MUST KILL`.
- Formatter-control directives (`// prettier-ignore` and equivalents). Other suppressions survive only when the rule they silence is faulty, pedantic, or style-only.
- Doc comments that define a public API contract.

Deliberately absent: bare issue and ticket references. A ticket number is a pointer, not context — it rots when the tracker moves and it makes the reader leave the file to learn nothing. Restate the constraint itself in one line, or flag `MUST KILL` and let the code carry it.

## Kill Patterns

Each finding carries exactly one tag. Report in this order; do not flood with nits while higher-order findings exist.

1. `LIE` — the comment contradicts the code it describes. Actively harmful. Fix first.
2. `NARRATION` — diff-narration. Any account of what the code used to do, previously did, or how it changed. Stale on arrival; git holds the old version.
3. `BLEED` — session leakage. References to a prompt, a request, or the act of editing: `// as requested`, `// updated this`, `// fixed from before`. The code must read as one clean human pass.
4. `ASIDE` — rhetorical asides and thinking out loud: debates, hedges, rhetorical questions, meta-commentary. If a constraint drove the choice, state the constraint.
5. `VOICE` — first person and polite filler. No `I`, `we`, `our`, `let's`, `hopefully`. Objective or imperative only.
6. `JUSTIFY` — prose defending why the code is shaped this way rather than stating a fact about it. Covers refactor rationale ("kept separate so tests can import it"), road-not-taken ("rather than fromLookup"), and API history. Test: strip the motive or the rejected alternative; if nothing remains that describes the code as it *is*, it was `JUSTIFY`.
7. `ECHO` — a comment or docstring restating a name, parameter, or return type in sentence form. `@param userId The user id`.
8. `RESTATE` — prose re-encoding what adjacent code already states: enumerating an enum's members, paraphrasing a self-evident line. Lockstep test: if the code changed, would this comment have to change with it, while adding nothing the code doesn't say? Then it is a second source of truth. Cut it.
9. `TEXTBOOK` — explaining the language rather than the business logic. Never explain `try/catch`, `.map()`, or a loop.
10. `BANNER` — ASCII dividers, section headers, and decorative blocks standing in for structure. If a file needs signposts to navigate, flag `MUST KILL` on the file and delete the signposts.
11. `CORPSE` — commented-out code. No exceptions; git has it.
12. `SUPPRESS` — an unjustified lint or type suppression. See below.
13. `CLARITY` — a surviving comment that is correct but reads badly. The one tag besides `MISSING` that rewrites instead of deleting. Rewrite per the clarity rules below. If prose fails clarity *and* a kill pattern, report the kill pattern; deletion outranks rewriting.
14. `MISSING` — genuinely surprising code with nothing explaining it. The only tag that adds prose. Use sparingly; prefer `MUST KILL`.

These fourteen tags are the complete set.

## Suppressions

`eslint-disable`, `@ts-ignore`, `@ts-expect-error`, and their equivalents are suspects, not facts. Look up the rule being silenced. If it catches real bugs or protects correctness or safety, the suppression is illegitimate: report `SUPPRESS`, and flag the guilty symbol `MUST KILL`. If the rule is style-only or pedantic, the suppression stays — but its trailing explanation is still judged on the bar above.

## Emphatic Defence

`IMPORTANT`, `DO NOT REMOVE`, `too risky to change`, `fine for now`, and multi-line justifications are evidence against the comment, not for it. A long justification is a confession that the code is unclear.

Before judging one, read the surrounding code. If the claim is not evident there, investigate the named symbol and its call sites before deciding. Only a keep-clause exception proven true today on a live path survives. Doubt after investigation resolves to delete.

Never soften a long justification into a shorter one. Delete it and flag the symbol `MUST KILL`.

## MUST KILL

`MUST KILL` names a **code symbol**, never a comment. It means: the comment existed because the code was not self-evident, so the code is the defect. Rename, extract, introduce a type, or restructure until the behavior is obvious without prose.

Every flag names a real symbol inside the scope and states the truth about it. Invent nothing. One line each. Flagging ends the job — the refactor is the caller's, and `MUST KILL` is never applied even in fix mode.

## Clarity Rules

For `CLARITY` rewrites, follow ASD-STE100 Simplified Technical English:

- One idea per sentence. Under 20 words for instructions, 25 for descriptions.
- Active voice. Present tense to describe, imperative to instruct.
- One term per concept. No synonym cycling.
- Plain concrete vocabulary. No filler, no hedging.
- No nested subordinate clauses. Split them.

## Documentation Prose

The same bans apply, with three adjustments:

- Second person (`you`) is fine in user-facing docs. First person is not.
- No changelog narration in reference docs.
- Examples must be runnable and current. Flag any that drifted from the code in the target.

## Output

Per finding:

```
path/to/file.ts:42  [TAG]
> // the offending line, quoted
DELETE  (or) REWRITE → // the replacement  (or) MUST KILL → symbolName
one line: why it fails
```

Then one summary line: files touched, deletions, `MUST KILL` flags, rewrites, skips.

If the target's prose is clean, say so in one line. Do not manufacture findings.

## Fix Mode

With `--fix`, apply every reported finding. The resulting diff must contain **no code changes at all**.

- Delete means remove the whole comment, including its line and newline when it owns a line. A trailing comment leaves the code line intact with trailing whitespace stripped.
- Rewrite uses the replacement text exactly as reported, keeping the original indentation, comment syntax, and position.
- `MUST KILL` is never applied. It is a report-only flag.
- Preserve surrounding structure exactly: indentation, blank-line spacing, trailing newline, line endings.
- Never re-wrap, re-indent, or re-order code to close a gap a deletion left.
- After applying, diff the result. Every changed line must be a comment, docstring, or doc line. Revert any code line that appears.

## Never

- Add comments to raise coverage. Fewer, denser comments is the target.
- Keep a comment because deleting it feels lossy. Git has it.
- Rewrite a bad comment into a slightly better bad comment. Delete it.
- Reformat, reorder, or refactor code — in report mode or fix mode.
