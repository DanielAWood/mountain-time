---
name: task-shepherd
description: "Shepherd a unit of work (e.g. a GitHub issue) from implementation to done: one long-lived implementation agent, then rounds of fresh review agents, with the user deciding every finding (or the shepherd deciding, with --unsupervised). Usage: /task-shepherd [--unsupervised] <issue-url or task description>"
disable-model-invocation: true
---

# Task Shepherd

We've been given a unit of work. Correct isn't enough: first we make the code correct, then we make it good. A long-lived Implementation agent does the work; a series of short-lived review agents critique it; the user decides what gets acted on.

You are the shepherd. You don't edit code, run fixes, or review anything yourself — you spawn agents, relay between them and the user, and keep the ledger. This keeps your context clean for coordination across many rounds, and keeps a single clear owner of the code (the Impl agent), so there's never confusion about who changed what. Issue-tracker operations (reading issues, opening or commenting on them) are the exception: do those yourself.

If no unit of work was provided as an argument, ask the user what to work on before doing anything else.

## Modes

- **Supervised (default):** the user decides every finding and answers every question.
- **Unsupervised (`--unsupervised` in the arguments):** you make the decisions the user would otherwise make — on the Impl agent's recommendations and its open questions — and only stop for the user when confidence is low or the result is high risk (see **Unsupervised decisions**). Everything else in this skill stays the same: the rounds, the ledger, tests green, verification. Strip the flag before passing the unit of work to the Impl agent.

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

When you escalate, decide everything in the round that isn't flagged, then ask about just the flagged items using the same table and verbatim text as supervised mode. If a push-notification tool is available, use it so the user knows you're blocked. Wait for the answer before remediation begins.

After each round, post the table with your decisions filled in and a one-line reason for each, so the user can follow along or step in — but don't wait for a reply.

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

## Implementation

Spawn the Implementation agent with the Agent tool: `subagent_type: "general-purpose"` (not `fork` — it should not inherit your context). Note the agent ID from the spawn result; you continue the agent with SendMessage to that ID. This agent persists for the whole task; always continue it rather than spawning a new one, since its accumulated understanding of *why* things were done is the reason it exists.

Tell the user once, right after spawning: each time the Impl agent ends a turn they'll see a "finished" notice. That's normal — it resumes with full context when you send it the next message.

Its spawn prompt should contain the unit of work plus this brief (adapt as needed):

> You are the Implementation agent for: <unit of work>.
>
> - **Work in your own git worktree**, never in the user's checkout. The user may have uncommitted changes there, and repo-wide commands (formatters, codegen) can silently destroy them. Start with `git worktree add <scratch-path> -b <branch> <base>`, install dependencies there, and run everything from it. If a project script only works from the main checkout, ask rather than working around it.
> - Work autonomously. Make your own reasonable decisions without checking in. Only stop and return when you hit a genuine question that needs the user's input (ambiguous requirements, product decisions, trade-offs you can't resolve from the code or issue). When you do, end your turn with the questions clearly listed — don't guess past them.
> - Follow the repo's commit conventions (check CLAUDE.md). Unless told otherwise: one commit for the unit of work, with all later remediation amended into it.
> - Keep tests green. Run the test suite before ending any turn where you changed code, and report the result. Any accepted change that alters behaviour needs a test that pins the new behaviour — review fixes are a common source of new bugs.
> - Later, you'll receive review findings. You don't review your own work, but you know best why things were done the way they were — for each finding give a recommendation (accept / reject / modify) with a short justification. You may run experiments to check a finding, but restore everything afterwards and say what you tried. Don't act on findings until told which ones the user approved; once told, carry out the approved remediation autonomously.
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
4. Send the decisions to the Impl agent and let it remediate. It must finish with tests green and report its status block.
5. Record every finding and its decision in the ledger (below), along with the commit sha after remediation.

## Ledger

Keep a running ledger across all rounds, in your context. Each fresh reviewer starts from zero, so without this it will re-raise findings the user already rejected — the main source of churn. The ledger also lets you detect thrash.

For each finding: round number, reviewer, short description, decision (accepted / rejected / modified), who decided (user / shepherd), and a one-line reason. For each round: the commit sha after its remediation.

Pass the reviewer the rejected and modified entries as "already decided — do not re-raise unless you have a materially new argument."

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
- 10 rounds are done (hard cap).

### 2. Clarity review (once)

Spawn one reviewer to run the `clarity-review` skill from the config on the latest scope. Follow **Relaying findings**. This runs once — no repeat rounds. Skip it if the config says `none`.

### 3. Verification

If the project has a verify/UAT skill or documented manual check (e.g. a `verify-<app>` skill), have the Impl agent run it now, against the final code — reviews can change behaviour, so a check run before them doesn't count. Relay anything it needs from the user (sign-ins, credentials refreshes). Bugs it finds are fixed and amended, tests green. If there's no such check, skip this step.

## Done

The work is done once the last of verification, the clarity round or the code quality rounds has landed with tests green. Give the user a final report:

- Final commit sha, branch and scope
- Test and verification status
- Number of code-quality rounds and why they stopped (clean / thrash / cap)
- The ledger: accepted and rejected counts, plus any rejected or deferred findings worth revisiting later
- Unsupervised: every decision you made yourself (findings and answered questions), with its reason, so the user can audit them; and what you escalated

Then (in both modes, these need the user's approval — pushing, opening PRs and changing the tracker are visible to others):

1. **Ship.** Offer to push and open a PR, following the repo's conventions. If the user agrees, the Impl agent does it.
2. **Update the tracker.** Read the open issues. For any whose assumptions, scope or details changed because of this session (something now done, a dependency added or removed, a design decision that affects it), propose a comment or edit. For every deferred item — out-of-scope bugs found, options set aside for later, follow-up work — propose a new issue. Show the user the list, then make the approved changes yourself, following the repo's issue-tracker conventions.
3. **Clean up.** Once the branch is pushed (or the user says so), have the Impl agent remove its worktree.
