# Session record — schema and field rules

The shape of `session.json` and what each field means. Read this before the first write, and again when you reach a field you have not written before.

The session directory and when to write are in **Session record** in `SKILL.md`; this file is the schema only.

```json
{
  "schemaVersion": 1,
  "unitOfWork": "", "issueUrl": null, "mode": "supervised | unsupervised",
  "repo": "", "branch": "", "baseSha": "",
  "config": { "code-review": "", "clarity-review": "" },
  "startedAt": "<ISO 8601>", "updatedAt": "<ISO 8601>", "endedAt": null,
  "status": "in-progress | done",
  "questions": [
    { "phase": "implementation | round-<n> | verification", "askedBy": "impl",
      "question": "<verbatim>", "answer": "<verbatim>", "answeredBy": "user | shepherd" }
  ],
  "rounds": [
    { "n": 1, "kind": "code-quality | clarity | verification", "skill": "",
      "shaBefore": "", "shaAfter": "", "tests": "<pass/fail + command>",
      "cancelled": false, "scopeNote": null,
      "findings": [
        { "id": "<round>.<index>", "short": "", "severity": null, "finding": "<verbatim>",
          "implRecommendation": "accept | reject | modify", "implReason": "<verbatim>",
          "decision": "accepted | rejected | modified | deferred", "decidedBy": "user | shepherd",
          "defectScope": "instance | class | class-declined | null", "sweptSites": null,
          "reason": "", "escalated": false, "reraiseOf": null, "revisit": false }
      ] }
  ],
  "stopReason": "clean | thrash | disproportionate | user-requested | cap",
  "retro": {
    "skill": "session-retro",
    "skipped": false,
    "skipReason": "no-retro-flag | skill-not-installed | unusable-output | null",
    "ranAt": "<ISO 8601> | null",
    "findings": [
      { "id": "retro.1",
        "category": "process", "proposedCategory": false,
        "short": "", "finding": "", "evidence": "", "cost": "",
        "target": { "repo": "", "artifact": "" },
        "proposedAction": "issue",
        "decision": "accepted | rejected | deferred | null",
        "decidedBy": "user | shepherd | null", "reason": "" },
      { "id": "retro.2",
        "category": "<coined kebab-case slug>", "proposedCategory": true,
        "short": "", "finding": "", "evidence": "", "cost": "",
        "target": { "skill": "", "artifact": "" },
        "proposedAction": "issue",
        "decision": null, "decidedBy": null, "reason": "" }
    ]
  },
  "outcome": { "finalSha": null, "pushed": false, "pr": null,
               "trackerChanges": [ { "action": "comment | edit | create", "title": "", "url": null, "status": "proposed | done | declined" } ] }
}
```

## Findings

- `short` is what a later reviewer receives as an already-decided finding, so write it as a claim about a place: "the `!isReady(first)` re-check at `manifest.ts:42` is redundant", never "`parseManifest`" or "the manifest parser".
- `reason` is yours to author, and it is read by the Impl agent as an instruction. Write it to say *which* defect to fix and how far to go — not as finished prose that can be pasted into the file under review. A reason written in the artifact's own register tends to arrive in the artifact almost verbatim, and then it is the next round's finding, authored by the shepherd and read by nobody before it landed.
- `reraiseOf` is the `id` of an earlier finding this one repeats or reverses; set it whenever you spot one, since it is how thrash shows up in the record. Point it at a **finding** id. When the thing this finding follows from was a question rather than a finding, leave it `null` and name the question in `reason` instead — a link to the nearest-looking finding makes the chain unreconstructable, which is worse than no link.
- `defectScope` records the **Class findings** call: `instance`, `class` (swept — list the sites in `sweptSites`), or `class-declined` (a class narrowed to one site on purpose, with the reason in `reason`). It is `null` for a finding that was not accepted. A `class-declined` entry is passed to later reviewers like any other decided finding, so the narrowing is visible rather than re-raised.
- `revisit` marks a rejected or deferred finding worth coming back to.

## Rounds

- `cancelled` on a round means the rounds were stopped while that round was in flight. Its findings are whatever had arrived — set `revisit: true` on all of them, leave `implRecommendation` and `decision` as they stand, and say in `scopeNote` what had and hadn't reported. **A cancelled round's finding count is not comparable to a completed round's**, and `scopeNote` is also where to say when a round was deliberately scoped differently from a fresh sweep.
- `stopReason` is the cause the rounds ended, and the five values are not interchangeable — the retro keys on it. `clean` is a round that produced nothing actionable. `thrash` and `cap` are as **Code quality rounds** describes. `disproportionate` is a stop under **Proportionality**. `user-requested` is the user stopping the rounds for any other reason. A stopped session recorded as `clean` tells the retro the loop converged when it did not; if none of the five fits, use the closest and say why in the round's `scopeNote` rather than inventing a sixth value.
- Verification has no findings of its own; record it as a round with its result in `tests` and any bugs it found as accepted findings.

## Retro

- `retro` is always written, even when the retro is skipped, so the record says the retro didn't run rather than leaving it unanswered. A skip is exactly `"skipped": true`, `"ranAt": null`, an empty `findings` array, and one of three `skipReason` values — `no-retro-flag` (the user passed `--no-retro`), `skill-not-installed`, or `unusable-output` (it ran but returned nothing you could record). Those three are the whole set; `ranAt` carries a timestamp exactly when `skipped` is false. **A retro that ran and found nothing is not a skip**: it is `skipped: false` with an empty `findings` array, and the report says so differently. Write the block as soon as the retro agent returns (or as soon as you know it is skipped), set `updatedAt`, and write it again once the findings are decided.
- `target` is one shape or the other, never both keys: `{ "repo", "artifact" }` for an artifact in the work repo, `{ "skill", "artifact" }` for one inside a skill that isn't — the second entry above shows that arm. The tracker step branches on which key is present, so copy whichever the retro sent rather than normalising it.
- Between the retro returning and its findings being decided in **Done**, `decision` and `decidedBy` are `null`: that is the state the record is written and rendered in, so they are nullable rather than absent.
- `retro.findings` come back from the retro as JSON, in rank order; store them in that order, which is what the `#` column and each `retro.<n>` id mean. Copy the retro's fields across unaltered — `reason` is the one field you author, and the rule below binds it.
- The retro's fields are the exception to recording verbatim text: they must contain no quoted finding, answer, tool output or file contents — see **Session retro**. That includes the `reason` you write when deciding one.
