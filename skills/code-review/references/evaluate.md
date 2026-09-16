# Evaluate this skill

Use during skill maintenance, not as a mandatory PR checklist. Structural checks cannot establish reviewer accuracy. Run actual agent scenarios separately and retain the prompt, revision, tool trace, findings, and validation limits when collecting evidence.

## Trigger checks

Should trigger:

- "Faça code review dessas PRs, sem focar nas migrations."
- "Check my staged changes for regressions before merge."
- "Review this API change together with its consumer PR."
- "Review this React form for regressions and keyboard usability."

Should not trigger:

- "Implement the findings from the approved review." Implementation task.
- "Design a new billing architecture." Design task, not a diff review.
- "Explain what a pull request is." General question.
- "Format this file with Prettier." Formatting-only task.
- "Design a new responsive dashboard from this mockup." UI creation, not review of a change.

## Behavioral scenarios

Provide a small fixture diff plus the surrounding source, not the expected verdict, to the reviewer. The following expectations are for the evaluator. These are evaluation specifications, not claims of executed model tests.

| Scenario | Fixture | Expected behavior |
| --- | --- | --- |
| Nested hydration bypass | DATE becomes DATEONLY; standalone mapper parses the string; offer/product constructors bypass it; public execute calls a Date method | Trace the actual association path; report runtime failure; propose a public-path regression test |
| Calendar/instant mismatch | Producer sends end-of-day BRT as ISO; consumer persists UTC digits as DATEONLY | Demonstrate the adjacent-day error using producer evidence; distinguish normalized dates from instants |
| Manual/default divergence | DAO stops expanding dates; scheduled caller sends bounds; manual branch sends midnight | Detect the manual regression even if default-path tests pass |
| Shared connection change | Session switches to UTC; one changed report fixes labels but leaves naive daily predicates | Trace both query windows and buckets; tie untouched predicates to the changed connection |
| Post-commit outbox | Write and event intent commit atomically; worker delivers idempotently | Do not demand a new try/catch or claim event loss without disproving outbox recovery |
| Cascade recovery | Parent status flips early but durable per-child checkpoints drive retry | Recognize valid recovery; do not mechanically require parent-last |
| Intentional irreversibility | Documented permanent deletion with recovery policy | Do not demand an automatic inverse merely because a cascade exists |
| Dedicated CLI exit | One-shot operator command exits after awaited work | Do not apply a shared-scheduler process-exit rule blindly |
| Unrelated old defect | Unchanged bug exists in a touched file but patch does not expose or worsen it | Exclude it from PR findings |
| Cosmetic history | Large squashed commit, weekend gap, no title tags; no project rule | Produce no behavioral finding or author judgment from metadata |
| Unknown deployment | Main has a format change; deployed version is inaccessible | Do not claim main is deployed; establish conditional compatibility and name the gap |
| Concurrent edits | Local checkout differs from PR and contains user changes | Read pinned objects/API; do not reset, switch, overwrite, or create a worktree |
| Head/base drift | PR changes after review but before publication | Inspect the delta and revalidate or stop short of a stale current verdict |
| Lost API response | Review creation times out after server success | Query existing reviews before retrying; avoid duplicates |
| Publish and delete | Two of three requested publications succeed | Report partial success and retain the requested report until all succeed |
| Missing context | API truncates diff and source cannot be obtained | Disclose unreviewed scope; do not claim a complete clean review |

## Frontend and full-stack scenarios

Use the same broken/corrected-variant method. Supply the relevant framework/library version and API contract; provide an authorized reviewed build when browser evidence is necessary.

| Scenario | Fixture | Expected behavior |
| --- | --- | --- |
| Async selection race | A slow response for item A overwrites item B after selection changes | Demonstrate the ordering through the public component; recognize cancellation/request-identity guards in the corrected variant |
| Edit round-trip | API supplies an ISO expiry; date field reset/submit changes the calendar day without user edits | Trace API → field → resolver → payload; do not bypass the form transform in the reproduction |
| Dirty form refetch | New reset effect replaces unsaved fields when background data refreshes | Show the edit/refetch sequence and lost input; honor an explicit conflict policy |
| Tenant cache collision | Query key drops the selected company while the response depends on it | Trace context switch and cached result; inspect existing cache separation before claiming exposure |
| SSR mismatch | Server/client use different locale or time values for initial markup | Establish SSR execution and mismatch; do not flag a client-only route as a hydration failure |
| Reordered input identity | Editable rows change to positional keys and can reorder | Show values/focus following the wrong row; distinguish a stable stateless list |
| Dialog focus regression | Changed composition breaks the library default for focus restoration | Verify opening, keyboard use, dismissal, and restoration in the browser; inspect library behavior first |
| Narrow viewport clipping | Translated label causes a primary action to be clipped at a supported viewport | Require observed layout evidence tied to the reviewed revision; state the blocked action |
| Optimistic update failure | Failed mutation leaves a successful-looking balance after rollback was removed | Reproduce the error path and cache/UI state; check whether refetch guarantees recovery |
| Duplicate submit guard | Repeated submit is protected by pending state and server idempotency | Do not demand speculative additional guards or claim duplicate writes without tracing both protections |
| Unnecessary memoization | Correct inexpensive render has no useMemo/useCallback | Report no performance defect without measured cost or a violated explicit budget |
| Browser unavailable | Source suggests possible overflow but no reviewed app can be run | Retain proven logic findings; mark layout/focus unverified and do not fabricate visual evidence |

## Evaluation method

1. Build isolated fixtures with explicit intended behavior and both broken and corrected variants. Keep them separate from the user's working tree.
2. Run the same review prompt against each variant with the model and tool setup recorded. Include multi-repository, local staged-only, frontend-only, and full-stack cases. Verify reference routing; frontend-only work should not load irrelevant backend lenses.
3. Score root-cause detection, false positives, path/evidence accuracy, severity calibration, adherence to exclusions, and tool side effects separately. Do not reward finding count.
4. Require no findings for the relevant corrected/negative variants. A reviewer that flags the same issue in both variants has not demonstrated discrimination.
5. Inspect traces: did the reviewer follow real consumers, distinguish observed tests from CI, tie browser evidence to the reviewed build, and verify publication? A plausible final explanation alone is insufficient.
6. Repeat on representative unseen changes before claiming general improvement. Publish actual counts and failure cases, not a blanket "validated" label.

## Structural validation

From the skill repository root, run:

```sh
python3 skills/code-review/tests/validate.py
```

This checks the skill's frontmatter conventions, main-file budget, local Markdown links, and basic document hygiene using only the standard library. It does not run LLMs, test application behavior, or measure review quality.
