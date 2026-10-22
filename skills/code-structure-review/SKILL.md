---
name: code-structure-review
description: "Strict structural review of a change: abstraction quality, spaghetti growth, file sprawl, layer and ownership boundaries, and the code-judo move that would delete whole categories of complexity. Behavior-preserving, report-only. Use for /code-structure-review, or as the structural reviewer in a code-carve roster."
argument-hint: "[commit|range|branch|PR#|path — defaults to the current change]"
---

# Code Structure Review

Review how the change is **shaped**: its abstractions, its control flow, where its logic lives, and how much a reader must hold in their head. Behavior stays exactly as it is.

Above all, be **ambitious**. Do not stop at local cleanup. Actively search for "code judo" moves: restructurings that preserve behavior while making the implementation dramatically simpler, smaller, more direct, and more elegant.

> Rethink how to structure the implementation to meaningfully improve quality without affecting behavior.
> Improve abstractions and modularity, reduce spaghetti, improve succinctness and legibility.
> Be ambitious: where there is a clear path to a better implementation that means restructuring some of the surrounding code, say so.
> Be thorough and rigorous. Measure twice, cut once.

## Target

Scope comes from `$ARGUMENTS`: a path, commit, range, branch, or PR number; empty means uncommitted changes plus the current branch's diff vs its base. For a single commit, compare against its first parent. Run `git status --short` first and do not report problems already fixed in the worktree.

**Scope discipline.** Report only what the change introduced or made load-bearing. Pre-existing structure is out of scope however bad it looks, and a nearby finding does not pull it in. Where pre-existing structure genuinely blocks the change from being clean, say so as a note, not a finding. Without this rule a repeated review re-raises the whole codebase every round.

## Depth

Judge structure by what a caller must learn, not by how much code sits behind it.

A module is **deep** when a small interface hides a lot of behavior, and **shallow** when its interface is nearly as complicated as its implementation. The **interface** is everything a caller must know to use it correctly — not only the signature, but the invariants it assumes, the errors it can produce, and the configuration it needs.

**Depth is a property of the interface, not the implementation.** A large, internally intricate module with two entry points is usually better than four tidy modules with twelve. This cuts against the instinct to equate "simpler" with "smaller", and it is where this review's own bias can do damage: a decomposition that trades one entry point for four has made the code shallower and the caller's job harder, whatever it did to the line count.

So every finding must say what happens at the interface, not just what happens to the code.

## Standards

1. **Be ambitious about structural simplification.**
   - Do not stop at "this could be a bit cleaner."
   - Look for ways to reframe the change so whole branches, helpers, modes, conditionals, or layers disappear entirely.
   - Prefer the solution that makes the code feel inevitable in hindsight.
   - Assume a code-judo move is often available: a re-organization that uses the existing architecture more effectively and makes the change dramatically simpler.
   - Where you can delete complexity rather than rearrange it, push hard for that path.

2. **Do not let a change push a file from under 1k lines to over 1k lines without a strong reason.**
   - Treat the crossing as a structural smell by default.
   - Prefer extracting helpers, subcomponents, or modules over letting a file sprawl.
   - If the diff crosses the threshold, ask explicitly whether the file should be decomposed first. The threshold triggers the question; it does not settle it.
   - Before recommending a decomposition, state what it does to the interface. A split that turns one entry point into four has made the module shallower, and that cost usually exceeds whatever the line count bought.
   - Waive it for a compelling structural reason, or where the file is one deep module whose interface stays small, and only if the result is still clearly organized.

3. **Do not allow spaghetti growth in existing code.**
   - Be highly suspicious of new ad-hoc conditionals, scattered special cases, and one-off branches inserted into unrelated flows.
   - Weird `if` statements in random places are a design problem, not a stylistic nit.
   - Prefer pushing logic into a dedicated abstraction, helper, state machine, policy object, or separate module over tangling an existing path.
   - Call out changes that make surrounding code harder to reason about, even when they work.

4. **Bias toward cleaning the design, not just accepting working code.**
   - Where behavior can stay the same while the structure becomes meaningfully cleaner, push for the cleaner version.
   - Do not rubber-stamp an implementation that works but leaves the codebase messier.
   - Strongly prefer simplifications that remove moving pieces over refactors that spread the same complexity around.

5. **Prefer direct, boring, maintainable code over hacky or magical code.**
   - Treat brittle, ad-hoc, or magic behavior as a structural problem.
   - Be skeptical of generic mechanisms that hide simple data-shape assumptions.
   - Flag thin abstractions, identity wrappers, and pass-through helpers that add indirection without buying clarity.
   - **Apply the deletion test.** Delete the module in your head and look at the callers. If the complexity vanishes, it was a pass-through and the finding is to delete it. If the complexity reappears spread across every caller, it was earning its keep — and saying so is a legitimate outcome of this review, not a non-finding.
   - An interface with exactly one implementation behind it is a hypothetical seam, not a real one. One adapter means indirection; two adapters — typically production and test — mean the seam is doing work. Flag a port introduced for a single implementation.

6. **Keep logic in the canonical layer and reuse existing helpers.**
   - Call out feature logic leaking into shared paths, and implementation details leaking through APIs.
   - Prefer existing canonical utilities over bespoke one-offs.
   - Push code toward the right package, service, or module instead of normalizing architectural drift.

7. **Treat needless sequential orchestration and non-atomic updates as design smells where the cleaner structure is obvious.**
   - Where independent work is serialized for no reason, ask whether the flow should run in parallel.
   - Where related updates can leave state half-applied, push for a more atomic structure.
   - Do not over-index on micro-optimizations, but do flag avoidable orchestration complexity that makes the implementation brittle.

8. **A seam that exists only so a test can reach inside is a production defect.**
   - Where the change adds an export, an injection point, or a visibility widening whose only consumer is a test, the seam is the finding. The interface grew to serve the test suite, and every caller now pays for it.
   - The fix is to delete the seam and test through the interface a caller uses — not to keep the seam and tidy the test.
   - Where a restructuring you recommend would break tests that should have survived it, say so: it strengthens the finding rather than weakening it, because those tests were coupled to internals.
   - The tests themselves are `test-review`'s subject. Report a test asserting on internals as a note handing it over, not as a finding here.

## Review Questions

- Is there a code-judo move that would make this dramatically simpler?
- Can this be reframed so fewer concepts, branches, or helper layers are needed?
- Does this improve or worsen the local architecture?
- Did the diff add branching complexity where a better abstraction should exist?
- Did a previously cohesive module become more coupled, more stateful, or harder to scan?
- Is this logic living in the right file and layer, or did the diff leak details across a boundary?
- Did this change enlarge a file or component past a healthy size boundary?
- Are there repeated conditionals that signal a missing model or missing helper?
- Is the implementation direct and legible, or does it rely on special cases and incidental control flow?
- Is this abstraction earning its keep, or is it just a wrapper? Delete it in your head — does complexity vanish, or reappear across the callers?
- Does this change make the module deeper or shallower? What does a caller now have to learn that they didn't before?
- Does this seam have two implementations, or one and an aspiration?
- Did any part of the interface widen purely to let a test in?
- Is this orchestration more sequential or less atomic than it needs to be?

## What to Flag Aggressively

- A complicated implementation where a cleaner reframing could delete whole categories of complexity.
- Refactors that move code around but fail to reduce the number of concepts a reader must hold in their head.
- A file crossing 1000 lines because of this change, especially where the new code could be split out.
- New conditionals bolted onto unrelated code paths.
- One-off booleans, nullable modes, or flags that complicate existing control flow.
- Feature-specific logic leaking into general-purpose modules.
- Generic "magic" handling that hides simple structure.
- Thin wrappers or identity abstractions that add indirection without simplifying anything — anything that fails the deletion test.
- A port, interface, or injection point with exactly one implementation behind it.
- A decomposition that lowers the line count while raising the number of entry points a caller must learn.
- An export, injection point, or widened visibility whose only consumer is a test.
- Copy-pasted logic instead of an extracted helper.
- Narrow edge-case handling implemented in the middle of an already busy function.
- Refactors that pass tests but make the code less modular or less readable.
- "Temporary" branching likely to become permanent debt.
- Bespoke helpers where the codebase already has a canonical utility for the job.
- Logic added in the wrong layer or package when it belongs somewhere more central.
- Sequential async flow where obviously independent work would be simpler run in parallel.
- Partial-update logic that leaves state less atomic than necessary.

## Preferred Remedies

- Delete a whole layer of indirection rather than polishing it, and let callers use what it wrapped.
- Collapse a single-implementation port back into the caller until a second implementation actually exists.
- Delete a test-only export and let the test exercise the behavior through the public entry point.
- Reframe the state model so conditionals disappear instead of getting centralized.
- Change the ownership boundary so the feature becomes a natural extension of an existing abstraction.
- Turn special-case logic into a simpler default flow with fewer exceptions.
- Extract a helper or pure function.
- Split a large file into smaller focused modules.
- Move feature-specific logic behind a dedicated abstraction.
- Replace condition chains with a typed model or explicit dispatcher.
- Separate orchestration from business logic.
- Collapse duplicate branches into a single clearer flow.
- Delete wrappers that do not meaningfully clarify the API.
- Reuse the existing canonical helper instead of introducing a near-duplicate.
- Move logic to the package, module, or layer that already owns the concept.
- Parallelize independent work where that also simplifies the orchestration.
- Restructure related updates into a more atomic flow where partial state would be harder to reason about.

Do not settle for "maybe rename this" when the real issue is structural. Do not settle for a cleaner version of the same messy idea when there is a plausible path to a much simpler idea.

## Verify Before Reporting

The characteristic failure of a structural review is a confident finding whose remedy does not survive contact with the code. Confirm all four before reporting:

1. **It exists.** Re-read the cited location; the construct really does what you say.
2. **It is in scope.** The change introduced it or made it load-bearing.
3. **The remedy preserves behavior.** Walk it against the call sites, types, and tests it touches, and name anything that would have to change with it.
4. **The remedy is actually simpler.** Run the deletion test on it: state what it removes — branches, concepts, layers, parameters, entry points — and what reappears in the callers. A remedy that only relocates complexity is not a finding, and one that shrinks the implementation while growing the interface is a regression.

Mark each surviving finding **CONFIRMED** when all four hold, or **PLAUSIBLE** when the defect is verified but the remedy needs a design decision — then say what the open question is. Drop failures of 1 or 2 silently. A failure of 4 is not a finding.

## Project Overlay

A project can add its own structural standards. Read the first that exists and treat its rules as additional numbered standards at full strength:

- `<repo root>/.agents/code-structure-review-overlay.md` — shared with everyone working on the repo
- `code-structure-review-overlay.md` in your personal agent config directory (`~/.claude/`, `~/.codex/`, or your harness's equivalent)

Overlays live outside the skill directory because skill updates replace that directory wholesale. They name a codebase's own layers and ownership rules — the things this skill can only describe generically. If none exists, review with the standards above and do not mention the overlay.

## Output

Prioritize: structural regressions, then missed simplifications, then spaghetti and branching growth, then layer and ownership problems, then file size and decomposition, then legibility.

```
path/to/file.ts:42  [CONFIRMED|PLAUSIBLE]
what the defect is, and the consequence for whoever reads or changes this next
remedy → what to do, and what it deletes
```

Then a one-line tally: findings by verdict, plus any out-of-scope notes.

Prefer a small number of high-conviction findings over a long list of cosmetic notes. If the change is structurally sound, say so in one line. Do not manufacture findings.

## Do Not

- Do not edit, stage, or commit. Report only, even where this skill says "push hard for" something.
- Do not report identifier names or comment wording. Raise a name only where it is evidence the abstraction behind it is wrong — and then the finding is the abstraction.
- Do not report pre-existing structure as a finding.
- Do not propose a restructuring you have not walked against its call sites.
- Do not soften a major maintainability issue into a mild suggestion. Be direct and demanding without being rude. If the change makes the codebase messier, say so plainly.
