---
name: code-carve
description: "Single entry point for the structural pass: runs every code-quality review over one scope, collates them into one report, and keeps surface changes out. Report-only; remedies behavior-preserving except where labelled. Use for /code-carve, as the repeated code-quality round in a review loop, or when a change works but leaves the codebase worse."
argument-hint: "[commit|range|branch|PR#|path]"
---

# Code Carve

Carve the form. This pass removes material: whole branches, modes, layers, wrappers, and concepts the change added or made load-bearing. It changes nothing itself, and it never touches surface detail — comment wording and identifier names belong to `code-polish`, which runs after this pass has stopped producing findings.

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
- skill: error-path-review
- skill: comment-slayer --kill-only
```

`skill:` and `agent:` name something installed in the harness, and are the normal form — the defaults above are all installed skills a dispatched reviewer can invoke by name. `file:` is a path to an instruction file the reviewer reads and follows exactly; reach for it only where an entry genuinely cannot be invoked that way — a review that exists solely as a prompt file, or one the harness withholds from a subagent. Trailing arguments pass through to the entry.

With no roster file, run those five defaults. Check each entry resolves; if one doesn't, say so and carry on with the rest — never silently substitute another.

**A roster file replaces the defaults; it does not extend them.** The first file that exists is the whole roster, so a project or personal roster written before a default was added silently drops it, and the pass goes on looking complete. Before running, diff the resolved roster against the five defaults above and **name every default it omits** — say which question therefore goes unasked this round, and that adding a line to the resolved roster file is what fixes it.

Worth adding, where the project has one: a correctness and bug review. This pass does not ask whether the code computes the right answer.

`error-path-review` is among the defaults because the two questions nobody else here asks are what a failure *tells the caller*, and whether one message is hiding several distinct causes.

Its remedies are the exception to this pass's behavior-preserving framing: they change the error payload. **A remedy that changes what a caller observes carries a `behavior-affecting` label**, whichever reviewer proposed it and whether it came from a reviewer or out of Design It Twice — a structural remedy that happens to enrich an error message is labelled on the same terms. The label is the exception, not a field on every finding: an unlabelled finding is read as behavior-preserving. Keep any label in the report, and separate the behavior-preserving part of a remedy from the part that is not, so the invoker can take one without the other. The pass stays report-only either way; the invoker decides.

`error-path-review` is the one roster entry where the label is the common case rather than the exception, so it also emits `caller-visible: none` to mark a remedy that changes nothing a caller sees. Do not expect that marker from any other reviewer.

It is also the entry that verifies least. The other reviewers each own a tool their standards push them toward — `test-review` runs the suite, `type-precision-review` compiles its proposed constructs, `comment-slayer` runs the linter, `code-structure-review` measures file size — and nothing in "what does this failure tell the caller" reaches for any of them, so its findings tend to arrive argued rather than demonstrated. **Ask it for the failure, not a reading of the code**: the input that produces the error, the message a caller actually receives, and for a message standing in for several causes, the two inputs that produce the same text. An error path is cheap to execute, and a claim about what a caller sees is settled by seeing it. Where it could not run the path, it should say so and the finding stays PLAUSIBLE.

`test-review` belongs in this pass, not in `code-polish`, because changing an assertion changes what the suite catches. That is a functional change to the tests, however cosmetic the edit looks.

`comment-slayer --kill-only` earns its place here for a reason that is easy to miss. It reports only `MUST KILL` and `SUPPRESS` — a comment that exists because the code is not self-evident is evidence of a structural defect, and a live lint suppression is hiding something real. The comment is the symptom; the code is the finding. Catching these here is also what makes `code-polish` safe later: deleting the comment is only correct once the code underneath no longer needs it.

## Run the reviews

Where the harness has subagents, launch every roster entry **concurrently in a single message**. Where it doesn't, run them in sequence. **Every reviewer gets the whole scope** — fan out across the rubric, never across the diff. A reviewer handed a subset of the files reads its one special case as local and defensible and reports nothing, and the findings this pass ranks highest are properties of the change as a unit: a rule stated across three modules, a contract a producer and a consumer disagree about, a feature that should have been an extension of something already there. None of those is visible from any one file.

Each reviewer gets:

1. The exact scope and the resolved base revision.
2. Its own instruction file, and the instruction to follow that file exactly. Where the **Roster** notes above name something a particular entry must do, that goes in that entry's brief — a requirement left in the roster commentary is read when resolving the roster and never reaches the reviewer it was written for.
3. **Report-only framing: do not edit, stage, or commit** — even where its own instructions encourage restructuring. Scratch files outside the repo are fine, and some reviewers need them: a reviewer proposing a narrowing construct is expected to compile it rather than assert that it compiles.
4. Any findings a previous round already declined, as "already decided — do not re-raise without a materially new argument." Pass each one as its own claim, carrying four things: the `path:line` it was about, what it asserted, what was decided (rejected or modified), and the one-line reason. The reason is the part that tells a reviewer what a materially new argument would have to beat; without it the entry only says "don't mention this", which is how a decision becomes a no-go area. Never hand over a function, file, module or area as settled: a reviewer given an area reads everything inside it as out of bounds, sees a real defect there, and talks itself out of writing it down. If what you hold cannot be stated as a claim about a line, it is not a decision you can pass on.
5. The project's documented vocabulary, where it has one — `UBIQUITOUS_LANGUAGE.md`, a glossary, or the terminology section of `CLAUDE.md`. These reviewers propose extracted helpers, modules, and types, and all of those need names that agree with the codebase. Where nothing is documented, hand over the exported names of the modules in scope and say that is all there is.
6. A request to say plainly when it finds nothing.
7. A request to list what it **considered and deliberately left alone**, each with the justification it left it on. These are not findings and do not go in the report as findings, but the collate step needs them.
8. The project's type-check and lint commands, **with the flags the project actually runs**. A reviewer compiling a proposed construct in a scratch file gets no `tsconfig`, and the flags decide the answer: a guard that looks dead under `--strict` alone is load-bearing under `--noUncheckedIndexedAccess`, so a reviewer without the flags proposes a remedy that crashes. If the project has no such command, say so.
9. One sentence covering everything it hands back beyond findings: **if a remedy changes what a caller observes, label it `behavior-affecting` and say what a caller sees differently; if you are handing a doubt to another reviewer, say which reviewer and give the evidence.** An unlabelled finding is read as behavior-preserving, so silence here is a claim.
10. A request to say, for each finding, **whether the defect is at the one site named or at every site stating the same rule** — and where it is the latter, to name all of them. A reviewer that finds a guard missing from one call site has usually found how the guard was propagated, and that is a different finding with a different remedy. Reviewers are generally willing to look once asked; unasked, they report the site they were reading.

## Collate

Present one report grouped by reviewer, preserving each finding's `path:line`, its verdict, any label it carries, the standard or axis it was filed under where its reviewer names one, the defect, and the remedy. Dropping the standard misfiles the defect, since several reviewers key their fields to it. Say plainly when a reviewer returned nothing.

Reconcile **by locus first, claim second.** Group every finding by the line or small block it is about, before reading what any of them assert. Taken in the other order — matching findings that say the same thing — reconciliation catches duplicates and misses the case it exists for: two reviewers making *different* claims about one line, which look like two findings right up until someone writes the remedy and finds there is only one. Each reviewer holds a fragment of the rubric, so a defect spanning two axes arrives as two partial sightings by construction; if you only merge same-claim pairs, every genuinely cross-axis defect in the scope gets filed twice and remediated once.

Then, within each locus group and across them:

- **Same code, two findings** — report once, naming both angles. A loose type and a tangled branch on the same function are usually one remedy. This holds whether the two findings agree or not: two reviewers asserting different defects on one line is still one decision, because whoever fixes it touches that line once.
- **Contradictory remedies** — one reviewer wants an abstraction extracted where another wants a layer deleted. Present it as one decision with both arguments, and recommend one. Where the right answer is neither, say so and recommend the third option; a reviewer holding one axis cannot see the remedy that satisfies both, and taking both in sequence is not the same as taking the one that was needed.
- **Findings that can only be fixed together** — say so, and present them as a single decision rather than two. **A reviewer's own sequencing note is this signal, and it is binding**: "fix together with finding 2", "sequenced with", "reshapes the same call sites" means the coupling has already been found, and filing the two separately after reading it is the failure this rule exists to stop. Never carry a sequencing note into the report beside two separate decisions.
- **A finding naming several sites** — one reviewer reporting that a rule holds at four of five call sites is describing one defect, not four. Report it as one finding whose remedy is the sweep, and say how many sites. Filing the sites separately invites a remedy that fixes the one that got reported.
- **A handoff note from one reviewer to another** — a reviewer's doubt about whether the behavior under test or under review is *right*, which its own standards cannot settle. Carry it into the report as an **open question**, with its `path:line`, its addressee and the evidence the sender gave. It has no verdict, so it will not route itself; a note left in a reviewer's own section is a note nobody reads. Where the addressee is not on the resolved roster, say so and list the question as **unanswered**, naming the roster entry that would answer it.

Then read the **considered and left alone** lists, and re-raise the waivers that defer to the type-checker.

A waiver belongs in this category when **its justification's subject is the type-checker rather than an input that reaches the check.** Match on that, not on a list of phrases — phrasing varies and any list goes stale. `type-precision-review`'s standard 11 states the same category for the producing side and carries the phrase examples; they live in that one file so the two sides cannot drift apart.

Such a waiver does not get dropped. Promote it to a **PLAUSIBLE** finding and send it to **Design It Twice**; the open question is which construct carries the knowledge instead. The reviewer saw the defect and declined on the strength of the one remedy it had already rejected, which is precisely the case Design It Twice exists for. Say in the report that the finding came from a waiver, and quote the justification — that is the evidence the defect is real.

Re-raise on the same terms a waiver justified by *an earlier round settled this function* or any other appeal to scope rather than to the code. A decision about one finding is never a decision about everything near it.

**Test the claim where the project's own tools can settle it.** A waiver deferring to the compiler makes a factual assertion, and a compile is the cheapest decisive evidence this pass can get: write the alternative construct to a scratch file outside the repo and run the project's own type-checker with the flags the project actually runs. Checking one reviewer's stated reason is not reviewing in its place — do not run its rubric.

**Where you cannot run the tools, re-raise it anyway, untested.** A compiler claim nobody was able to check is still a compiler claim, and a harness with no type-checker is a fact about the harness, not evidence about the code. Say the claim is untested and carry it to Design It Twice as PLAUSIBLE.

What is *not* re-raised is a waiver that asserts no checkable claim at all — *this is fine, I looked*, *it reads clearly to me*. List those, one line each, with three of the four fields a decided finding carries: the `path:line`, what was considered (in place of what it asserted), and the one-line reason. A one-liner naming only an area — "considered the export narrowing and left it" — is the same defect this pass is here to stop, committed by the report rather than by a reviewer.

Rank the collated report: structural regressions, then missed simplifications, then spaghetti and branching growth, then boundary, ownership and type-precision problems, then file size, then legibility. Rank a merged finding by its highest band and name the others it spans. Prefer a small number of high-conviction findings over a long list of nits.

Carry each reviewer's verdict through to the report rather than flattening it — they route differently. CONFIRMED findings carry a remedy ready to decide on. PLAUSIBLE ones do not, and go to **Design It Twice**.

A reviewer may qualify a PLAUSIBLE verdict to say its open question is not a design question — `PLAUSIBLE (unreached)`, where the defect is real for an input the types admit but no producer is known to emit. Do not send those to Design It Twice: no amount of interface design answers "does a producer exist". Route them to whoever owns the producer as a question with the input attached. Generating three designs for a case that may never occur is how a pass spends its credibility.

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
- no check kept only so the compiler narrows, and no branch retained that no input reaches
- no error that leaves the caller to discover its remaining causes one request at a time
- no single message standing in for several distinct causes a caller would act on differently

No bar item is ever cleared by silence. Where this run did not clear one outright, report it as one of two things, because an invoker acts on them oppositely:

- **unexamined (live)** — the scope contains work the item is about, and no reviewer in this run examined it. The bar is not cleared. Name the item and the roster entry that would cover it. Where several items are uncovered they may need different entries, and some may have no installed entry at all; list each with its own.
- **vacuous** — the scope contains nothing the item is about, and a reviewer that ran said so. A markdown-only diff has no error paths and no narrowing; the question does not arise, so the item **is** cleared, vacuously. Say that and move on. Do not send the invoker to install a reviewer and re-run a pass that cannot produce anything.

## Do Not

- Do not edit, stage, or commit. Report only.
- Do not review the code yourself in place of the roster. Each reviewer exists because a narrow instruction set catches what a broad one skims past; folding their rubrics into one reading defeats the point.
- Do not apply surface changes. Comment wording and identifier names are `code-polish`'s, and making them here destroys the guarantee that this pass changes nothing.
- Do not report pre-existing structure as a finding.
- Do not drop a reviewer's waiver because the reviewer sounded confident. A waiver citing the type-checker, or an earlier round's scope, is a finding this pass is specifically here to catch.
- Do not soften a major maintainability issue into a mild suggestion. Be direct and demanding without being rude. If the change makes the codebase messier, say so plainly.
