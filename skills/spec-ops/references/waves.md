# WAVES

Use only after [control's backend/width policy](control.md#backend-selection) selects useful parallel execution. Native subagents, a configured CLI or a canvas may transport the same roles; this file verifies and operates the selected transport, not a competing selection policy.

## Preflight

Read the installed backend's documentation/help and record concrete answers before launch:

| Capability | Required evidence |
| --- | --- |
| Dispatch and identity | How to start concurrent workers with the correct role and resolve their handles |
| Context | How role instructions, repository instructions, tickets and applicable contracts reach each worker |
| Permissions | Whether scoped edits and required commands can run; how blocked approval requests reach the user |
| Completion | Exact report/event mechanism each role can access, including a read-only scout |
| Liveness and stop | How to distinguish running, waiting, exited and crashed; how to cancel and confirm no remaining writers |
| Isolation | Fresh context between unrelated tickets; command output paths, ports and test resources do not collide |

Do not assume terminal idleness proves write permission, a CLI invocation is stateless, a transcript becomes an event automatically, or a role's prose creates a sandbox. Never bypass approval prompts or broaden permission grants. If a read-only worker cannot send the required completion event, use a supported returned-message adapter or do not dispatch it there.

Use the host's least-privilege controls: read-only investigation for scouts; read-only review plus explicitly permitted serial checks for reviewers. If role scope cannot be enforced by the host, disclose that it remains an instruction, not a sandbox; do not claim equivalent isolation.

For named agents, install only a compatible schema; otherwise pass the role body directly. Models and tool bindings come from the host's available capabilities, not ticket classes. For critical work, load both the critical supplement and the builder contract. Project-specific knowledge belongs in `Reads:`, not another agent definition.

## Plan the batch

The main session validates dependencies, ticket bodies, full gate commands and external-effect authorization before scheduling. Supply the coordinator the resolved control-policy path/body and reviewed checkpoint, not just headers; it must not infer command safety from scheduling data.

Apply control's independence test to unblocked tickets and their local commands. Builders run only approved local TDD checks; the dispatcher serializes full suites, builds and coverage after writers stop. Snapshot the batch and update its [checkpoint](control.md#checkpoint) before dispatch, including actual handles as they become available.

## Dispatch inputs

Give builders one ticket path, the role contract location/body, the project root, mode, safe local commands and any action-scoped authorization. Header fields need not be copied. Provide a working report mechanism and the wave's remaining repair budget.

Give the reviewer the complete batch, not a single representative ticket:

```text
Tickets: <all paths in this wave>
Scope: <original/current snapshots, changed paths, before/after diff evidence>
Contracts: <applicable FRs, seams, frozen contracts, decisions, Reads>
Checks: <literal commands, exit codes, inspected scope>
Repairs: <round, remaining budget, unresolved findings>
Report: <supported completion channel>
```

Use each snapshot's recovery copies for previously dirty content, the recorded starting commit for initially clean tracked paths, and inspect new files separately. A snapshot manifest alone is not a diff. The main session prepares before/after evidence when the backend cannot. Include integration context without attributing earlier unrelated changes to this wave.

## Supervise and settle

1. Launch the planned batch and wait through its supported completion mechanism. On partial launch failure, stop/cancel started workers and apply control C2 before any fallback.
2. On timeout, probe task/process health and approvals, update the checkpoint, and apply C2/C3. Surface owner questions without answering on their behalf.
3. Once every writer stops, run the literal gates serially, honesty and boundary for the union of batch tickets. Verify current and original boundaries across repairs, accounting only for validated intervening work as specified in [execute.md](execute.md). Compare reported paths with each worker's `Where:`; the script proves wave scope, not individual authorship.
4. Dispatch the reviewer with the full input above, then apply control C7-C10 using the checkpoint's shared budget. Follow [verify.md](verify.md) for review and repairs.
5. The main session records evidence and acceptance boxes, marks `done`, and reconciles decisions/INDEX before the next batch. A coordinator requests these edits and waits for acknowledgment. Shared-artifact work uses the main session's serialized maintenance path, never an unauthorized worker edit. If the wave is incomplete, use [late maintenance](execute.md#late-maintenance) within the suspended unit, keeping full gates pending until all its phases settle.
6. Reuse context only for repairs to the same ticket or reviews of the same wave. Release/reset before unrelated work, even when the role matches.

Apply control's stop/liveness rules before handover; a missing completion event must never become an inferred success.

## Optional coordinator

The [coordinator role](../agents/spec-ops-coordinator.md) is a scheduler, not a second planner. Bind it to a backend only after preflight. The main session supplies reviewed execution context and remains reachable for ticket authoring, shared maintenance and owner decisions. If it is unavailable, the coordinator pauses rather than improvising those jobs.

For Orca or another canvas, load that host's current orchestration instructions instead of embedding version-specific CLI commands here. The same dispatch/report/liveness contract applies; a canvas is not evidence of portability or unattended permission by itself.
