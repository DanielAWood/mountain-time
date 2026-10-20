---
name: code-carve
description: "Single entry point for the structural pass: runs every code-quality review over one scope, collates them into one report, and keeps surface changes out. Behavior-preserving and report-only. Use for /code-carve, as the repeated code-quality round in a review loop, or when a change works but leaves the codebase worse."
argument-hint: "[commit|range|branch|PR#|path]"
disable-model-invocation: true
---

# Code Carve

Carve the form. This pass removes material: whole branches, modes, layers, wrappers, and concepts the change added or made load-bearing. It never changes behavior, and it never touches surface detail — comment wording and identifier names belong to `code-polish`, which runs after this pass has stopped producing findings.

Run this repeatedly. Each round is a fresh reading of a changed codebase, so findings genuinely converge; stop when a round produces nothing actionable, or when rounds start reversing each other.

Report findings only. Do not edit, stage, or commit — even where a roster skill says "push hard for" a restructuring. Whoever invoked the review decides what gets changed.

## Target

Scope comes from the invocation arguments or request (`$ARGUMENTS`):

- empty → uncommitted changes plus the current branch's diff vs its base
- a path → that file or directory tree
- a commit, range, branch, or PR number → that diff; for a single commit, compare against its first parent

Resolve the scope **once**, and give every reviewer the same scope plus the same base revision. Without a shared base a reviewer cannot tell what the change introduced from what was already there, and the findings stop lining up. Never hand a reviewer bare paths with no base revision.

## Roster

Read the first of these that exists:

- `<repo root>/.agents/code-carve-roster.md`
- `code-carve-roster.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

One entry per line, naming what to invoke:

```
- skill: code-structure-review
- skill: type-precision-review
- skill: test-review
- skill: comment-slayer --kill-only
```

`skill:` and `agent:` name something installed in the harness. `file:` is a path to an instruction file the reviewer reads and follows exactly — use it for a review that lives as a slash command, a prompt file, or anything the harness won't let a reviewer invoke directly. Trailing arguments pass through to the entry.

With no roster file, run those four defaults. Check each entry resolves; if one doesn't, say so and carry on with the rest — never silently substitute another.

Worth adding, where the project has one: a correctness and bug review. This pass is maintainability-only — it never asks whether the code is *right*.

`test-review` belongs in this pass, not in `code-polish`, because changing an assertion changes what the suite catches. That is a functional change to the tests, however cosmetic the edit looks.

`comment-slayer --kill-only` earns its place here for a reason that is easy to miss. It reports only `MUST KILL` and `SUPPRESS` — a comment that exists because the code is not self-evident is evidence of a structural defect, and a live lint suppression is hiding something real. The comment is the symptom; the code is the finding. Catching these here is also what makes `code-polish` safe later: deleting the comment is only correct once the code underneath no longer needs it.

## Run the reviews

Where the harness has subagents, launch every roster entry **concurrently in a single message**. Where it doesn't, run them in sequence. Either way each reviewer gets:

1. The exact scope and the resolved base revision.
2. Its own instruction file, and the instruction to follow that file exactly.
3. **Report-only framing: do not edit, stage, or commit** — even where its own instructions encourage restructuring.
4. Any findings a previous round already declined, as "already decided — do not re-raise without a materially new argument."
5. The project's documented vocabulary, where it has one — `UBIQUITOUS_LANGUAGE.md`, a glossary, or the terminology section of `CLAUDE.md`. These reviewers propose extracted helpers, modules, and types, and all of those need names that agree with the codebase.
6. A request to say plainly when it finds nothing.

## Collate

Present one report grouped by reviewer, preserving each finding's `path:line`, its verdict, the defect, and the remedy. Say plainly when a reviewer returned nothing.

Then reconcile across reviewers:

- **Same code, two findings** — report once, naming both angles. A loose type and a tangled branch on the same function are usually one remedy.
- **Contradictory remedies** — one reviewer wants an abstraction extracted where another wants a layer deleted. Present it as one decision with both arguments, and recommend one.
- **Findings that can only be fixed together** — say so, and present them as a single decision rather than two.

Rank the collated report: structural regressions, then missed simplifications, then spaghetti and branching growth, then boundary, ownership and type-precision problems, then file size, then legibility. Prefer a small number of high-conviction findings over a long list of nits.

Carry each reviewer's CONFIRMED / PLAUSIBLE verdict through to the report rather than flattening it — the two route differently. CONFIRMED findings carry a remedy ready to decide on. PLAUSIBLE ones do not, and go to **Design It Twice**.

## Design It Twice

A PLAUSIBLE finding is one whose defect is verified but whose remedy needs a design decision. Do not pass those on as a single proposal. The first design for an interface is rarely the best one, and a reviewer that found a defect has no special authority over how to fix it: it has one idea, generated once, under the influence of the code it had just been reading.

For each PLAUSIBLE finding worth acting on, generate alternatives before recommending anything:

1. **Frame the problem.** State the constraints any remedy must satisfy, what the affected code depends on, and a rough sketch that makes the constraints concrete. The sketch is not a proposal.
2. **Generate three or more designs, each from a different mandated stance**, so they diverge instead of converging on the first idea:
   - *minimise the interface* — fewest entry points, most leverage behind each
   - *maximise flexibility* — most use cases and extension points
   - *optimise the common caller* — make the default case trivial, even at the rare case's expense
   - where the remedy crosses a process or network boundary, a fourth designing around a port with injected adapters

   Where the harness has subagents, run these concurrently, giving each a brief with the file paths, the coupling, what sits behind the seam, and the project's own vocabulary so the designs name things consistently. Otherwise produce them in sequence, and do not let the second reuse the first's shape.
3. **Present each design**: its interface including invariants and error modes, a usage example, what it hides, and its trade-offs.
4. **Compare in prose** on depth (leverage at the interface), locality (where future change concentrates), and seam placement. Do not score them — a number here is false precision.
5. **Recommend one**, or a hybrid where elements combine, and say why.

Skip this for a CONFIRMED finding whose remedy is obvious and local. It is for the findings where the right shape is the actual question.

## Deferred

Some findings surface here but do not belong to this pass. List them separately, and name `code-polish` as their owner:

- A comment or doc that reads badly but sits on code that is structurally fine.
- A name that is merely unclear, where the abstraction behind it is sound.

A name that is wrong *because the abstraction is wrong* is not deferred — it is a structural finding, and the abstraction is the remedy.

## Approval Bar

Do not approve merely because behavior seems correct. The bar is:

- no clear structural regression
- no obvious missed opportunity to make the implementation dramatically simpler where such a path is visible
- no unjustified file-size explosion
- no obvious spaghetti growth from special-case branching
- no hacky or magical abstraction that makes the code harder to reason about
- no domain value travelling as a loose primitive where the project defines a precise type

## Do Not

- Do not edit, stage, or commit. Report only.
- Do not review the code yourself in place of the roster. Each reviewer exists because a narrow instruction set catches what a broad one skims past; folding their rubrics into one reading defeats the point.
- Do not apply surface changes. Comment wording and identifier names are `code-polish`'s, and making them here destroys the guarantee that this pass is behavior-preserving.
- Do not report pre-existing structure as a finding.
- Do not soften a major maintainability issue into a mild suggestion. Be direct and demanding without being rude. If the change makes the codebase messier, say so plainly.
