---
name: prose-review
description: Review comments and docs — delete the ones that don't earn their place, fix the rest
argument-hint: "[path|PR#|branch] [--fix]"
disable-model-invocation: true
---

# Prose Review

Review **prose only**: code comments, docstrings, and documentation. Do not review or change logic.

## Target

Scope comes from the invocation arguments or request (`$ARGUMENTS`):

- empty → uncommitted changes plus the current branch's diff vs its base
- a path → that file or directory tree
- a PR number or branch → that diff
- `--fix` anywhere in the args → apply the findings after reporting; otherwise report only

Only judge prose that appears in the target. Untouched comments elsewhere are out of scope.

## Core Principle

Code is self-documenting. A comment earns its place only by supplying context the code cannot: intent, constraint, external reason, non-obvious consequence. Absent that, it is noise that rots.

Default verdict on a comment is **delete**. It survives only if a competent engineer reading the code would otherwise be surprised, or would have to leave the file to understand why the code is the way it is.

## Banned Patterns

**0. Diff-narration.** `[NARRATION]` No description of what the code used to do or how it changed. Git holds the old version; a comment about it is stale on arrival.
Bad: `// Previously used a Map here`, `// Now handles null too`, `// Removed the retry loop`

**1. Conversational leakage / session bleed.** `[BLEED]` No reference to a chat session, prompt, or the act of modifying the code.
Bad: `// As requested`, `// Per your instructions`, `// I have updated this`, `// Fixed from before`, `// Changes made`
The code must read as a human's single clean pass. Strip all metadata about how or when it was generated.

**2. Rhetorical asides and thinking out loud.** `[ASIDE]` Comments state final, objective engineering facts. No debates, hesitation, or rhetorical questions.
Bad: `// We could do X, but Y is fine`, `// Is this efficient? Probably`, `// Quick fix, a robust architecture would...`
If a design choice was made, document the constraint instead: `// Linear search: array size is capped at < 10`

**3. First-person pronouns and polite filler.** `[VOICE]` Objective, passive, or imperative voice. Never `I`, `we`, `us`, `our`, `let's`.
Bad: `// Let's go ahead and clear the cache`, `// I am adding this check just to be safe`, `// Hopefully this fixes it`
Good: `// Clear the cache`

**4. Textbook / educational over-explaining.** `[TEXTBOOK]` The reader is a competent engineer who knows the language. Never explain what `try/catch`, `.map()`, `.filter()`, a loop, or a basic data structure does — explain why the business logic needs it.
Bad: `// Using a try-catch block to handle errors that might occur`
Good: `// Intercept network timeouts to trigger a background retry`

**5. Function signature echoing.** `[ECHO]` No comment or docstring that restates the name, params, or return type in sentence form.
Bad: `// This function updates the user profile` above `updateUserProfile()`
Bad: `@param userId The user id`
Delete outright if it adds nothing beyond a one-second glance at the signature.

**6. Meta-commentary outside intent.** `[ASIDE]` Meta-commentary is restricted to intent, context, and external constraints the syntax cannot express. Anything else is deleted.

**7. Decision-justification and road-not-taken.** `[JUSTIFY]` No prose defending *why the code is shaped this way* rather than stating what the value or constraint is. Two shapes:
Refactor or design rationale — Bad: `// The runtime package, named once`, `// shared so the two agree`, `// a single coordinate keeps these from drifting`, `// kept separate so tests can import it`, `// returned so tests assert against it`
Road-not-taken or API history — Bad: `// fromString is deprecated, so use fromProps`, `// rather than fromLookup`, `// we don't use X because...`
The code already uses the chosen API and already has the shape; the reasoning that produced it is noise. Keep the why only when it names a constraint the code cannot express: `// Must match the runtime's EMF namespace`, `// Same-region queue, so no resource policy`

**8. Redundant restatement.** `[RESTATE]` No comment that re-encodes what adjacent code already states — enumerating a list's or enum's members, naming the identifiers a nearby literal declares, or paraphrasing a self-evident statement. Signature echoing (#5) is the special case for function signatures; this is the general rule.
Lockstep test: *if the code changed, would this comment have to change with it to stay true, without adding anything the code doesn't say?* If yes, the comment is a second source of truth. Cut the restatement; keep only the why the code cannot carry.
Bad: `// statuses: pending, active, closed` above `enum Status { Pending, Active, Closed }`; `// retries three times` beside `for (let i = 0; i < 3; i++)`

## What Earns Its Place

Keep or write a comment when it carries:

- Why, not what: the constraint, tradeoff, or invariant behind a surprising choice
- External cause: a spec clause, protocol quirk, upstream bug, browser/vendor workaround (link or ticket it)
- Non-obvious consequence: ordering requirements, thread/lock assumptions, precision or overflow limits
- A real danger: what breaks if the next reader "simplifies" this
- Genuinely dense algorithms: the shape of the trick, not a line-by-line narration

The why must name an external cause or an invariant, not a preference. Why this name, why this file split, why not the other API — delete. Test: strip the refactor motive or the rejected alternative from the comment; if nothing remains that describes the code as it *is*, the comment was `[JUSTIFY]`.

## Clarity Pass

Separate from the banned-pattern checks: those decide whether prose survives, this decides whether the survivors read well. After the cuts, read every remaining comment and doc line and flag any that are hard to follow — tangled sentences, ambiguous pronouns, stacked clauses, jargon that hides the point. Rewrite them with `[CLARITY]` per ASD-STE100 Simplified Technical English:

- One idea per sentence. Keep them short — aim for ≤ 20 words in instructions, ≤ 25 in descriptions.
- Active voice. Present tense for descriptions, imperative for instructions.
- One term per concept. Do not cycle synonyms for the same thing.
- Concrete, plain vocabulary. Drop filler and hedging.
- No nested subordinate clauses — split them into separate sentences.

A `[CLARITY]` finding is always a rewrite, never a delete: the comment earns its place, it just reads badly. If it fails clarity *and* a banned pattern, report the banned pattern — deletion outranks rewriting.

## Documentation Prose

Same bans apply, with these adjustments:

- Second person (`you`) is fine in user-facing docs; first person is not
- No changelog narration inside reference docs — release notes live in their own file
- Cut preamble and throat-clearing; lead with the fact
- Examples must be runnable and current; flag any that drifted from the code in the target
- Flag headings that promise content the section doesn't deliver

## Severity Order

Report in this order. Do not flood with nits when higher-order findings exist.

1. `LIE` — comment or doc contradicts the code it describes. Actively harmful; fix first.
2. `NARRATION` / `BLEED` — diff-narration and session bleed. Guaranteed to rot, exposes the generation process.
3. `ASIDE` / `VOICE` / `JUSTIFY` — rhetorical asides, first-person, polite filler, decision-justification. Noise with a voice problem.
4. `ECHO` / `RESTATE` / `TEXTBOOK` — signature echoing, redundant restatement, educational over-explaining. Pure token cost and a second source of truth.
5. `CLARITY` — a surviving comment or doc that is correct but hard to read. The only finding besides `MISSING` that keeps the prose; it rewrites rather than deletes.
6. `MISSING` — code that is genuinely surprising with nothing explaining it. The only finding that adds a comment.

These eleven tags are the complete set. Every finding carries exactly one, and it is the tag printed in the output block.

## Output

Per finding:

```
path/to/file.ts:42  [LIE|NARRATION|BLEED|ASIDE|VOICE|JUSTIFY|ECHO|RESTATE|TEXTBOOK|CLARITY|MISSING]
> // the offending line, quoted
DELETE  (or) REWRITE → // the replacement
why it fails, one line
```

Then a one-line tally: counts by verdict.

If the target's prose is clean, say so in one line. Do not manufacture findings.

## Fix Mode

With `--fix`, apply every finding after reporting:

- Delete means delete the whole comment, not soften it
- Rewrite means the replacement text exactly as reported
- Touch only comments, docstrings, and docs — never logic, never formatting of code
- Do not add comments beyond the `MISSING` findings reported

Structural safeguard — the diff must contain no code changes at all:

- Deleting a whole-line comment removes that line entirely, including its indentation and newline. Deleting a trailing comment leaves the code line intact with its trailing whitespace stripped.
- Preserve surrounding structure exactly: indentation of every remaining line, blank-line spacing between blocks, trailing newline at end of file, and existing line endings.
- Never re-wrap, re-indent, or re-order code to close the gap a deleted comment left behind.
- A rewrite keeps the original comment's indentation, comment syntax, and position (own line vs trailing).
- After applying, diff the result: every changed line must be a comment, docstring, or doc line. If a code line appears in the diff, revert it.

## Do Not

- Do not add comments to raise coverage. Fewer, denser comments is the target.
- Do not preserve a comment because deleting it feels lossy — git has it.
- Do not rewrite a bad comment into a slightly better bad comment. Delete it.
- Do not reformat, reorder, or refactor code.
