# Control Policy

This is the session's single source for routing, backend selection, state and retry decisions. Phase references supply procedures; actor files retain their own safety contracts. Read this before choosing a phase, dispatching, resuming or accepting work. Repository instructions and host permissions take precedence.

## Decision matrix

Check safety rows C1-C3 before any continuation row; an unknown fact is not a passed condition. Record the applied row and its evidence in the checkpoint. Multiple blockers remain listed even when one determines the next action.

| ID | Observed situation | Required action | Evidence before proceeding |
| --- | --- | --- | --- |
| C1 | Unauthorized external effect, permission blocker, out-of-scope write or inspection/recovery error | Stop the affected work; request owner action. Never bypass, restore or widen scope retroactively | Action-scoped dated authorization, resolved permission or investigated boundary/error |
| C2 | Missing worker completion or unknown liveness | Probe the bound task/process. Keep `dispatched`; no replacement, backend switch or INLINE fallback while a writer may remain | Actual status/termination result, not silence or an agent's guess |
| C3 | Product/architecture fork lacks a defensible default | Research first, then ask with findings and options | Repository precedent or an owner decision; an assumed default stays labelled assumed |
| C4 | Planning-only request or `--review` approval boundary reached | Finish and check only the requested phase, present artifacts, then wait | User request and phase gate; no tickets/implementation unless requested |
| C5 | No backend chosen or a run is resumed | Apply Backend selection below; record selection source | Capabilities, existing binding, project policy and useful-width assessment |
| C6 | Initial TDD red, including diagnosed late maintenance | Continue the same incomplete unit using the TDD/maintenance procedure; do not close it | Intended red output; maintenance requires prior boundary and local phase checks |
| C7 | Stable required gate fails or review has a high finding | Use a remaining repair round, or stop exhausted | Failure output/finding, diagnosed cause and persisted budget |
| C8 | Exit 0 without relevant work inspected, or required evidence unavailable | Keep verification pending; obtain an observing check | Actual test/file scope and observed outcome; exit code alone is insufficient |
| C9 | Implementation returned but gate/review/acceptance is pending | Keep `dispatched`; do not release dependents | Non-UAT acceptance, complete literal gate, honesty, boundaries and review |
| C10 | All C9 evidence passes on the settled unit, no high finding | Record evidence and mark ticket `done` | Review independence or disclosed self-review; UAT remains separate |
| C11 | Required UAT, FR evidence or debt triage is incomplete | Feature remains Active, even if tickets are done | Observed UAT/FR outcomes and owner debt dispositions before feature Done |

For a diagnosed invocation-only error with no writes or uncertain effects, correct the invocation and rerun the same check within existing scope/permissions; owner action is unnecessary. Verification stays pending. This does not exempt actual permission, boundary or recovery blockers from C1.

On any stop, cancel active workers through the verified backend and confirm they no longer write. If that cannot be established, preserve their handles and `dispatched` state; do not present a stable handover. A healthy running worker may continue waiting under C2 rather than being treated as failed.

## Backend selection

`--serial` forces INLINE after any existing writers are settled. Otherwise use this order, without asking when the result is unambiguous:

1. **Explicit user choice.** Verify that backend; if unavailable or unsafe, report the blocker instead of silently replacing it.
2. **Existing execution binding.** Revalidate the backend/handles from the checkpoint or host-bound run. An unfinished binding cannot silently switch; resolve liveness first, then obtain owner approval for a necessary transport change.
3. **Documented project preference.** Read existing project/agent instructions or `PROJECT.md`; no new config file is required. Try an ordered preference list as written. A required preference blocks if unavailable; an optional one records the reason and falls through.
4. **Native delegation.** Consider only tools exposed by the current host and permitted by project policy. Use its advertised default when equally capable; otherwise choose the compatible tool name in lexical order. Presence of a tool is not proof of unattended edits, completion or cancellation.
5. **INLINE.** With no compatible candidate, the main session executes serially and reports why. A standalone coordinator hands work back; it never becomes a builder.

Every selected worker backend must pass the [WAVES preflight](waves.md#preflight). Do not scan installed executables to invent a backend, start a canvas/CLI merely because it exists, or change permissions to make a candidate fit. Backend choice does not choose a model provider; bind available capable models separately.

INLINE is also used when fewer than two useful independent builder slices exist. WAVES width is the minimum of independent work, safe resource capacity and available workers. Uncertain write/read dependencies, shared mutable test resources or unsafe local TDD commands serialize the work. Scouts/reviewers do not increase builder width. Before switching modes on resume, apply C2.

## Repairs and state

One ticket/wave receives its initial implementation and at most **two repair rounds total** for stable-gate failures and high findings. Persist consumption before a repair starts. Initial causal TDD red and diagnosed environment/sibling interference do not consume a repair; they still require resolution. A new worker, model, maintenance phase or fixer ticket never resets the counter. Missing history means reconstruct it from evidence, not assume zero.

Apply these state predicates in order after C1-C3; an ended process alone says nothing about whether implementation finished. New units start `ready` and become `dispatched` before their first write once prerequisites pass.

| State evidence | Transition |
| --- | --- |
| Live or unknown writer | Keep `dispatched` under C2, regardless of a failure or exhausted budget |
| No possible live writer; exhausted verification or recorded terminal execution failure | `failed`, with findings and recovery paths |
| Implementation finished; verification/review still pending | Keep `dispatched` under C9; resume verification, not another implementation |
| C10 satisfied | `done`; ticket completion does not imply feature Done |
| Abandoned shape, no possible live writer | `superseded`, linking its replacement and carrying evidence/budget forward |
| Confirmed ended worker/interrupted session; implementation unfinished and eligible to continue | Preserve changes/history, return to `ready`, recheck checkpoint before dispatch |

## Checkpoint

The main session maintains one `### Checkpoint` inside each ticket's existing `## Notes`, using exactly the ten labels below; put extended evidence in referenced Notes subsections, not extra checkpoint keys. For a wave, use the same unit membership and shared repair history in its member tickets. Quick lane uses its existing run record instead; planning-only does not create tickets just for a checkpoint. This is a Markdown convention, not a new scheduler or executable config.

```text
### Checkpoint
Unit: <ticket identity or complete wave membership>
Mode/backend: <INLINE / none or WAVES / backend; selection source>
Phase: <current phase; completed maintenance phases if applicable>
Last verified: <observed fact, literal command/result and evidence path; control row>
Next action: <one concrete action, or wait for named blocker>
Pending: <unverified acceptance, gate, review, UAT and unresolved questions>
Repairs: <consumed>/2; <history reference if consumed>
Writers: <handles/status/evidence, or confirmed none; unknown is explicit>
Scope: <current phase paths and authorization; other phase scopes by reference>
Baseline: commit <ref>; baseline <path>; original <path>; current <path>
```

Update before the first write/dispatch, before each repair, after observed phase results, and before a pause or handover. Never replace evidence history with a new narrative or overwrite original snapshots. Fields not yet established say `pending` before execution, never invented values. Read the checkpoint first on resume, then open its evidence and applicable contracts; continue only when they corroborate the next action. Coordinator requests updates and waits for acknowledgment.
