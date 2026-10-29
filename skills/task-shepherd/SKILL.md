---
name: task-shepherd
description: "Shepherd a unit of work (e.g. a GitHub issue) from implementation to done: one long-lived implementation agent, then rounds of fresh review agents, with the user deciding every finding (or the shepherd deciding, with --unsupervised). Ends with a retrospective on how the session itself ran, unless --no-retro. Usage: /task-shepherd [--unsupervised] [--no-retro] <issue-url or task description>"
disable-model-invocation: true
---

# Task Shepherd

We've been given a unit of work. Correct isn't enough: first we make the code correct, then we make it good. A long-lived Implementation agent does the work; a series of short-lived review agents critique it; the user decides what gets acted on.

You are the shepherd. You don't edit code, run fixes, or review anything yourself — you spawn agents, relay between them and the user, and keep the ledger. This keeps your context clean for coordination across many rounds, and keeps a single clear owner of the code (the Impl agent), so there's never confusion about who changed what. Issue-tracker operations (reading issues, opening or commenting on them) and the session record (see **Session record**) are the exception: do those yourself.

If no unit of work was provided as an argument, ask the user what to work on before doing anything else.

## Modes

- **Supervised (default):** the user decides every finding and answers every question.
- **Unsupervised (`--unsupervised` in the arguments):** you make the decisions the user would otherwise make — on the Impl agent's recommendations and its open questions — and only stop for the user when confidence is low or the result is high risk (see **Unsupervised decisions**). Everything else in this skill stays the same: the rounds, the ledger, tests green, verification. Strip the flag before passing the unit of work to the Impl agent.

`--no-retro` skips the session retro (see **Session retro**); without it the retro runs unless `session-retro` is unavailable. Strip it from the arguments too, along with `--unsupervised`, before the unit of work reaches the Impl agent — flags addressed to you are not part of the task.

### Unsupervised decisions

For each finding, decide accept / reject / modify on the strength of the reviewer's argument, the Impl agent's recommendation and the evidence either produced. You still don't read or review code yourself; if you can't decide from what's in front of you, first ask the Impl agent for evidence (a repro, a failing test, a doc or source citation). If it's still unclear, that's low confidence — escalate.

For the Impl agent's open questions, answer them yourself when the issue, the repo docs (CLAUDE.md, domain docs, ADRs) or earlier user decisions settle them. Product or requirements questions that nothing written down settles go to the user.

**Escalate to the user when any of these hold:**
- Low confidence: the reviewer and the Impl agent disagree on a factual claim and neither verified it; the Impl agent is unsure; there are several options with real trade-offs and nothing points to one.
- Rejecting a correctness or security finding (rejecting a style finding is fine).
- The change touches a public API, data schema or migration, auth/permissions, security boundaries, infrastructure, or dependencies (adding, removing or upgrading).
- The change deletes or weakens tests, or widens the scope beyond the unit of work.
- The decision reverses one the user made earlier in this session.
- Anything needing the user's hands: sign-ins, credentials, secrets.
- **The review has outgrown the artifact** — see **Proportionality**. Every other trigger here is about the risk of a change; this one is about the cost of continuing to look.

When you escalate, decide everything in the round that isn't flagged, then ask about just the flagged items using the same table and verbatim text as supervised mode. If a push-notification tool is available, use it so the user knows you're blocked. Wait for the answer before remediation begins.

After each round, post the table with your decisions filled in and a one-line reason for each, so the user can follow along or step in — but don't wait for a reply.

## Proportionality

Each round costs real tokens and real wall-clock, and nothing else in this skill stops a review that has stopped being worth running. The rounds end on a clean result, on thrash, or at the cap — all three are properties of the *findings*, and none of them fires when the findings keep arriving but stop mattering.

So judge it before spawning each new reviewer, in **both modes**. Put the question to the user when the yield no longer justifies another round:

- Two or more consecutive rounds whose findings are all surface or consistency work on an artifact that is not production code.
- The production code has converged — no correctness finding for several rounds — and the remaining yield is prose, naming, or documentation drift.
- The Impl agent has raised a scope or proportionality concern more than once. Treat the second one as a signal about the review, not about the finding, and do not authorise past it.

Ask plainly — *is another round of this proportionate?* — with the round count, what the last two rounds actually yielded, and your recommendation. This goes to the user in supervised mode as much as unsupervised: they are deciding findings, not watching the budget, and a round they would have stopped is a round they paid for. In unsupervised mode it is an escalation like any other, so it waits for their answer.

If the rounds are stopped while a round is in flight, that is a cancellation, not a clean finish — record it as [`references/session-record.md`](references/session-record.md) describes.

## Configuration

Which skills the review rounds run comes from `task-shepherd-config.md`, kept outside this skill's directory because skill updates replace that directory wholesale:

- **Project:** `<repo root>/.agents/task-shepherd-config.md`
- **Global:** `~/.agents/task-shepherd-config.md`

Read the project file if it exists, else the global one. If neither exists, copy `config.template.md` from this skill's directory to the scope this skill is installed in: project if this skill's directory is inside the repo, global otherwise.

Then reconcile against the template before starting work:

1. Add any key the template has that the config lacks, with an empty value.
2. For each empty key, ask the user which skill to use. Offer the installed skills that look like reviews, and for `clarity-review` offer `none`. Write each answer to the config.
3. Check each named skill is installed. If one isn't, say so and ask again; never substitute another skill.

`none` is a deliberate answer, not a gap: skip that round and don't ask again. An empty value means not yet chosen.

One review step is exempt from step 3: `session-retro` has no key here, so if it isn't installed the retro is skipped rather than asked about — see **Session retro**.

## Implementation

Spawn the Implementation agent with the Agent tool: `subagent_type: "general-purpose"` (not `fork` — it should not inherit your context). Note the agent ID from the spawn result; you continue the agent with SendMessage to that ID. This agent persists for the whole task; always continue it rather than spawning a new one, since its accumulated understanding of *why* things were done is the reason it exists.

Tell the user once, right after spawning: each time the Impl agent ends a turn they'll see a "finished" notice. That's normal — it resumes with full context when you send it the next message. In the same message, give the report path and the `scp` line (see **Session record**).

Its spawn prompt should contain the unit of work plus this brief (adapt as needed):

> You are the Implementation agent for: <unit of work>.
>
> - **Work in your own git worktree**, never in the user's checkout. The user may have uncommitted changes there, and repo-wide commands (formatters, codegen) can silently destroy them. Start with `git worktree add <scratch-path> -b <branch> <base>`, install dependencies there, and run everything from it. If a project script only works from the main checkout, ask rather than working around it.
> - **Explore through subagents, and keep summaries rather than file dumps.** Your context has to last the whole task, through every review round. Send each "how does X work" or "where does Y live" question to a read-only `Explore` subagent. Ask it for a map: the files and symbols involved, the `path:line` ranges that matter, the data shapes, and any gotchas. If a question spans several subsystems, split it into 2–4 angles and spawn them all in one message. Read source yourself only for the lines you're about to change or need to match exactly. Find them with `grep -n`, read them with `Read` using offset/limit, and don't re-read a range you've already seen. Never `cat` a whole source file. Send build and test output to a log file and read it through `tail` or `grep`.
> - Work autonomously. Make your own reasonable decisions without checking in. Only stop and return when you hit a genuine question that needs the user's input (ambiguous requirements, product decisions, trade-offs you can't resolve from the code or issue). When you do, end your turn with the questions clearly listed — don't guess past them.
> - Follow the repo's commit conventions (check CLAUDE.md). Unless told otherwise: one commit for the unit of work, with all later remediation amended into it.
> - Keep tests green. Run the test suite before ending any turn where you changed code, and report the result. Any accepted change that alters behaviour needs a test that pins the new behaviour — review fixes are a common source of new bugs.
> - Later, you'll receive review findings. You don't review your own work, but you know best why things were done the way they were — for each finding give a recommendation (accept / reject / modify) with a short justification. You may run experiments to check a finding, but restore everything afterwards and say what you tried. Don't act on findings until told which ones the user approved; once told, carry out the approved remediation autonomously.
> - **Remediate exactly what was approved, and no more.** Each accepted finding arrives with a scope — one site, or a named set of sites. Anything else you think also needs changing is a *new proposal*: report it with the remedy and leave the code alone. Writing the remedy stronger than it was approved, or tidying the neighbourhood while you are in there, is how the next review round gets its findings — and they will be yours, against work nobody approved. If an approved remedy turns out to be unimplementable as scoped, say so and stop rather than widening it.
> - End every turn with a status block:
>   - Worktree: <path>
>   - Branch: <name>
>   - Commit: <current HEAD sha>
>   - Review scope: <a range that survives amends, e.g. `origin/main..HEAD`>
>   - Tests: <pass/fail + command run>
>   - Open questions: <list, or "none">

When the Impl agent returns with questions, surface them to the user verbatim and relay the user's answers back verbatim (in unsupervised mode, answer them yourself unless they need escalating, and tell the Impl agent the answer came from you). Repeat until the initial implementation is done with green tests, then begin reviews.

## Relaying findings

Every review round, of either kind, follows this process:

1. Send the reviewer's findings verbatim to the Impl agent and ask for a recommendation on each.
2. Show the user a summary table first, then the verbatim findings and recommendations below it:

   | # | Finding (short) | Impl recommendation | Decision |
   |---|---|---|---|

3. Get a decision on each finding. The user can respond per finding, or use shortcuts like "accept all recommended", "accept all", or "accept recommended except 3, 5". Relay any questions or clarifications back and forth until every finding is decided. (Unsupervised: you decide, per **Unsupervised decisions**, and the user decides only what you escalate.)
4. For each accepted finding, settle whether its defect is an **instance** or a **class** — see **Class findings**. Send that with the decision.
5. Send the decisions to the Impl agent and let it remediate — each one saying *which* defect to fix and how far to go, never in a register that can be pasted into the file under review (see the `reason` rule in [`references/session-record.md`](references/session-record.md)). It must finish with tests green and report its status block.
6. Record every finding and its decision in the ledger (below), along with the commit sha after remediation.

## Class findings

A finding describes an instance. Its defect is sometimes a **class**: one rule, invariant, guard or contract stated in several places, where the finding happens to name the site the reviewer looked at. Remediating the named site and stopping is what produces round after round of near-identical findings — each round sweeps one more site, and the reviewer that finds the next one looks like it found something new.

So for every accepted finding, settle before remediation which it is:

- **Instance** — the defect is local to the site named. Remediate it.
- **Class** — the same defect exists wherever the rule is stated. Remediation must sweep **every** site, and the Impl agent reports the list it swept. Where the sweep is genuinely out of scope, decline it as instance-only *explicitly*, record that in the ledger, and pass it to the next reviewer as a decided finding — otherwise the next round re-raises it and nothing records that the narrowing was deliberate.

The reviewer is often the one that tells you. A finding that counts sites ("four of the five call sites", "both halves of the rule", "the sibling at `:211` was left byte-identical") is naming a class. So is a finding whose own diagnosis is duplication — *the diff copied the guard into four files instead of extracting it* is a finding about the fifth file, whether or not the reviewer noticed.

Where the class is "this rule is stated in N places at all", the remedy that ends the loop is usually to make it stated once. Prefer that over a wider sweep, and say so when you relay.

## Ledger

Keep a running ledger across all rounds in `session.json` (see **Session record**), not just in your context: long sessions get compacted, and the verbatim findings and reasons are what a summary loses. Re-read it before each round. Each fresh reviewer starts from zero, so without this it will re-raise findings the user already rejected — the main source of churn. The ledger also lets you detect thrash.

For each finding: round number, reviewer, short description, decision (accepted / rejected / modified), who decided (user / shepherd), and a one-line reason. For each round: the commit sha after its remediation.

Pass the reviewer the rejected and modified entries as "already decided — do not re-raise unless you have a materially new argument."

Pass them as **findings**, one entry per finding, each carrying its own specific claim: the `path:line` it was about, what it asserted, what was decided (rejected or modified), and the one-line reason.

**Never describe a function, file, module or area as settled, and never merge several entries into one.** "`parseManifest` was settled in round 3" tells the reviewer to skip a whole function. "Round 3 rejected the claim that `parseManifest` should take a non-empty tuple, because X" tells it exactly one sentence not to write again. The first is how a real defect survives round after round: the reviewer sees it, reads the area as out of bounds, and talks itself out of reporting it. If an entry's `short` cannot be read as a claim about a specific line, rewrite it before passing it on; if you cannot, leave the entry out rather than hand over an area.

## Session record

Each session gets a directory `~/.agents/task-shepherd/reports/<repo>/<YYYY-MM-DD>-<slug>/`, where `<slug>` is the issue number or a short kebab-case name for the task (append `-2`, `-3` if it exists). It holds:

- `session.json` — the source of truth for the ledger. Create it right after spawning the Impl agent, once you have its branch and base.
- `report.html` — a self-contained view of it. Regenerate it after every write with `python3 <this skill's directory>/render_report.py <session dir>`.

**The schema and the rule for every field are in [`references/session-record.md`](references/session-record.md). Read it before the first write** — several fields mean something specific enough that guessing produces a record the retro reads wrongly, and `defectScope`, `cancelled`, `scopeNote` and `stopReason` all carry rules you cannot infer from their names.

Write to `session.json` whenever something is decided: each question answered, each round once remediation has landed (with its `shaAfter` and tests), the stop reason, and the outcome of the **Done** steps. Set `updatedAt` on every write. Record findings, Impl replies and questions verbatim — never paraphrase into these fields; `short` and `reason` are where you summarise.

The report lives on this machine, so give the user a copy command: `scp <output of hostname -f>:<session dir>/report.html .`

## Reviews

Spawn each reviewer with the Agent tool as a fresh `general-purpose` agent (not `fork`, so it reviews with fresh eyes rather than inheriting your context). Include in its prompt:

- The worktree path and the review scope from the Impl agent's latest status block.
- From round 2 on, the previous round's changes: `git diff <sha before last remediation> <current sha>` (amended commits stay reachable locally). Ask the reviewer to check these first — fixes made in response to review are where new bugs tend to appear.
- The skill to run.
- The ledger's prior decisions (see above).
- "This is a read-only review. Do not edit, stage, or commit anything — report findings only, even if the skill encourages you to restructure the code." Review skills may tell the reviewer to "go for it"; here, the user decides what gets changed.

### 1. Code quality rounds

Have the reviewer run the `code-review` skill from the config on the scope. Then follow **Relaying findings**.

Repeat with a new reviewer each round until one of these happens:
- A round produces no actionable findings (everything is rejected, or the reviewer found nothing).
- Thrash: the ledger shows a round reversing an earlier accepted change as a matter of taste (round N changed X→Y, round N+1 suggests Y→X), or re-raising rejected findings without new arguments. Tell the user what you observed and stop the rounds. A reversal because the earlier change introduced a real bug is not thrash — note it and carry on.
- The review has outgrown the artifact, and the user agrees it should stop — see **Proportionality**. The findings may still be real; this is the stop reason for when they have stopped being worth the round.
- The user stops the rounds.
- 10 rounds are done (hard cap).

Each of those is a different `stopReason`, and they are not interchangeable: the retro reads the field as a signal about how the session ran, so a session that was stopped recorded as `clean` tells it the opposite of what happened.

Expect most rounds after the first to find defects in the previous round's remediation rather than in the original work — that is the normal shape, not a sign something has gone wrong. What it *does* mean is that the round-1 scope is never the right scope again: give every later reviewer the previous round's diff, as **Reviews** describes.

### 2. Clarity review (once)

Spawn one reviewer to run the `clarity-review` skill from the config on the latest scope. Follow **Relaying findings**. This runs once — no repeat rounds. Skip it if the config says `none`.

### 3. Verification

If the project has a verify/UAT skill or documented manual check (e.g. a `verify-<app>` skill), have the Impl agent run it now, against the final code — reviews can change behaviour, so a check run before them doesn't count. Relay anything it needs from the user (sign-ins, credentials refreshes). Bugs it finds are fixed and amended, tests green. If there's no such check, skip this step.

## Session retro

Once the code is settled, the session itself gets reviewed. Spawn one agent to run the `session-retro` skill: a fresh `general-purpose` agent, not a `fork` — it reasons with clean eyes like every other reviewer here, and your context is the thing it would otherwise inherit its conclusions from.

Run it **after verification and before the tracker step of Done**, while the Impl agent's worktree is still present: the retro checks the artifacts it names against it. It runs unless the user passed `--no-retro`, in which case record the skip in the one shape given in [`references/session-record.md`](references/session-record.md) and go to **Done**.

The stop reason is one of the retro's signals, so `stopReason` has to be in the record before it runs: write it when the rounds stop, not in **Done**.

Its prompt needs:

- The session directory path. `session.json` is its evidence; it reads the ledger itself rather than being told what's in it.
- `--worktree <path>` — the Impl agent's worktree from the latest status block. The skill requires it, and it is the only repo the retro reads.
- "This is read-only. Do not edit, stage or commit anything, in any repo."
- "Cite counts, round numbers, decision ids and paths. Never quote finding text, answer text, tool output or file contents."

The retro returns at most seven ranked findings as JSON. Record them in `retro` with `decision` and `decidedBy` null (see [`references/session-record.md`](references/session-record.md)), set `ranAt` and `updatedAt`, and render the report. They are decided with the final report, in **Done** — not in a round of their own.

Two other things make it a skip, and neither is a clean result: the skill isn't installed, or it ran and returned output you cannot parse into the record. In both, don't improvise a retro yourself and don't let it block the session — record the skip, in the shape [`references/session-record.md`](references/session-record.md) gives, and carry on to **Done**. **An empty findings array is not one of them** — that retro ran. The retro is the one review step with no entry in the config, which is why its missing-skill case is handled here rather than there.

## Done

The work is done once the last of verification, the clarity round or the code quality rounds has landed with tests green. Set `status`, `endedAt` and `outcome.finalSha` in `session.json` (`stopReason` is already written — see **Session retro**), render the report, and give the user a short final report — the full ledger and, in unsupervised mode, the audit of your own decisions are in the HTML, not the chat:

- Final commit sha, branch and scope
- Test and verification status
- Number of code-quality rounds and why they stopped (clean / thrash / cap)
- Counts by decision (accepted / rejected / modified / deferred) and by who decided
- Only what needs the user now: anything still escalated, and findings marked `revisit`
- The report path and the `scp` line

Then append the retro's findings as one compact table, in rank order. It carries its own columns, but it is decided the same way a review round is — per finding, or in bulk ("accept all", "accept all except 3"):

| # | Finding (short) | Category | Target | Decision |
|---|---|---|---|---|

The target column names the owner beside the path (`skill:session-retro · SKILL.md`), because `SKILL.md` is a different file in every skill and this is the table the user decides from.

Each finding is **accepted, rejected or deferred**, and that is the whole vocabulary. There is deliberately no `modified`: a retro finding is a proposal, so the decisions are to propose it, not to, or not yet — and a remedy you would shape differently goes in `reason`, the one field you author. There is no escalation either: you show this table with your decisions on it before anything is filed, so a decision the user would have made differently is in front of them with time to say so, and the tracker step below needs their approval in both modes anyway.

The full text, evidence and cost are in `report.html`; the table carries the short line only. In unsupervised mode you decide them, and show the table with your decisions and a one-line reason each. Write every decision, `decidedBy` and `reason` back to `retro.findings`, set `updatedAt`, and render the report.

If the retro was skipped, say so in one line with its cause. If it ran and reported nothing, say *that* — a session with no retro findings is the clean result, not an empty table to print.

Then (in both modes, these need the user's approval — pushing, opening PRs and changing the tracker are visible to others):

1. **Ship.** Offer to push and open a PR, following the repo's conventions. If the user agrees, the Impl agent does it.
2. **Update the tracker.** Read the open issues. For any whose assumptions, scope or details changed because of this session (something now done, a dependency added or removed, a design decision that affects it), propose a comment or edit. For every deferred item — out-of-scope bugs found, options set aside for later, follow-up work — propose a new issue. Show the user the list, then make the approved changes yourself, following the repo's issue-tracker conventions.

   Every **accepted** retro finding is proposed here too, as a new issue — `action: "create"` — against its own target. Nothing is applied to a file: a retro finding is an issue, and whoever picks it up decides what to write. A deferred finding isn't proposed at all: it belongs to the user's own list, and the report already gives it a home under Open threads, so filing it would turn "not now" into a tracker item nobody chose.

   Which key `target` carries says where the issue goes. `repo` is the work repo: file there like anything else in this step. `skill` names a *skill*, not a repo, because the retro cannot see where a skill it isn't looking at came from — so you resolve it, from the directory that skill is installed in. If that directory is a git checkout of a repo the user has, file there. If it's an installed copy — a plugin directory, or anything `npx skills` wrote — there is no tracker to file against: show the user the proposal with the reason that no owning repo could be resolved, and leave it `proposed` unless they decline it.

   Creating issues needs the user's approval even in unsupervised mode, by the same rule as everything else in this step. Record each outcome in `outcome.trackerChanges` alongside the rest, naming the finding id in the title so the record ties the two together.
3. **Clean up.** Once the branch is pushed (or the user says so), have the Impl agent remove its worktree.

Record the outcome of steps 1 and 2 (`pushed`, `pr`, `trackerChanges`) in `session.json` and render the report again.
