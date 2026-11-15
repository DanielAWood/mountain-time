---
name: trust-boundary-review
description: "Review what a change lets cross a trust boundary: what each client-visible value reveals, what untrusted input reaches models, tools and interpreters, and whether the caller may act on this object, field and tenant. Checks the code against documented decisions. Report-only. Use for /trust-boundary-review, or as the security reviewer in a code-carve roster."
argument-hint: "[commit|range|branch|PR#|path — defaults to the current change]"
---

# Trust Boundary Review

Three questions, asked of every boundary the change touches:

1. **What leaves?** What does each client-visible value let the caller tell apart, and was that intended?
2. **What enters?** What untrusted input reaches a model, tool or interpreter, and what authority does it get there?
3. **Who may?** Is this caller allowed to act on this object, this field and this tenant?

Most defects here are not exploits. A field can be well-typed, tested and correctly named, and still undo a decision the project made about what a caller may learn. So read what the project decided before reading the code, and read every value a field can hold, not just its name.

This review is narrow on purpose. It leaves out dependency CVEs, cryptography choices, denial of service and rate limits, and whether the surrounding logic computes the right answer.

## Target

Scope comes from `$ARGUMENTS`: a path, commit, range, branch, or PR number; empty means uncommitted changes plus the current branch's diff vs its base. For a single commit, compare against its first parent. Where a pass invoking this review hands over an explicit scope and base revision, that wins. Run `git status --short` first and do not report problems already fixed in the worktree.

**Scope discipline.** On a diff, report only surfaces the change added, altered or made reachable. A pre-existing field becomes in scope when the change newly populates it with a new value or sends it to a new caller. On a bare path there is no base revision: review every surface in the path, and say that you did.

## Read the Intent First

Before enumerating, collect what the project has decided about these boundaries:

- decisions handed over by the invoker, including any made during this session
- the issue or PR description
- ADRs and decision records (`docs/adr/`, `docs/decisions/`, or wherever this repo keeps them), including any the change adds
- security and tenancy rules in `CLAUDE.md`, `AGENTS.md`, or a threat model

Quote each relevant decision **and its reason**. The reason governs, not only the literal rule. A decision to show two cases the same copy because telling them apart would help an attacker also covers any other channel that tells them apart. Say what you read, and say when nothing was documented.

Only decisions about what a caller may learn or do count here. A code/doc conflict over UX, product scope or architecture is not a trust-boundary defect, even if the conflict is real.

## Enumerate First

List these before forming any finding. Judge the surfaces the scope has, not the ones you happened to read.

A surface is something the code or config in scope can do when it runs. A design doc, plan or ADR is intent to check code against; it is not a surface, and neither is anything it proposes to build. On a diff, unchanged code does not become a surface because a changed doc mentions it.

**Leaves:** every field the change can send to a client or other caller outside the trust boundary, in response bodies, stream chunks, error payloads, status codes, headers and redirects. Include client-bundled config. For each field, list **every value it can hold**, and trace it from producer to serializer.

**Enters:** every untrusted source the change reads, including request fields, stored user content, third-party and tool responses, and model output. For each, name the sink it reaches: a model's context, a tool argument, a query, a shell, a filesystem path, a fetched URL, or rendered HTML or Markdown.

**Who may:** every route, handler, tool, job and query the change adds or widens. For each, name where identity comes from, where object ownership is checked, where the tenant comes from, and which fields the caller may set.

If a list is empty, say so in these words: "**Vacuous:** this review enumerated the scope and found no `<leaves|enters|who may>` surface." If all three are empty, stop with no findings; a docs-only diff ends here. A collating pass has to tell *the question does not arise here* from *nobody asked it*.

## Standards

1. **Every distinction is a disclosure.** For each client-visible value, ask what a caller learns from receiving it rather than another value. Check enum members, optional fields present or absent, differing status codes, and differing response shapes. Ignore how the UI treats the value: the client's rendering is not the boundary, the wire is.

2. **Code is checked against decisions by their reasons.** Where a value, channel or behavior defeats a documented decision or its stated reason, that is a defect even if the code satisfies the decision's literal wording. Quote the decision.

3. **A sensitive distinction with no decision behind it is a question.** Where nothing documents the choice, and the value exposes a classifier verdict, internal reason code, existence of an object, internal identifier, prompt text, secret, or another tenant's data, report it as `PLAUSIBLE (intent)`. Name the two callers: the one who gains by acting on the distinction, and the one who abuses it. `error-path-review` asks for distinct codes where a legitimate caller acts differently. Where the two reviews pull apart, say so, and let the collating pass present one decision.

4. **Response and write shapes are allowlists.** A response built by spreading a stored record exposes every column added later. A write that spreads a request body lets the client set `tenantId`, `role`, or ownership. Name the field. (OWASP API3:2023.)

5. **Untrusted input does not get the authority of the instructions around it.** Name the source, path, sink, and what a successful attack obtains. For a model, that means which tools it can call, and with whose identity, once content in its context steers it. Stored content is untrusted, whoever typed it. Model output is untrusted at its own sinks: tool arguments, rendered Markdown, links. For a query, shell, path, URL or HTML sink, name the missing parameterization or encoding.

6. **The check belongs to every path that reaches the object.** Authorize per object and per field, not per route. A tenant taken from a request body or path, rather than from verified identity, is a defect. A tool the model can call is a route. Where one sibling has the check and another does not, name every sibling.

7. **Enforcement is server-side and fails closed.** A rule enforced only in the client is not enforced. A guard whose error path lets the request through is off whenever its dependency is down, unless a documented decision accepts that.

## Reasons That Clear Nothing

- "The client doesn't display it." Anyone can read the wire.
- "Only our own client calls this." The caller is whoever holds a session.
- "An attacker could guess." Then show the guess is as good as the signal.
- "It needs another bug to matter." State the chain and report it. Do not require a full exploit.
- "Stakes are low today." That affects priority. Name the planned capability that raises them, if any.
- "The field was renamed or reviewed last round." A review of a name is not a review of its values.

## Verify Before Reporting

1. **In scope.** The change added it, altered it, or made it reachable.
2. **It reaches the boundary.** Trace from producer to serializer or sink, with `path:line` at each end. Prefer demonstrating over arguing: parse the value through the schema, or run the path. Name the input that produces it. Where the types admit the value and no producer is known, mark it `PLAUSIBLE (unreached)`.
3. **The gain is named.** Say who learns or does what, and what they would do next. A finding with no answer here is dropped.
4. **The blast radius is named.** For a remedy that changes the wire, list the client code, tests and logs that read the old shape.

Drop silently only what fails item 1 or 3. Report the rest with what you could not establish.

- **CONFIRMED** — contradicts a documented decision or its reason, or is a demonstrable violation of a standard, and the remedy is clear. Not available where the gain depends on how a model responds and you did not run that model.
- **PLAUSIBLE** — the defect is real, and either the right remedy needs a design decision or the gain depends on model behavior you did not observe. Say which.
- **PLAUSIBLE (intent)** — whether it is a defect depends on a decision nobody has written down. The open question goes to whoever owns that decision.
- **PLAUSIBLE (unreached)** — the types admit it, and no producer is known to emit it.

A remedy that changes what a caller observes carries the label **`behavior-affecting`**. State what the caller sees differently. Where internal consumers need the removed detail, say where it goes instead, such as a log line, metric or trace.

## Project Overlay

Read the first that exists and treat its rules as additional numbered standards at full strength:

- `<repo root>/.agents/trust-boundary-review-overlay.md`
- `trust-boundary-review-overlay.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

An overlay is where a project names its tenant model, identity source and what a caller may see. If none exists, do not mention it.

## Output

```
path/to/file.ts:42  question <leaves|enters|who may>  standard <n>
                    [CONFIRMED|PLAUSIBLE|PLAUSIBLE (intent)|PLAUSIBLE (unreached)]  [behavior-affecting]
the surface, quoted, with the producer → boundary trace
decision → the quoted decision and its reason, or "none documented"
gain → who learns or does what, and what they do next
remedy → the change, and where any removed detail goes instead
reads the old one → the clients, tests and logs affected
open question → any PLAUSIBLE form: what has to be decided, and by whom
```

Then one tally line: findings by verdict, the surfaces enumerated under each question, and which of those carry no finding. List the decisions you read. If nothing survives, say so in one line and name the surfaces you checked. Do not manufacture findings.

## Do Not

- Do not edit, stage, or commit. Report only.
- Do not report a pre-existing surface the change did not touch, on a diff scope.
- Do not clear a value because its field's name sounds harmless. Read the values.
- Do not review message completeness; that is `error-path-review`'s.
- Do not propose a remedy that drops detail internal consumers need without saying where it goes instead.
