# TICKETS - Vertical Slices

**Complete when:** tickets fit one session, follow dependency order, and pass `spec-gate.sh tickets` and `spec-gate.sh spec`.

## 1. Slice by behavior

A ticket is a **tracer bullet**: a narrow, complete path through its layers, independently verifiable, with its tests. Never defer testing or create unused layers as milestones.

Merge only cohesive work sharing an outcome. Same class and disjoint files do not justify merging unrelated behavior; useful independent parallel slices may stay separate. Split for dependencies, risk, scope or session size. Mechanical batches share one bounded transformation. Report material merge/split decisions.

If a wide refactor cannot stay green in one slice, use expand-contract: introduce the new contract, migrate bounded dependent batches, then remove the old form after all batches. Compatibility scaffolding requires a concrete migration need.

## 2. Ticket file - `.specs/features/<name>/tickets/NN-<slug>.md`

Example for `email-validation`, assuming these npm scripts form the full project gate. Replace paths, FRs and commands with repository evidence; retain all eight fields, selecting single enum values.

```markdown
# 01 - Reject blank email submissions

Blocked by: none
Where: src/accounts/submit.ts, src/accounts/submit.test.ts
Reads: none
Class: standard
TDD: red-green
UAT: none
Implements: FR-1
Status: ready

## What to build
Reject blank email at the existing account-submission boundary before persistence.

## Done when
- [ ] Blank email matches FR-1's sourced acceptance example without persisting an account.
- [ ] Valid submissions preserve existing behavior.
- [ ] gate: npm run typecheck && npm run lint && npm run format:check && npm test exits 0

## Notes
Spec context: FR-1 and its sourced acceptance examples; Seams under test; Frozen contracts; Implementation decisions; Testing decisions; applicable Decisions.
Local test: npm test -- src/accounts/submit.test.ts. Run concurrently only after confirming isolated test resources.
```

For `ratchet`, add `- [ ] test count >= <N> (ratchet)` with measured baseline and count/coverage commands in Notes. Each UAT FR needs `- [ ] UAT: FR-n - <action and expected result>`. Before execution add the [canonical checkpoint](control.md#checkpoint) inside Notes; do not create a second state file. Point acceptance checks at spec examples and sources instead of copying them into every ticket.

## 3. Field rules

- **`Where:`** is a narrow, explicit write boundary in both modes, including tests. Use comma-separated paths/bounded patterns; reject whole-tree patterns (`.`, `./`, `*`, `**`, `**/*`) in every list position.
- Exact paths match only themselves; trailing `/` includes descendants; `*`, `?`, `[]` use Bash patterns. `src/accounts/**` is bounded; `submit.ts` never authorizes `submit.ts.bak`.
- **`Reads:`** lists guideline paths or `none`; mandatory repository instructions still apply. Builders and reviewers load the ticket and relevant `Implements:`/`UAT:` FRs **plus applicable seams, frozen contracts, implementation/testing decisions and referenced decisions**, identified in Notes. Never FR-only context or unrelated spec sweeps.
- **`Class: scout | mechanical | standard | critical`** labels risk, not model tiers: read-only research; judgment-free, command-checkable work; ordinary implementation; costly-failure work (migrations, state machines, save/wire contracts), respectively. Default to `standard` when uncertain. Choose an available capable model at dispatch, never a prescribed provider/tier.
- **`TDD:` and `UAT:` are orthogonal.** Follow the table; new logic plus visual verification can require `red-green` and `UAT: FR-1`.
- **`Implements:`** names owned FRs; **`UAT:`** is `none` or hand/browser-check FR-ids. A green suite never closes UAT.
- **`Status: ready | dispatched | done | failed | superseded`** persists progress. Initialize `ready`; subsequent transitions and dependent release follow [control.md](control.md#repairs-and-state).
- **`gate:` requires the full literal project command**, not a label, variable or local-test shortcut. Keep it stable across tickets; control C6-C10 governs when the complete unit can pass it.
- Local tests belong in **Notes**, with their required fixtures/caches/services. Assess concurrency through control's backend/width policy, not `Where:` alone.

## 4. `TDD:` - the decision table

Assign here; [verify.md](verify.md) governs execution. Probes never replace behavior-driving red tests.

| Situation | Mode | Required evidence |
| --- | --- | --- |
| New logic at an observable, proven seam | `red-green` | Every behavior-driving test fails for the intended reason before implementation, then passes. |
| Bug fix, including a project currently without tests | `red-green` | Investigate and add an executable reproduction; observe red before fixing, then green. |
| Mechanical change with an existing suite | `ratchet` | No new tests required; existing suite, test count and coverage must not regress. |
| Behavior only a browser/hand check observes here | `ratchet` + `UAT:` | Preserve existing tests and walk the real seam; do not assert CSS classes as fake behavior coverage. |
| No suite and no feasible automated seam after investigation | `none` | Record `no-tests`, investigation and remaining verification in the plan; retain applicable build/lint checks and explicit UAT or accepted-unverified disposition. |

Missing tests never alone justify `none`, especially for bugs: investigate a minimal regression harness first. Unavailable tools mean **checks not run**, not a TDD downgrade. Never delete, skip, weaken tests or lower count/coverage baselines to pass. Report intentional expectation changes; frozen contracts still bind.

## 5. Edges

Ticket numeric IDs must be unique, including differently padded forms such as `01` and `1`. `Blocked by:` is `none` or comma-separated existing IDs using the filename's spelling, each lower than the current filename's ID. Dependencies precede dependents in both modes. Edges mean code cannot compile/run without the predecessor; demo order belongs in Notes. Overlapping writes/test resources require serialization even without code dependencies.

## 6. Validation

```bash
.specs/bin/spec-gate.sh tickets .specs/features/email-validation
.specs/bin/spec-gate.sh spec .specs/features/email-validation
```

Resolve findings before EXECUTE. Also inspect cohesion, spec context, dependency necessity, TDD fit, UAT ownership, full-gate completeness and concurrent scope/resources. Report checks not run; unchecked tickets are not validated.
