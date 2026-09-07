# VERIFY

The [builder](../agents/spec-ops-builder.md) owns the TDD loop; the [reviewer](../agents/spec-ops-reviewer.md) owns findings. The main session owns acceptance, retries and final validation. Use those contracts INLINE too, with bookkeeping reserved to the session.

## Mechanical checks

Run commands from the worktree root after writers settle. The dispatcher runs each distinct full gate serially and updates the checkpoint with command, exit code and inspected scope. Apply [control C6-C10](control.md#decision-matrix), including the distinction between exit 0 and relevant observed coverage.

```bash
.specs/bin/spec-gate.sh gate "<literal command>"
.specs/bin/spec-gate.sh honesty <starting-commit>
.specs/bin/spec-gate.sh boundary <feature-dir> --ticket <ticket> --since <snapshot>
.specs/bin/spec-gate.sh spec <feature-dir>
.specs/bin/spec-gate.sh tickets <feature-dir>
```

For a wave, repeat `--ticket` for every member. For quick lane, use explicit `--where` instead and omit spec/tickets checks. Follow [execute.md](execute.md)'s initial/current snapshot rule across repairs.

`honesty` checks explicit disable markers and test-file deletions in both index and worktree against the given commit, including untracked tests. It is not proof against weakened assertions, all framework-specific skips, or changes to discovery configuration; review those. Snapshot boundary proves changed paths outside `.specs/`, not process attribution or absence of live external effects. Any inspection error blocks advancement.

## Review and repair budget

Prefer a fresh reviewer context. If none is available, review inline and report `independent review: not run`. Supply the entire ticket/wave list, applicable spec contracts, scoped diff evidence and gate results. A reviewer needs enough code context to investigate a finding, not just worker summaries.

Control C6/C7 and its [shared budget](control.md#repairs-and-state) decide continuation versus repair/exhaustion. Record `med`/`low` in Carried debt; do not upgrade cosmetic preferences into blocking findings. Keep scoped repairs in the original ticket; new-scope fixes stay in this feature with inherited history. Late maintenance follows its same-unit procedure in execute.md. After repairs, rerun gate/boundary/honesty and review the fix, updating the checkpoint from actual results.

Record justified divergence as `SPEC_DEVIATION: <what>; Reason: <why>` using the language's comment syntax, or ticket Notes when comments are unsuitable. Review and handover must account for it; a marker is not approval to change a frozen contract.

## VALIDATE

Complete only when the full gate passes, FR evidence is accounted for, required UAT has been observed, and debt is triaged. Otherwise report validation incomplete, not Done.

1. **Full gate:** discover the project's required checks from instructions/config/scripts: typecheck, lint, formatting, full suite, coverage and applicable translation checks. Run through `gate` on a stable tree; no subset silently substitutes for the complete gate. Recheck honesty, spec and tickets too.
2. **Traceability:** produce the table below. Check actual behavior against sourced acceptance examples, not merely `Implements:` or source-field presence. Distinguish observed results, implementation inferences and assumptions. Revisit unresolved defaults, unverified FRs, frozen contracts and deviations under control C8/C11.
3. **Composition:** for user-facing work, exercise the assembled flow, initial state, transitions, controls and smallest supported viewport using the declared real environment. Check visual fidelity against the design when supplied. A DOM-only test is not evidence for layout or browser behavior it cannot observe.
4. **UAT:** walk the union of ticket `UAT:` boxes. For owner-operated checks, give one action and expected result, then wait for confirmation. For tool-operated checks, record the observed result and evidence. Unreachable environments leave boxes unchecked. An empty UAT union is valid only if the declared automated seams cover all required behavior, including applicable visual/browser checks.
5. **Debt:** present deferred findings with impact and cost; let the user choose fix now, follow-up ticket or explicit acceptance. Required checks and high findings cannot silently become accepted debt.
6. **Handover:** use [execute.md](execute.md)'s report. Move a tracked feature to Done only when completion criteria hold. Never commit automatically.

| FR / example | Ticket(s) | Seam | Expected-result source | Observed evidence / command | Status |
| --- | --- | --- | --- | --- | --- |

Prefer an existing app instance. If absent, use a documented safe start command only when project policy permits; use an available port and never kill or replace someone else's process. With no browser/device capability, report the relevant checks `not run`, rather than substituting class assertions. UAT failures return to the same bounded repair loop; exhausted budgets require owner direction.
