---
name: test-review
description: "Review the tests a change adds or touches on three axes: assertions that cannot fail, assertions weaker than they should be, and tests coupled to internals rather than the interface. Report-only unless --fix. Use for /test-review, or as the test reviewer in a code-carve roster."
argument-hint: "[path|commit|range|branch|PR#] [--fix]"
---

# Test Review

Three defects, in the order they matter:

1. **Tautology** — the assertion cannot fail, so the test is green forever.
2. **Incompleteness** — the assertion can fail, but passes over regressions a stronger one would catch.
3. **Coupling** — the assertion is strong and meaningful, but written against internals, so it breaks every time the implementation is improved.

The first two decide whether a test catches bugs. The third decides whether the codebase stays safe to change. Fix a tautology before bothering to strengthen a subset assertion — there is no point tightening an assertion that was never load-bearing.

## Target

Scope comes from `$ARGUMENTS`: a path, commit, range, branch, or PR number; empty means uncommitted changes plus the current branch's diff vs its base. For a single commit, compare against its first parent. `--fix` anywhere in the args applies findings after reporting; otherwise report only.

Review **test files only** — `*.spec.*`, `*.test.*`, `__tests__/**`, and the project's equivalents. Never flag production code. Report only tests the change added or touched; a pre-existing test elsewhere is out of scope, and when one genuinely blocks reading a new one, say so as a note.

## 1. Tautology

Flag any assertion whose outcome does not depend on the code under test. A tautological test is worse than no test: it manufactures confidence and survives real regressions untouched.

**a. Asserts the mock, not the code** — the expected value is exactly what a stub was told to return, so the assertion verifies the test's own setup.

```ts
// FLAG — repo.get is stubbed to return `user`, then we assert we got `user` back
repo.get.mockResolvedValue(user);
const result = await service.load(id);
expect(result).toEqual(user); // passes even if service.load ignores repo entirely
```

**b. Recomputes the expected value with the production logic** — the expected side is derived by calling the same code, or a copy of its formula, so both sides move together.

```ts
// FLAG — expected mirrors the implementation; a bug in the impl is a bug here too
expect(formatName(u)).toBe(`${u.first} ${u.last}`);
```

**c. Constant against itself** — no code under test is exercised: `expect(true).toBe(true)`, `expect(STATUS.OK).toBe(STATUS.OK)`, `expect(x).toBe(x)`.

**d. Asserts a value the test just constructed** — equality-checking or snapshotting data the test set up, not anything the subject produced or transformed.

**e. Pass-through with no transformation** — asserting a mock was called with arguments the test handed straight through, where the subject does nothing to them. This verifies wiring the type system already guarantees.

**f. Assertion that may never run** — an `expect` inside a callback, `.then`, `catch`, loop, or `if` that can be skipped, with no assertion count, `expect.assertions(n)`, or reached-flag guaranteeing it fired. A test that silently runs zero assertions is tautologically green.

Recognise these across matcher styles and frameworks: `toBe`/`toEqual`/`toMatchObject`, `assert.equal`, chai `expect().to.equal`.

**The bar.** Confirm the assertion's truth does not depend on the behavior under test. If you can name a plausible implementation bug the assertion *would* catch, it is not tautological — leave it.

- **Mock-return checks** are fine where the subject *transforms* the stubbed value — maps, filters, wraps it. Flag only where it returns the stub unchanged.
- **Round-trips** (serialize→deserialize, encode→decode) may legitimately reference both directions. They test that the pair is inverse, not a value against itself.
- **Golden constants** written by hand — a known hash, a fixed formatted string typed out literally — are the point, not the defect. Computing the expected value with the subject's own logic is the defect; writing it down is the fix.

## 2. Incompleteness

Default to a **single whole-object equality** (`toEqual`, or `toStrictEqual` where the suite distinguishes `undefined` keys and class instances) whenever a test inspects an object. A whole-object match is strictly stronger: it also fails on a stray or dropped attribute that a field-by-field or subset check silently ignores.

**a. Field-by-field** — two or more assertions each reading a different field of the same object.

```ts
// FLAG — three reads of one object, subset only
expect(version.data?.manifest).toEqual({ prototype: "s3-v1" });
expect(version.data?.triggeredBy).toBe("orchestrator");
expect(version.data?.cascadeId).toBe("cascade-1");
```

**b. Subset match** — a single `toMatchObject`, `objectContaining`, or partial `toEqual` listing some attributes where the object's full shape is knowable.

Both take the same fix: one equality on the whole object, listing **every** attribute it actually carries. Read the type, schema, or producer so the proposal is complete rather than the old subset plus a guess.

**The bar.** A subset assertion needs justification to survive. Confirm all of these before flagging; if any fails, the subset form is justified — leave it and say why.

- **Same object.** The asserted fields all belong to one value, not several.
- **Fully determined.** Every attribute is knowable and stable in the test: ids injected or deterministic, timestamps from a fixed clock, no `Date.now()`, randomness, or auto-generated values leaking in. Where some fields are nondeterministic a whole-object equality is simply wrong.
- **Completeness is desirable here.** Catching unexpected attributes has to be the point. Where a test deliberately asserts a subset of a large or open-ended object — an API response with volatile metadata — that subset is intentional, not a defect.

## 3. Coupling

A test that must change when the implementation changes is testing past the interface. It is usually correct today and still a defect, because it is what turns a behavior-preserving restructuring into fifty test edits — and a codebase whose tests punish improvement stops getting improved.

Flag:

- Assertions on internal state, private fields, or module-private helpers rather than observable outcomes.
- A test reaching through a seam that no caller crosses, or importing an internal module to exercise it directly when the public entry point covers the same behavior.
- Mock assertions pinning the exact sequence of internal calls, where the outcome is what matters. Verifying *that* a collaborator was called can be legitimate; verifying the order of three private steps is a reimplementation of the code in assertion form.
- A duplicate layer: a shallow module's unit test retained alongside a test at the interface that already covers the behavior. Delete the inner one.

**The test to apply:** if this test had to change when the implementation changed but the behavior did not, it was testing past the interface.

The remedy is always to move the test out to the interface a caller uses, and delete the one that reached inside. Where the test can only reach the behavior through an internal seam — because the seam exists purely so a test can get in — that is a production-code defect and belongs to `code-structure-review`. Report it here as a note naming that handoff, and do not restructure production code yourself.

## A Sound Test Can Be Evidence About the Code

Sometimes a test asserts an outcome the production code should probably not produce. None of the three axes has anything to say about it: the assertion can fail, it covers the whole object, and it is written at the interface.

Do not resolve that doubt here, in either direction. Loosening the assertion deletes the only record of what the code does, and rewording the production doc comment so the two agree makes the documentation consistent with code that may be the defect. Both read as tidying and both bury the question.

Report it as a note handing it over — to `error-path-review` where it is an error whose message names one of several items that satisfy one condition, or to the project's correctness review otherwise. The giveaway is an expected value that reads as a single-cause answer where the condition under test can hold for several items at once: one id, one filename, or the word "first" in the assertion, the test name, or the doc comment it was written from.

Write the note as a **question with evidence**, not an impression, because a hunch is what a receiving reviewer is entitled to drop:

```
handoff → <addressee>
path/to/file.test.ts:28  the assertion, quoted
the doubt → stated as a question about the behavior, not about the test
evidence → the concrete input where two or more items satisfy the condition at once
```

Without that input the note is speculation; drop it rather than send it.

## Verify Before Reporting

1. **It exists and is in scope.** The change added or touched this test.
2. **A tautology finding genuinely cannot fail.** Name the implementation bug it would miss.
3. **A completeness finding's proposed object is complete and deterministic.** Name what makes it stable — fixed clock, injected ids.
4. **A coupling finding names the interface** the test should be written against, and confirms that interface already reaches the behavior.
5. **A handoff note names the concrete input** where two or more items satisfy the condition the test pins at once. This is the same bar the receiving reviewer applies.

Where practical, prove the finding rather than asserting it: a proposed assertion should **fail against a deliberately broken implementation**, and a proposed whole-object equality should pass against the real one — a green run confirms the shape is exact. Say which proposals you checked this way and which you did not.

Mark each surviving finding **CONFIRMED** when verified, or **PLAUSIBLE** where the defect is real but the remedy needs a decision.

## Output

Report tautology findings first, then incompleteness, then coupling. Per finding:

```
path/to/file.test.ts:42  [TAUTOLOGY|INCOMPLETE|COUPLED]  [CONFIRMED|PLAUSIBLE]
current → the offending assertion, quoted
why it fails → one line: what makes it unable to fail, what it misses, or what it couples to
proposed → the assertion that would break if the behavior broke
```

Then a one-line tally by axis, plus any out-of-scope notes, any **seam handoffs** to `code-structure-review`, and **any handoff notes** under "A Sound Test Can Be Evidence About the Code", each with its `path:line`, its addressee, the doubt as a question, and the input that evidences it. A handoff note is not a finding and carries no verdict, but it is the one item in this report whose whole purpose is to be read by someone else — leave it out of the tally and nothing downstream knows it exists.

If the change's tests are sound on all three axes **and no handoff note is open**, say so in one line. Where the axes are clean but a note is open, say that instead: the tests are sound and the behavior one of them pins is in question. Never report "the tests are sound" over an open note.

Do not manufacture findings.

## Fix Mode

With `--fix`, apply the findings after reporting, then run the affected tests and report the result faithfully, including failures.

- Touch test files only. A fix that needs production code to change is not applied — it is a handoff.
- A rewritten assertion must be the one reported, not a softened version.
- Never weaken a test to make it pass. If a strengthened assertion fails, that is a finding about the code, not a reason to revert the assertion — report it.
- Never delete a test to resolve a finding, except the duplicate-layer case in **Coupling**, where the interface-level test demonstrably covers the same behavior.

## Do Not

- Do not flag production code, and do not edit it in fix mode.
- Do not add tests for coverage. This review judges the tests the change brought, not the ones it didn't.
- Do not report a pre-existing test as a finding.
- Do not propose an assertion you have not checked against the object's real shape.
- Do not settle a doubt about whether the behavior under test is right by loosening the assertion or rewording a production doc comment. Hand it over as a note.
