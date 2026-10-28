---
name: session-retro
description: "Retrospective on how a shepherded session ran, not on the code it produced. Reads the session ledger for thrash, rejection and modification patterns, escalation rate, per-round reviewer yield, round count and stop reason, how much of each round came from the previous round's remediation, and the questions the session had to ask, and reports at most seven ranked retro findings — each naming what it cost and the one artifact to change, proposed as an issue. Cites counts, round numbers and decision ids only, never raw text. Use when task-shepherd asks for the session retro, after verification and before the tracker step."
argument-hint: "<session dir holding session.json> --worktree <path>"
---

# Session Retro

The code has been reviewed round after round. Nobody reviewed the session.

A shepherded session leaves a record of its own conduct: how many rounds it took, what the reviewers kept finding, what the user kept rejecting, where the shepherd had to stop and ask. That record is evidence about the *process* — the missing guardrail that let a bug reach review, the standard stated as prose that a linter should have enforced, the question that got asked because nothing was written down. The code reviewers cannot see any of it; each of them saw one scope, once.

You review the session. Not the diff, not the code, not whether a finding was decided correctly.

## Target

`$ARGUMENTS` names the task-shepherd session directory. `session.json` inside it is the ledger and your only evidence source: the unit of work, the config, every question and answer, every round with its findings, decisions, deciders and reasons, and the stop reason. Read it whole before forming any finding.

`--worktree <path>` is required, and task-shepherd passes it: the Impl agent's worktree, still present because you run before it is cleaned up. Use it to **run the artifact check on any path you name** — open the file, or establish that it is not there — and to read the file you are proposing to change; a finding naming a path you did not check is a finding against nothing. The worktree and the ledger are the whole of your access. You do not edit anything, anywhere.

task-shepherd invokes this skill; it is not a standalone entry point. If `--worktree` does not arrive, or the path it names is not a readable directory, stop and say so rather than running: a retro whose artifact checks were all unperformed is worse than no retro.

The ledger is the whole of the evidence for any claim *about the session*: if a claim cannot be grounded in the record, you cannot make it. Nothing you read in the worktree is evidence about the session, and **Never Quote** binds everything you saw there. There is no transcript mining here.

## Never Quote

Findings cite the **shape** of their evidence: round numbers, counts, rates, decision ids, file paths, skill names. Never the text behind them.

This inverts the record's usual rule, which stores findings and answers verbatim on purpose, and the rendered report shows that text by design. The rule binds your fields, not the record at large: they are the ones you compose from material outside the record, and the report is a file the user is told to `scp` between machines. It is absolute rather than a judgement about any particular string.

So: "rounds 2, 4 and 5 each raised a finding at `src/parse.ts:118`, two accepted" is evidence. The findings' own words are not. Paraphrase the *kind* of thing at issue in your own words — "a null-check convention", "an import-ordering rule" — and never reproduce a finding's text, an answer's text, a tool's output or a file's contents, in any field.

## Read The Ledger For These Signals

Compute all of them before writing anything. They are what you have; a finding that does not rest on at least one of them is a guess.

1. **Thrash.** A round reversing or re-raising an earlier decision. `reraiseOf` is set where the shepherd spotted it, but it undercounts: also look for two findings naming the same `path:line`, a round changing X→Y after an earlier one settled Y, and a rejected finding reappearing. Thrash is the signal that something in the session had no written answer, so each fresh reviewer re-derived its own.
2. **What got rejected.** Group the `rejected` findings by what they were about. A kind of finding rejected three times is a standard this repo has decided against and not written down; every future reviewer will spend a round discovering it again.
3. **What got modified.** `modified` means the reviewer was onto something and wrong about the fix. A recurring shape of modification says where the reviewers' model of this repo is off.
4. **Escalation rate.** `escalated` findings over total, and in unsupervised mode which of the escalation triggers fired. A high rate is not a fault — it says the session kept hitting decisions nothing written down could settle, and names them.
5. **Per-round reviewer yield.** For each round: findings raised, and how many were accepted or modified. A round with many findings and no accepted ones cost a full cycle and bought nothing; a late round with accepted findings says the earlier rounds were looking in the wrong place. Exclude any round with `cancelled: true` from the per-round comparison and say you did — its count is whatever had arrived before the stop, not what the round would have produced. A round carrying a `scopeNote` was scoped differently too; read it before comparing.
6. **Round count and stop reason.** `stopReason` of `thrash` or `cap` is itself a finding waiting to be written: the rounds stopped because the loop was not converging, and the record says what it was circling. `disproportionate` and `user-requested` say the rounds were stopped from outside rather than running out — for those, the finding is usually about what the session spent the last two rounds on, and whether anything in the shepherd's own rules would have stopped it unprompted.
7. **Remedy-caused findings.** For each round after the first, how many of its findings concern code the previous round's remediation wrote or half-applied. `defectScope` is the direct evidence: a run of `class-declined` entries, or `class` entries whose `sweptSites` kept growing round over round, says one rule was being chased site by site. This is the normal shape of a multi-round session, so the finding is not that it happened — it is a rule stated in enough places to need the sweep, or a remedy repeatedly written wider than approved.
8. **Questions asked.** `questions`, each with who answered it. A question the shepherd answered from the repo's own docs is a doc that was hard to find; a question that went to the user and was answered in one line is a decision nobody had recorded. This signal is the reason the gates count a question round-trip as a cost and a question not asked as a remedy effect.

## Three Gates

Every finding passes all three. They exist because the default failure of this review is a page of advice that would read identically for any session.

1. **A specific thing that happened, and what it cost.** Name the rounds, counts or ids, and the cost in the session's own currency: rounds spent, remediation turns, a question round-trip, a bug that reached review. "Round 3 and round 5 both raised the same null-check convention; both were rejected, costing two reviewer rounds" passes. "Reviews could be more focused" does not, and neither does a cost you cannot point at in the record.
2. **A named artifact, and the check you ran on it.** One file, by path, and the result of looking for it: you opened it in the worktree, or you looked there and it is not present, or it is inside a skill this run cannot read (see **Category And Target**). "Improve the docs" is unreportable, and so is a path you did not check — the two are indistinguishable to whoever reads the finding, which is the whole reason the check gets stated rather than assumed. `.agents/code-carve-roster.md`, `CLAUDE.md`, `eslint.config.js` are reportable.

   Where the artifact does not exist, say so and name the path it would be created at. Where it is inside a skill this run cannot read, say that instead — the check result is that you could not open it.
3. **Seven, ranked.** A hard cap. Rank by cost of recurrence — what will cost the most the next time a session runs in this repo — and if you have eight, the eighth is cut. The cap is the point: it forces you to choose. Fewer is fine, and **zero is a legitimate result**. A session that ran clean in two rounds with nothing rejected has no retro findings, and filler written to fill the section is worse than an empty one.

A finding also has to be actionable by whoever picks up the issue: a change they could make to the artifact you named. A finding whose remedy is "be more careful" fails gate 2 in disguise.

## Category And Target

Each finding carries a free-form kebab-case `category` slug and a `proposedCategory` flag. Nothing consumes them yet; they are recorded so that once several sessions have run, recurring slugs can be found and promoted into a named list.

- The slug names the **kind of problem**, not what it targets and not where the evidence came from. The signal is the evidence; the slug is the problem. A slug that restates the target cannot be compared with the same finding in another repo.
- `process` is the one established slug, and the default when the problem *is* the process: the rounds, the decisions, the escalations, the ledger. Set `proposedCategory: false`.
- A finding whose evidence is a process signal but whose problem lies elsewhere — a missing guardrail, a steering file nothing reads, a convention no check enforces — coins its own slug.
- A slug you coin yourself sets `proposedCategory: true`. Coin one only when `process` is genuinely wrong for the finding, and keep it to a noun phrase of two or three words: `missing-automated-check`, `steering-file-noop`. The flag is true exactly when the slug is not `process`.

`target` names the artifact and whatever owns it. Which **key** you set says which kind of owner that is — set one or the other, never both:

- `{ "repo": "<the record's repo>", "artifact": "<path>" }` — the artifact is in the work repo, or would be created there: a missing guardrail, a convention nobody wrote down, a check that would have caught a review finding, or a skill whose source lives in this repo. Copy `repo` from the record verbatim, so the two are comparable.
- `{ "skill": "<name>", "artifact": "<path inside the skill>" }` — the finding is about a skill that is not in the work repo: the ledger, the rounds, the review roster, a skill's own instructions. `artifact` is the path within that skill, such as `SKILL.md`. You normally cannot open it: a skill you are reporting on sits outside the worktree.

`skill` is a skill's name, not a repo, which is why it is a different key rather than a different kind of string in the same one. Do not try to resolve which repo owns a skill: that depends on how the skill was installed, which is not visible from here. The shepherd resolves it at the tracker step, branching on which key it finds.

A config or steering file gets named at its **project-scoped** path — `.agents/code-carve-roster.md`, `.agents/task-shepherd-config.md`, `CLAUDE.md` — which is in the work repo, is checkable, and is where a convention that cost *this* repo rounds belongs. The same file in a home directory would silently change every other project the user shepherds, so it is a different artifact and not this finding's target.

`proposedAction` is `issue`, always: a retro finding is filed on the target's tracker, never applied as an edit. Writing the change is someone else's decision, taken with the issue in front of them.

## Verify Before Reporting

For each candidate, in order:

1. **The claim is in the record.** Re-read the entries you are citing and check the counts. A miscounted rate is a wrong finding, not a rough one.
2. **The artifact check is stated**, with its result.
3. **The remedy would have changed this session.** State what would have gone differently had the artifact already said what you propose — a round not run, a finding not raised, a question not asked. If you cannot name that, the finding is an opinion about good practice and goes no further.
4. **No raw text survived** into any field. Check every field of every finding against **Never Quote** before you emit it. This is the last point at which the fields *you* author can be caught. One field is written later and elsewhere: the shepherd fills in each finding's `reason` when it is decided, and the same rule binds it there.

## Output

A ranked table first. Name the owner beside the artifact, since the same path — `SKILL.md` most of all — belongs to several of them:

```
| # | Finding (short) | Category | Target |
|---|---|---|---|
```

Then the same findings as a JSON array, in the same rank order. This is the copy that reaches the session record, so the full text of `finding`, `evidence` and `cost` goes here and nowhere else — the table carries `short` and the routing columns. It mirrors the record's `retro.findings` with the decision fields omitted, since the shepherd fills those in once they are decided:

```json
[
  { "id": "retro.1", "category": "process", "proposedCategory": false,
    "short": "", "finding": "", "evidence": "", "cost": "",
    "target": { "repo": "", "artifact": "" }, "proposedAction": "issue" },
  { "id": "retro.2", "category": "process", "proposedCategory": false,
    "short": "", "finding": "", "evidence": "", "cost": "",
    "target": { "skill": "", "artifact": "" }, "proposedAction": "issue" }
]
```

`evidence` carries round numbers, counts, ids and paths; `cost` carries what this session paid, in rounds, turns, questions or bugs.

Close by accounting for **every signal, by name** — all of the ones listed above, not only the ones that produced a finding: for each, whether it yielded a finding, was computed and came back clean, or could not be computed from this record. Then findings reported and how many candidates the gates cut. An agent that names them all and shows four clean has said something; one that lists the two it got round to has said nothing, and the account is the only trace that the sweep was complete.

## Do Not

- Do not edit, stage, or commit anything, in any repo. Report only.
- Do not quote. No finding text, answer text, tool output or file contents, in any field — see **Never Quote**.
- Do not review the code. A bug in the diff is not your subject even if you see one; the rounds had reviewers for that, and a finding about the code is a finding the gates cannot cost.
- Do not re-decide a finding. Whether round 3's rejection was correct is the user's call, already made. That it was the third rejection of the same kind is your subject.
- Do not report generic practice. If the finding would read the same for a session in another repo, it fails gate 1.
- Do not exceed seven, and do not pad to reach it.
- Do not infer from anything outside the record. No transcripts, no session logs, no recollection of how the session felt. The worktree is the one exception and **Target** states its limits.
