# Evidence and severity

## Finding acceptance gate

Keep a finding only when all questions have concrete answers:

1. **Scenario:** Which valid input, persisted state, configuration, or concurrent interleaving reaches the problem? Name conditions; do not assume arbitrary corrupt data unless the changed boundary must handle it.
2. **Path:** Which real entry point, producer, adapter, query, mapper, and consumer execute? Types and comments alone do not prove runtime values.
3. **Violation:** What observable behavior differs from the intended contract? Source the expectation from requirements, tests, callers, established behavior, or a documented external contract.
4. **Patch link:** Which changed line creates or exposes the violation? Compare the base. Untouched consumers can be affected by a changed shared helper, schema, or contract; explain that causal link.
5. **Impact:** What fails, for whom, how often, and with what recovery cost? Separate known reach from possible reach.
6. **Disconfirmation:** Which guard, alternate path, compatibility layer, cache refresh, or retry could prevent it? Inspect the relevant implementation before claiming absence.
7. **Action:** Can the author address it with a bounded change? Suggest the invariant to restore, not a speculative rewrite.

If the intended behavior cannot be established, ask a targeted question. Do not present a disputed requirement as a confirmed bug. Do not report preexisting issues merely because their files appear in the diff; a proven new exposure, larger blast radius, or loss of a previous safeguard is in scope.

## Evidence strength

- **Reproduced:** executed the relevant revision with a representative input and observed the violation. State mocks, runtime, commands, and limits. A hand-rewritten approximation is an illustration, not an execution of the implementation.
- **Statically established:** the traced path and deterministic runtime/framework behavior prove the violation. Cite source locations and the reachable condition. A reproduction is useful, not mandatory for every clear bug.
- **Unresolved:** plausible but missing a contract, runtime fact, or reachable path. Keep out of confirmed findings; mention only if material to the verdict, with the exact missing evidence.

Use confidence separately from severity. High-impact speculation is not P0. Do not assign percentage confidence without a calibration method. If evidence is insufficient for a confident claim, investigate further or label the uncertainty.

## Impact-based priority

| Priority | Meaning | Typical supported example |
| --- | --- | --- |
| P0 — critical | Broad or immediate severe damage; block release until addressed | Unconditional loss of durable financial records; systemic authentication bypass |
| P1 — high | Substantial failure on a supported path; fix before merge | Coupon application crashes for every coupon with expiry; an ordinary retry can duplicate a payout |
| P2 — normal | Bounded functional regression or demonstrated meaningful operational cost | Manual report drops its final day; an added N+1 query measurably degrades a requested listing |
| P3 — low | Small but real, actionable correctness or maintainability cost | A misleading public contract causes a limited caller error with straightforward recovery |

Assess reach, likelihood under supported use, financial/security consequences, recoverability, and existing mitigation. A rare scenario can still be severe if its impact is irreversible. Architecture, observability, performance, and missing tests receive priority only through a demonstrated failure mode or explicit acceptance criterion.

Style, preferred patterns, function length, commit size, commit intervals, coverage percentages, and title tags are not severity signals by themselves. Do not infer developer competence, effort, working hours, push times, or validation habits from commit history.

## Verification that can reveal the bug

- Test the public entry point with the raw representation production supplies: HTTP payload, ORM result, queue JSON, cache record, or API response rendered into an interactive component.
- Keep real serialization/hydration when it is the disputed boundary. Mocking that boundary with the expected final object hides the failure.
- Exercise success and relevant failure paths: nullability, day/month boundaries, old/new formats, partial commits, retries, and concurrency where affected.
- Assert independently derived expected behavior. Calling the same helper to compute actual and expected values only establishes wiring, not the helper's correctness.
- Inspect existing tests before alleging missing coverage. A missing test is not itself a product bug. Report a separate test gap only when it leaves a specific critical invariant unverified or violates explicit acceptance criteria; otherwise include the proposed regression case with the finding.
- Never remove, skip, or weaken tests to make checks pass. Do not demand arbitrary coverage thresholds unless the project explicitly requires them.
- Inspect current CI checks and their tested revision. A PR description claiming tests passed is author-reported evidence, not a run observed by the reviewer.
- For UI claims, distinguish component logic tests from real browser rendering and interaction. A DOM-only test cannot establish layout, and a screenshot cannot establish keyboard/focus behavior. Report the tested route, state, viewport, and revision when these determine the finding.

## Compact finding format

```text
[P1] Normalize nested coupon expiry before applying the discount
Location: repository/path.ts:27-30 at reviewed SHA
Scenario/path: DATEONLY string -> offer -> product -> coupon -> public execute().
Impact: ordinary dated coupons throw TypeError instead of applying.
Evidence: reproduced with the actual hydration chain; DB I/O mocked.
Direction: normalize the association boundary and cover it through execute().
```

Choose the smallest useful changed line range as the anchor. Cite untouched consumers as supporting evidence. Do not attach a finding to an unrelated changed line merely to obtain an inline comment; use a review-body finding when no honest inline anchor exists.
