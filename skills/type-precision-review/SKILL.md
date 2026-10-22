---
name: type-precision-review
description: "Review whether a change uses the precise types the project offers: shared contracts over local redeclarations, distinct types over bare primitives, one boundary parse over casts and scattered validation, and knowledge carried in a narrowing construct rather than re-checked to satisfy the compiler. Report-only; remedies behavior-preserving except where labelled. Use for /type-precision-review, or as the type reviewer in a code-carve roster."
argument-hint: "[commit|range|branch|PR#|path — defaults to the current change]"
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

Where the project has no shared types module and no validation convention, standards 1, 2, 4, 5 and 6 have nothing to enforce: each of them asks whether the change used a type or a validation convention the project already offers, and it has neither. Say so, skip those five, and review against the rest — standards 3 and 7 through 11 judge the change against its own types rather than against the project's, so they apply to any TypeScript codebase. Inventing a shared type system for a project that has not adopted one is still not this review's job.

**Where the scope holds nothing for this review to read at all, say so and stop** — and say it as *vacuous, not unexamined*: "This review enumerated the scope and found no TypeScript, so there is no typing and no narrowing here for it to be right or wrong about." A markdown-only, config-only or stylesheet-only scope reaches this exit legitimately, and so does a Python or Go repo. A collating pass has to tell *the question does not arise here* from *nobody asked it*, and acts on the two oppositely, so the wording matters. "The change uses the project's types faithfully" is a different sentence and will not serve: that one means you read typed code and found it sound.

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

11. **A check the code has already settled, and a branch that cannot run, are both findings.** They are one defect wearing two faces: knowledge the code already holds, re-derived at runtime because it was never carried in a type.

    - **The redundant re-check.** Inside a `if (!items.some(isReady)) { … }` branch, a following `first !== undefined && !isReady(first)` asks a question whose answer is already determined, and runs the predicate a second time. Report it, and say what the earlier check established. **The negation is the precondition, not decoration.** A *true* `some` settles only that **at least one** element passes, so it constrains no individual element and the re-check is load-bearing: for `[blocked, ready]`, `items.some(isReady)` is true and `!isReady(items[0])` is a live question. `some` has no type-predicate overload in any lib, so a true `some` narrows nothing. Confirm you are inside the negated branch before reporting; otherwise you are reporting a live guard as dead.
    - **The unreachable narrowing branch.** A ternary arm, `if` body, `??` right-hand side, or `default` case that no input reaches, kept so the compiler accepts the line after it. Report it, and say plainly that it is dead: a reader who trusts it will go looking for the input that reaches it and not find one.
    - **The double walk.** Where both appear together — a predicate run once in `some()` and again inside a `map`/`flatMap`/`filter` whose other branch is the unreachable one — they are a single finding with a single remedy, not two.
    - **The type-checker justification.** The category, which is what to match on: **a justification whose subject is the type-checker rather than an input that reaches the check.** Phrasing varies and no list of phrases is complete — "the compiler needs it", "TypeScript can't tell", "otherwise this doesn't narrow", "it only satisfies the compiler", "removing it would need a cast or another guard" are examples of the category, not its definition. Report it even when the check is cheap: the cost is a reader who cannot tell which checks are load-bearing. This is the same category `code-carve`'s collate step re-raises waivers on, stated here once so the two cannot drift apart.

    The remedy is to carry the knowledge in a narrowing construct, so the check runs once and the compiler learns its result. Name the construct in the finding:

    - a **type-predicate `filter`** — `items.filter((x): x is Blocked => !isReady(x))` yields a typed array in one pass, and the typed array replaces the later re-check
    - the **`this is readonly S[]` overload of `every`** — `if (items.every((x): x is Blocked => !isReady(x)))` narrows the *whole array* inside the branch. This is the construct that replaces a `some` plus a per-element re-check plus a ternary, and it is the one most often missed. **It narrows the receiver reference, so the receiver must be one the compiler can narrow** — a parameter, a `const`, or a property access. On a call result it narrows nothing: `load().every(p)` followed by `load().flatMap(…)` fails, because the second `load()` is a different expression. Bind the array to a `const` first
    - a **discriminated union**, where the two outcomes should have been distinct shapes carrying their own payloads all along
    - a **non-empty tuple** — write it `readonly [T, ...T[]]` where the collection is `readonly T[]`, to keep the readonly-ness the collection already had. Use it where the invariant being re-checked is "this collection has a first element", and **name the boundary guard (`xs is readonly [T, ...T[]]`) that makes the type reachable**: no array type satisfies a tuple type by assignment, because the length is unknown, so without a guard at the edge the remedy does not compile. The guard is the whole remedy here, not a detail of it

    Two constraints on the remedy:

    - **Annotate the predicate explicitly.** Write `(r): r is T =>` so the narrowing is stated rather than derived. Since TS 5.5 an inline arrow such as `(r) => !isGuard(r)` is *often* inferred as a type predicate, including over a negated guard — that it usually works is why a lapse in the inference is silent, not a reason to rely on it. The inference is conditional and silent when it lapses; giving the arrow an explicit `: boolean` return type kills it outright and the narrowing just stops.
    - **"Removing it would need a cast" is not a reason to keep the check.** It is a reason to try the constructs above. The check stays only once all four have been tried and named as unworkable — and then the justification belongs in the commit message or an ADR, saying which construct failed and why. Not in a comment at the site: an invariant living in a comment is a finding under this review's own standards.

    **Whose obligation the four-construct sweep is.** It is the bar the author, or whoever decides the finding, must clear before the check is allowed to stay — not a cost you pay before reporting. You compile **the one construct you propose** (verify item 3) and name it. You do not have to try all four, and you must not drop a finding because you could not afford to.

## Review Questions

- Does a shared contracts or types module already define this type, schema, or identifier? If so, why isn't it imported?
- Is a domain value typed as a bare primitive where the project defines a precise type for it?
- Does this accept a looser type than it actually requires — an unresolved reference where it needs a resolved value, or loose params where a composite type exists?
- Is parsing happening once at the boundary, or sprinkled through the flow?
- Did the diff introduce casts, optionality, or ad-hoc object shapes that obscure the real invariant?
- Where a value is asserted rather than parsed, did the module that defines the type mint that value itself?
- What must a caller know here that the types don't say? Which of those requirements could a type carry?
- Is a precondition, ordering rule, or error mode documented in a comment where the type system could enforce it?
- Does any check here re-ask a question an earlier line already settled? Is any predicate run twice over the same collection?
- Is there a branch no input can reach, kept so a later line type-checks? Which construct would let it go?
- Where a check is defended by what the type-checker believes rather than by an input, which narrowing construct would carry the knowledge instead? Name one and compile it.

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
- A runtime check whose outcome an earlier check in the same flow already settled.
- A branch, ternary arm, or fallback no input reaches, retained so the code after it type-checks.
- The same predicate walked over one collection twice, once to decide and once to narrow.
- Any check or branch whose stated justification is the type-checker rather than an input.

## Preferred Remedies

- Import the shared type or schema and delete the local redeclaration.
- Replace a cast with a single parse at the boundary, then carry the precise value inward unchanged.
- Take the composite type instead of a handful of primitives.
- Resolve a reference to a concrete value at the layer that owns the read, so downstream code only sees resolved values.
- Replace an assertion helper with a minting constructor, or with a structural type the constructor satisfies outright.
- Make the boundary explicit so the control flow downstream gets simpler.
- Move a documented precondition into a type, and delete the comment that carried it.
- Replace a **negated** `some` plus a per-element re-check with one `every` carrying an explicit type predicate, so the array arrives narrowed and the second check and its dead branch both go. Only the negated form; a true `some` settles nothing about any element.
- Replace an index-then-re-check with a type-predicate `filter`, and let the typed array carry the knowledge forward.

## Verify Before Reporting

Confirm all four before reporting:

1. **The precise type exists.** Name it and the module it comes from. A recommendation to use a type you have not located is the characteristic failure of this review. For a standard 11 finding, this is satisfied by naming the **one** narrowing construct you propose and the type its predicate narrows to — usually a type the change already has. Do not drop the finding because the project has no new type to offer; the knowledge, not the type, is what is missing.
2. **It is in scope.** The change introduced or widened it.
3. **The remedy preserves behavior, and for a standard 11 finding you compiled it.** A parse added at a boundary can reject input that previously flowed through. Say so where it can, and name the call sites affected.

   For a standard 11 finding, three things, in this order. **Name what settles the check** — the earlier line, or the reason no input reaches the branch; "it looks redundant" is not that reason. **Compile the construct you propose**, in a scratch file outside the repo, using the project's own type-checker *and the flags the project actually runs*. The flags decide the answer: a guard that looks dead under `--strict` alone is load-bearing under `--noUncheckedIndexedAccess`, and a remedy that deletes it crashes on an empty collection instead of throwing what it threw before. Asserting it compiles is how this standard fails.

   **Then check what the deleted guard was selecting.** The replacement is usually behavior-identical — `!xs.some(p)` and `xs.every(x => !p(x))` are de Morgan duals and agree on every input, empty included, so comparing them finds nothing. The risk is elsewhere: a guard being deleted alongside the predicate was often also choosing a *different error path* for the empty or single-element case. Deleting it changes, or breaks, what a caller receives there. Where it does, say so and label the finding `behavior-affecting`.
4. **It is not a justified exception** under standard 8.

Mark each surviving finding **CONFIRMED** when all four hold, or **PLAUSIBLE** when the defect is verified but the remedy is not settled — then say what the open question is. Drop failures of 1 or 2 silently.

PLAUSIBLE covers two cases, and the open question says which. The first is a remedy whose right boundary needs a design decision. The second is a **standard 11 finding you could not compile**, because the project has no type-check command — the brief that dispatched you should have said so. Mark it PLAUSIBLE, say the construct is untested, and name running the compile as the open question. Never drop it and never withhold it: a harness with no type-checker is a fact about the harness, not evidence about the code.

## Project Overlay

Projects name their own contracts, so most of this review's real force lives in an overlay. Read the first that exists and treat its rules as additional numbered standards at full strength:

- `<repo root>/.agents/type-precision-review-overlay.md` — shared with everyone working on the repo
- `type-precision-review-overlay.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

An overlay is where the contracts package gets named, the project's distinct identifier types get listed, and its own Id-versus-reference distinctions get spelled out. Overlays live outside the skill directory because skill updates replace that directory wholesale. If none exists, review with the standards above and do not mention the overlay.

## Output

```
path/to/file.ts:42  [CONFIRMED|PLAUSIBLE]  [behavior-affecting, where it is]
the loose type, and the precise type that should be there — named, with its module
remedy → where the parse belongs, and what stops being possible once it's there
```

Add the label only where the remedy changes what a caller observes — a parse added at a boundary that rejects input which used to flow through, or a deleted guard that was selecting a different error path (verify item 3) — and say in the remedy what a caller sees differently.

Then a one-line tally: findings by verdict, plus any out-of-scope notes.

If the change uses the project's types faithfully, say so in one line. Do not manufacture findings, and do not report a type the project does not have.

## Do Not

- Do not edit, stage, or commit. Report only.
- Do not invent a type system the project has not adopted.
- Do not report identifier names or comment wording.
- Do not report pre-existing loose types as findings.
- Do not recommend a parse without saying where it goes and what it rejects.
