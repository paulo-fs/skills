# EXECUTE

Complete when every selected ticket passes its acceptance checks and review, state matches evidence, and the uncommitted result is reported. A failed ticket is a reported stop, not successful delivery. Feature completion additionally requires [VALIDATE](verify.md).

## Preparation

1. Resolve the Git worktree root, read repository instructions, and check the installed runtime. Read [control.md](control.md); select mode/backend by its policy and initialize or corroborate the existing checkpoint. On resume, apply its ordered state transition before continuing: for a confirmed ended, unfinished attempt, persist `Status: ready` as reconciliation before the INLINE/dispatch loop sets `dispatched` for new ownership. Do not collapse that handoff into the inherited status. Live/unknown writers, terminal failures and completed implementations awaiting review follow their other control rows instead.
2. Load the ticket, its `Implements:`/`UAT:` FRs and applicable seams, frozen contracts, decisions, and `Reads:`. Read the [builder contract](../agents/spec-ops-builder.md) and, for `Class: critical`, its [critical supplement](../agents/spec-ops-builder-critical.md) in either mode. Investigate pre-existing failures; do not silently accept or fix unrelated work.
3. Before the first code write, create the feature directory if needed and run `snapshot <feature-dir>/.baseline`. Reuse existing baselines on resume. No initial commit means honesty cannot run: report the blocker, never create a commit to bypass it.
4. Before each attempt, create `<feature-dir>/.boundaries/` if absent and snapshot to `<feature-dir>/.boundaries/NN-attempt-M.snapshot` (or `wave-N-attempt-M.snapshot` there). Update the [checkpoint](control.md#checkpoint) with the actual paths before writing; preserve its original references/history.

Snapshots preserve dirty worktree content, modes and index fingerprints under Git's `spec-ops/` recovery directory, without staging. They are not a full backup of ignored files or all index versions. Dirty submodule/directory records are unsupported and return exit 2; never ignore them to proceed. `.specs/` is excluded from mechanical boundary checks; its protection comes from session ownership. Never restore snapshots automatically.

## INLINE loop

Run one unblocked ticket at a time, in dependency order:

1. Set `Status: dispatched` before implementation. In INLINE this means the current session owns an incomplete attempt, including pending review.
2. Build using the ticket's TDD mode and scope. The main session also owns bookkeeping: it may write tickets, snapshots, evidence and INDEX under `.specs/`. That is not a delegated builder's permission and does not widen code scope.
3. With writes settled, run the checks below. Read the [reviewer contract](../agents/spec-ops-reviewer.md); use an independent reviewer when available, otherwise disclose self-review.
4. Apply control C6-C10 to continue, repair or accept; update the checkpoint from observed results. Use [verify.md](verify.md) for review and checks.
5. Reconcile before proceeding. For useful parallel work, replace this loop with [waves.md](waves.md), keeping the same completion criteria.

```bash
.specs/bin/spec-gate.sh gate "<literal ticket command>"
.specs/bin/spec-gate.sh honesty <starting-commit>
.specs/bin/spec-gate.sh boundary <feature-dir> --ticket <ticket> --since <snapshot>
```

Run every distinct literal gate serially on the settled unit. Exit 1 reports findings/failure; exit 2 reports a usage/inspection/environment error. Interpret results through control C1/C6-C10. Run boundary against the current attempt and initial ticket/wave snapshot after repairs so earlier scope violations cannot disappear into a new baseline.

For maintenance or later validated tickets between those snapshots, the original-snapshot check may include their recorded, individually verified scopes via additional `--ticket` arguments. First verify the previous attempt's boundary before permitting intervening work; never mask a failed boundary by retroactively widening it. The current-attempt check remains limited to its own ticket/wave. Keep this history when UAT reopens an earlier ticket.

## Shared work and quick lane

Package installation, codegen and shared test infrastructure are main-session work only, with all workers stopped. On a green tree, use a narrow maintenance ticket with `Where:`, prerequisites and a literal gate, executed INLINE with a fresh snapshot. On an incomplete tree, use Late maintenance below instead of introducing a prerequisite that cannot pass its gate. Never edit a shared stub merely to make a vacuous assertion pass. External effects still need action-scoped authorization.

Quick lane uses the same builder, TDD, review and boundary rules, with inline scope replacing a ticket. Keep unique snapshots and the canonical checkpoint in its existing `<run>.md` record under `.specs/.boundaries/`, alongside `Where:`. Use `boundary .specs --where <pattern> --since <snapshot>`. Carry that history into tickets if escalating to the full route; omit spec/ticket checks when those artifacts intentionally do not exist. Add an INDEX entry only in tracked mode.

### Late maintenance

The suspended ticket (or existing wave) remains the verification unit. Maintenance and resumed implementation run serially within it; no new status or dependency cycle is needed.

1. Confirm all writers stopped and check the previous phase's original scope before authorizing new work. Record the preserved TDD red and maintenance blocker. An unexplained failure is not permission to defer verification.
2. Keep maintenance in the suspended ticket: prospectively extend bounded `Where:`, update risk if needed, and refresh the checkpoint's phase/scope/evidence without resetting history. Revalidate tickets. If the scope cannot stay bounded, stop and replan. Never widen scope to excuse an earlier violation.
3. Take a fresh snapshot and execute only the maintenance phase as the main session. Run its local checks and boundary with explicit per-phase `--where` paths. Their success permits resuming implementation, not marking the ticket `done`; the full gate and acceptance boxes remain pending.
4. Snapshot again and resume implementation within its recorded phase paths. Require both `boundary --since <resume-snapshot>` with explicit implementation-phase `--where` paths and the original whole-unit boundary; the expanded ticket scope cannot authorize writes into another phase. These read-only checks may run together on the same settled tree, but both must pass before acceptance or further writes. In a paused wave, finish remaining phases serially until stable. Preserve the red test/history and require the unchanged full gate, honesty and review before closing any member or releasing external dependents.

If a separate maintenance ticket was already opened, verify its own boundary, mark it `superseded` with a link to the suspended ticket absorbing it, and carry its scope/evidence/attempts forward. On resume, use Notes to identify the completed phase; no live or uncertain writer may be redispatched. A missing full gate still means incomplete delivery, not accepted failure.

## Reconcile and resume

The main session owns ticket bodies, checkpoints, acceptance boxes, decisions and INDEX; a coordinator requests edits and waits for acknowledgment. Read the checkpoint first, corroborate evidence/handles against the actual tree, then apply [control's transitions](control.md#repairs-and-state). Missing or stale evidence requires revalidation, not a reconstructed success narrative. Record deferred findings in Carried debt and justified architectural changes in Decisions; never rewrite requirements to excuse an unapproved change.

## Handover

Report mode/backend, files changed, literal checks and exit codes, test/coverage delta, review independence, decisions made without asking, deviations, remaining UAT/debt and recovery paths. Inspect `git status --short` and `git diff HEAD`, and read untracked files separately: Git diff does not include their contents. Separate pre-existing work from this delivery. The user commits manually.
