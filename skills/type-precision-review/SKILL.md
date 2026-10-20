---
name: type-precision-review
description: "Review whether a change uses the precise types the project already offers: shared contracts over local redeclarations, distinct types over bare primitives, one parse at the boundary over casts and scattered validation. Behavior-preserving, report-only. Use for /type-precision-review, or as the type reviewer in a code-carve roster."
argument-hint: "[commit|range|branch|PR#|path — defaults to the current change]"
disable-model-invocation: true
---

# Type Precision Review

One question, asked everywhere: **where the project already offers a precise type, does the change use it?**

A loose type is not a style preference. A domain value travelling as a bare `string` is a value nobody validated, carried through code that cannot tell valid from invalid. The precise type exists to make that visible, so every place it has been widened, cast away, or redeclared is a defect with a reader cost and usually a latent bug.

## Target

Scope comes from `$ARGUMENTS`: a path, commit, range, branch, or PR number; empty means uncommitted changes plus the current branch's diff vs its base. For a single commit, compare against its first parent. Run `git status --short` first and do not report problems already fixed in the worktree.

**Scope discipline.** Report only what the change introduced or made load-bearing. A pre-existing loose signature is out of scope however bad it looks; note it rather than reporting it. Without this rule a repeated review re-raises the whole codebase every round.

## Orient First

Before judging anything, find out what the project actually offers. A finding that recommends a type the codebase does not have is noise.

1. Locate the shared contracts, types, or schema module the touched code belongs to.
2. List the types, schemas, and distinct identifier types it exports for the concepts in the diff.
3. Note the project's parse and validation convention — a schema library, a factory, a type guard.
4. Note any configured lint rules on unsafe assertions and narrowing.

If the project has no shared types and no validation convention, say so and stop. There is nothing for this review to enforce, and inventing a type system for them is not its job.

## The Interface Is Bigger Than the Signature

The interface of a function is everything a caller must know to use it correctly: not only its parameter and return types, but the invariants it assumes, the errors it can produce, and the order in which things must happen. Precise types are how that knowledge moves out of prose and folklore and into something the compiler checks.

So the question behind every standard below is: **what must a caller know here that the types could have told them instead?** A signature reading `(a: string, b: string)` that silently requires the first to be a resolved identifier, the second to be non-empty, and the two to refer to the same entity has a far larger interface than its two parameters suggest. Every requirement left out of the types is one a caller can violate and no reviewer will catch.

An invariant stated in a comment is a requirement the reader must remember. The same invariant in a type is one they cannot get wrong. Prefer the second, and treat a comment documenting a precondition the type could carry as a finding in its own right — the remedy is the type, not better wording.

## Standards

1. **A concept with an existing shared type must use it.** A locally re-declared interface, a parallel schema, or a hand-rolled union over the same values is a structural problem, not a style choice. Subtle widening — an extra optional field, a looser union member — is worse than outright duplication, because it type-checks until it doesn't.

2. **A domain value must not travel as a bare primitive where the project defines a precise type for it.** Identifiers, tokens, paths, money, durations. A bare `string` in a signature, field, prop, or map key where a distinct type exists means the value was never parsed.

3. **Casts do not create validity.** A cast, `as unknown as`, or a spread that strips a precise type back to its primitive defeats the whole mechanism. Treat each as a finding, and ask where the value should have been parsed instead — ideally once, at the boundary, with the canonical schema.

4. **Respect the distinctions the project's types encode.** A reference that admits aliases is not a resolved identifier. A value naming exactly one entity is not one that defers resolution. Accepting the looser type where the code needs the resolved one, or threading an alias deep into logic that assumes resolution, is a boundary bug waiting to happen.

5. **Prefer composing an existing composite type over re-listing its fields inline.** A signature taking the composite states its depth; four loose primitive params do not.

6. **Parse at the edge, carry precise values inward.** Validation scattered mid-flow, or re-validation of an already-validated value, both signal the boundary is in the wrong place.

7. **Question needless optionality and escape hatches.** Unnecessary `?`, `unknown`, `any`, and cast-heavy code where a clearer boundary could exist. Where a branch leans on a silent fallback to paper over an unclear invariant, ask whether the boundary should be explicit instead.

8. **Justified exceptions exist.** External or untrusted input not yet parsed, interop with a third-party type, a genuine test fixture. Require the justification to be stated where it is surprising, not assumed.

9. **Zero-cost construction of self-minted values is legitimate, under conditions.** Where a module builds a value itself the construction is the proof, and re-parsing buys nothing; on a hot path the parse is pure cost. Prefer, in this order:
   1. **A structural type, where the value's shape is the whole contract.** A template-literal type is satisfied by the template literal that builds it — no assertion, no parse, no suppression, nothing for a lint rule to object to. This gives up nominality, so it fits formatting conventions whose shape *is* the agreement, not identifiers whose validity is a fact about a store.
   2. **A minting constructor returning the nominal type**, with the single narrowing assertion inside it and its justification stated there.
   3. **An assertion helper** (`asserts value is T`), only when all of these hold: it lives in the module defining the type, it is applied solely to values that module minted, and a real parsing path exists for anything inbound.

   Flag an assertion helper when any condition slips. Applied to a wire value, a route param, a store read, or an argument the module did not build, it is a cast with a reassuring name — and worse than a plain cast, because it narrows the caller's variable in place with no value to point at.

10. **Watch for the assertion form chosen to evade the linter.** An `asserts value is T` signature is invisible to rules banning unsafe narrowing assertions, because it is a signature rather than an assertion expression. Where such a rule is configured, that invisibility is not a point in the helper's favour: it performs the act the rule exists to surface. If a narrowing assertion is genuinely warranted, prefer a visible suppression with its reason at the one mint site over a helper that routes around the rule silently.

## Review Questions

- Does a shared contracts or types module already define this type, schema, or identifier? If so, why isn't it imported?
- Is a domain value typed as a bare primitive where the project defines a precise type for it?
- Does this accept a looser type than it actually requires — an unresolved reference where it needs a resolved value, or loose params where a composite type exists?
- Is parsing happening once at the boundary, or sprinkled through the flow?
- Did the diff introduce casts, optionality, or ad-hoc object shapes that obscure the real invariant?
- Where a value is asserted rather than parsed, did the module that defines the type mint that value itself?
- What must a caller know here that the types don't say? Which of those requirements could a type carry?
- Is a precondition, ordering rule, or error mode documented in a comment where the type system could enforce it?

## What to Flag Aggressively

- A domain value typed as a bare primitive where a precise type exists.
- A cast, `as unknown as`, or spread that launders an unvalidated value into a precise type.
- An assertion helper applied to values its own module did not construct, or exported where a parse belongs.
- An assertion used to sidestep a lint rule banning unsafe narrowing, where the real fix is a structural type or a visible suppression.
- A local type, interface, or schema that duplicates or subtly widens one the shared module already defines.
- Inline object shapes or loose primitive params where a defined composite type exists.
- An unresolved reference or alias threaded past the layer that should have resolved it.
- Validation repeated mid-flow on values already parsed at the boundary.
- `any`, `unknown`, or optional params that muddy what the contract really is.
- A precondition, ordering requirement, or error mode that exists only in a comment, where a type could enforce it.
- Two parameters of the same primitive type that a caller can transpose without the compiler noticing.

## Preferred Remedies

- Import the shared type or schema and delete the local redeclaration.
- Replace a cast with a single parse at the boundary, then carry the precise value inward unchanged.
- Take the composite type instead of a handful of primitives.
- Resolve a reference to a concrete value at the layer that owns the read, so downstream code only sees resolved values.
- Replace an assertion helper with a minting constructor, or with a structural type the constructor satisfies outright.
- Make the boundary explicit so the control flow downstream gets simpler.
- Move a documented precondition into a type, and delete the comment that carried it.

## Verify Before Reporting

Confirm all four before reporting:

1. **The precise type exists.** Name it and the module it comes from. A recommendation to use a type you have not located is the characteristic failure of this review.
2. **It is in scope.** The change introduced or widened it.
3. **The remedy preserves behavior.** A parse added at a boundary can reject input that previously flowed through. Say so where it can, and name the call sites affected.
4. **It is not a justified exception** under standard 8.

Mark each surviving finding **CONFIRMED** when all four hold, or **PLAUSIBLE** when the defect is verified but the right boundary needs a design decision — then say what the open question is. Drop failures of 1 or 2 silently.

## Project Overlay

Projects name their own contracts, so most of this review's real force lives in an overlay. Read the first that exists and treat its rules as additional numbered standards at full strength:

- `<repo root>/.agents/type-precision-review-overlay.md` — shared with everyone working on the repo
- `type-precision-review-overlay.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

An overlay is where the contracts package gets named, the project's distinct identifier types get listed, and its own Id-versus-reference distinctions get spelled out. Overlays live outside the skill directory because skill updates replace that directory wholesale. If none exists, review with the standards above and do not mention the overlay.

## Output

```
path/to/file.ts:42  [CONFIRMED|PLAUSIBLE]
the loose type, and the precise type that should be there — named, with its module
remedy → where the parse belongs, and what stops being possible once it's there
```

Then a one-line tally: findings by verdict, plus any out-of-scope notes.

If the change uses the project's types faithfully, say so in one line. Do not manufacture findings, and do not report a type the project does not have.

## Do Not

- Do not edit, stage, or commit. Report only.
- Do not invent a type system the project has not adopted.
- Do not report identifier names or comment wording.
- Do not report pre-existing loose types as findings.
- Do not recommend a parse without saying where it goes and what it rejects.
