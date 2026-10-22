---
name: error-path-review
description: "Review the errors a change can produce: does each one tell the caller everything they need to fix the request in one go, and does a single-cause message hide a failure with several causes? Report-only. Use for /error-path-review, or as the error reviewer in a code-carve roster."
argument-hint: "[commit|range|branch|PR#|path — defaults to the current change]"
---

# Error Path Review

Two questions, asked of every error the change can produce:

1. **Does the error tell the caller everything they would need to fix the request in one go?**
2. **Does a single-cause message hide a failure with several causes?**

An error message is part of the interface, and for a failing caller it is the whole of it. An error naming one of five missing inputs is not a smaller error, it is a wrong one: it tells the caller their request is nearly right. They fix the named thing, retry, and get the same error about the next one. Five round trips to learn what one message could have said — and the message reads perfectly well in the one-item case, which is why nobody notices.

This review is narrow on purpose. It asks what the errors *say*, not whether the logic that produced them is correct.

## Target

Scope comes from `$ARGUMENTS`: a path, commit, range, branch, or PR number; empty means uncommitted changes plus the current branch's diff vs its base. For a single commit, compare against its first parent. Where a pass invoking this review hands over an explicit scope and base revision, that wins — it is what every other reviewer in the pass is reading. Run `git status --short` first and do not report problems already fixed in the worktree.

**Scope discipline.** Report only error paths the change added or made reachable. A pre-existing thin message elsewhere is out of scope however bad it looks, and a nearby finding does not pull it in. Where a pre-existing error genuinely blocks the new one from being complete, say so as a note, not a finding.

**A snapshot has no "the change".** Given a bare path, or a commit named as a state of the world rather than as a diff, there is no base revision and nothing for scope discipline to subtract — so neither scope discipline nor the Do Not against reporting a pre-existing error path applies. Review every error path in the named scope, and say in the report that you did, because the invoker asked about a state and not a delta. "The change introduced it" is unanswerable here, not false.

**That snapshot form reaches you only on direct invocation.** A `code-carve` dispatch always arrives as a diff with a base revision: that pass resolves a single commit against its first parent and never hands a reviewer a scope without a base. So if a pass dispatched you, you are on a diff scope whatever the argument looked like, and scope discipline is fully in force.

## Enumerate the Error Paths First

Judge the errors the scope can produce, not the ones you happened to read. List them before forming any finding.

1. Every `throw`, rejection, error return, and non-success response in scope — those the diff adds or makes reachable, or on a snapshot scope, all of them.
2. For each: the condition that produces it, the data in scope at that point, and what the caller actually receives — status, code, message, structured fields.
3. The project's error convention: an error class hierarchy, a problem-details shape, a code enum, a localisation table. A remedy proposing a shape the project does not have is noise.
4. What already reads each message — a test asserting on it, a client matching it, a log consumer parsing it. Those are the sites a richer error affects.

If the scope produces no errors, say so and stop — and say it as **vacuous, not unexamined**: "This review enumerated the scope and found no error paths, so there is nothing here for it to be right or wrong about." A markdown-only, config-only or stylesheet-only scope reaches this exit legitimately. State it in those words, because a collating pass has to tell *the question does not arise here* from *nobody asked it*, and acts on the two oppositely.

## Standards

1. **One error, every cause.** Where a condition can hold for several items, the error names all of them. The test to apply: *can two or more items fail this check in the same request?* If they can, a message naming one is incomplete — report it. The word "first" in a message, a doc comment, or a variable feeding a message is the strongest single signal this review has.

2. **A singular message is a claim about the data.** Singular phrasing asserts the failure has exactly one cause: "the missing input", a lone id field, a bare singular noun. Check that claim against the collection the message was derived from. Where the code reaches into a list to build it — `items[0]`, `.find(...)`, `[...xs][0]`, the head of a sorted array — the message is a summary of a set, and the set is what the caller needs.

3. **Everything needed to fix the request, in one response.** Ask what the caller must do next, and whether the error gave them it: which input, which entity, which constraint, which of several accepted values. Name the fields the complete error would carry and where they already sit in scope. Where the data is not reachable at the throw site, name the call that would fetch it, or say the error has to stay thin and why.

4. **A collapsed error hides which cause applied.** The converse defect: one message covering several distinct conditions, so the caller cannot tell a missing permission from a missing artefact from a malformed id. Each distinct cause the caller would act on differently needs to be distinguishable — by code, not by prose a client has to pattern-match.

   Where the project's error shape cannot carry a code at all, do not invent a taxonomy for it. Say what the error type would have to grow, and whether distinct prose is enough in the meantime — a note naming the pre-existing limit, not a finding against the change that ran into it.

5. **Completeness must not become leakage.** A richer error must not newly expose internals: stack frames, query text, internal identifiers, filesystem paths, or anything belonging to another tenant or user. Where the complete answer cannot be given to *this* caller, the remedy splits it — full detail to the log with a correlation id, and a stable code plus a safe count or category to the caller. Say which half goes where.

6. **An untested error contract is not the finding; an incomplete one is.** Whether a message is pinned by a test belongs to `test-review`. If the remedy here needs a test to hold, name that as a consequence of the remedy, not as a separate finding — and never let "the behavior is untested, so nobody depends on it" argue for leaving a thin message alone. It argues the opposite.

## Review Questions

- For each error the change can produce: what does the caller do next, and did the error tell them enough to do it once?
- Can the condition behind this error hold for more than one item at a time? What does the message say when it does?
- Does any message name "the first" of something, or read as singular over data that is plural?
- Is the message built by indexing or searching into a collection? Why that element and not the whole set?
- Do two conditions a caller would handle differently produce the same error?
- Would the complete error expose anything this caller should not see?
- Is there a structured field — a code, a list of ids, a count — that the client could act on instead of parsing prose?

## Verify Before Reporting

Four numbered **items** below. Throughout this section "item" means one of these four and "standard" means one of the six above. The characteristic failure of this review is a confident rewrite of a message that was already right for the only input that reaches it.

Every finding is confirmed against items 1, 3 and 4. **Item 2 applies only to a finding under standard 1 or 2.**

1. **The path exists and is in scope.** The change added it or made it reachable; on a snapshot scope, it is in the named scope.
2. **The multi-cause case is real — for a finding under standard 1 or 2 only.** Name a concrete input where **two or more items satisfy the condition at once**, which is standard 1's own test and the same bar `test-review` applies when it hands a doubt over. Without such an input the finding is speculation.

   Read "items", not "causes". Five documents each missing an artefact is **one condition over five items**, and that is the canonical case this review exists to catch — reading the bar as "two distinct conditions" rejects it, and a standard 1 finding that fails this item is dropped silently, so the misreading is unrecoverable. Several *distinct* conditions sharing one message is standard 4, a different defect with a different bar.

   A finding under standard 3, 4 or 5 cannot name such an input and is not asked to; applying this item to them would delete them.

   An input the change's own types admit counts, even with no producer in the repo that emits it yet. Where that is the only input you can name, say so plainly and mark the finding **PLAUSIBLE (unreached)** — the open question is whether a producer can emit it, which is a question for whoever owns the producer, not a design question about the payload. Do not drop it for want of a caller.
3. **The data is reachable.** Every field the proposed error carries is in scope at the throw site, or you name the call that fetches it and what that costs.
4. **The blast radius is named.** Where the remedy changes the error payload, list what reads the old one — tests asserting on the message, clients matching it, log parsers, localisation entries — and say what each needs. Where it does not change what any caller observes (a standard 5 remedy that moves detail to the log), say that instead.

Mark each surviving finding:

- **CONFIRMED** — every applicable item holds.
- **PLAUSIBLE** — the error is verifiably incomplete, but the right payload needs a design decision. Also the verdict for a finding you could not establish on **item 3 or item 4**: the defect is real, and the unestablished item is the open question — the data you could not confirm is reachable, or the readers of the old payload you could not enumerate.
- **PLAUSIBLE (unreached)** — item 2's case: the input is one the types admit but no known producer emits.

Say what the open question is for every PLAUSIBLE form. Every finding carries a verdict: the collating pass routes by verdict, and a verdictless finding has nowhere to go.

Drop a finding silently only when it fails **item 1**, or when it is a standard 1 or 2 finding that fails **item 2**. Nothing else is dropped silently: a finding you cannot confirm on item 3 or item 4 is reported with what you could not establish, because a finding you cannot fully evidence is still the only record that anyone looked.

## Most of These Remedies Change Behavior

A completer error changes what a caller receives. Where a remedy does that, label the finding **`behavior-affecting`** and state in the remedy what a client would observe differently, so whoever collates the report can route it.

Every finding carries one of the two labels; which one is a judgement, not a default. A standard 5 remedy that moves detail to the log and leaves the caller's payload alone changes nothing a caller sees; label it `caller-visible: none`. Deciding which applies is this review's job, not the collator's.

That is a reason to be precise about the blast radius, not a reason to soften a finding.

## Project Overlay

Projects define their own error shapes, codes, and rules about what a caller may see. Read the first that exists and treat its rules as additional numbered standards at full strength:

- `<repo root>/.agents/error-path-review-overlay.md` — shared with everyone working on the repo
- `error-path-review-overlay.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

An overlay is where the error base class gets named, the code enum gets listed, the status-code convention gets stated, and the project's rules on what detail reaches an external caller get spelled out. Overlays live outside the skill directory because skill updates replace that directory wholesale. If none exists, review with the standards above and do not mention the overlay.

## Output

```
path/to/file.ts:42  standard <n>  [CONFIRMED|PLAUSIBLE|PLAUSIBLE (unreached)]
                                 [behavior-affecting|caller-visible: none]
the error, quoted, and the condition that produces it
why it's wrong → for standard 1 or 2: the input where several causes hold, and what the
                 caller can't learn from it
                 for standard 3: what the caller must do next that the error didn't tell them
                 for standard 4: the distinct conditions sharing this message, and the two
                 callers who would act differently
                 for standard 5: what the complete answer would expose, and to whom
remedy → the payload that answers in one go, or the log/caller split
reads the old one → the tests, clients, log parsers and localisation entries affected
open question → either PLAUSIBLE form: what has to be decided, and by whom
```

Name the standard in every finding. The fields differ by standard.

Then a one-line tally: findings by verdict, how many error paths you enumerated and how many of those carry no finding, plus any out-of-scope notes.

If every error in scope answers both questions, say so in one line and name the paths you checked. Do not manufacture findings.

## Do Not

- Do not edit, stage, or commit. Report only.
- Do not report a pre-existing error path as a finding, on a diff scope. On a snapshot scope there is no such thing, and every path in scope is reportable — see **Target**.
- Do not propose a message carrying data the throw site cannot reach.
- Do not review wording for its own sake. An error that reads awkwardly but says everything is `prose-review`'s subject, not a finding here.
- Do not invent an error taxonomy the project has not adopted.
- Do not widen into whether the surrounding logic is correct. This review is about what the errors say.
