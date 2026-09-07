---
name: spec-ops
description: "Model-neutral spec-driven delivery: plan a feature, create vertical tickets, implement planned work, run a bounded quick fix, validate evidence, or reconcile .specs state. Use for /spec-ops plan, tickets, do, validate, reconcile, init, or promote. Works inline with any coding model; parallel workers are optional. Not for read-only investigation, generic repository setup, or full ownership handoffs."
license: MIT
metadata:
  author: paulo-fs
  version: 3.5.0
---

# spec-ops

Define behavior and observable interfaces in a spec, deliver vertical tickets, and verify the result. Never stage, commit, restore another person's work, or create a worktree without permission. Repository instructions and host permissions always apply.

## Capabilities, not providers

The same Markdown workflow applies to GPT, Claude, Gemini, or another model. Slash commands below are user intents, not a required CLI. Use the host's actual read, edit, search and command tools; do not invent tool names or assume instructions load automatically.

Execution requires filesystem access, Git, Bash 3.2+ and standard macOS/Linux utilities (WSL is suitable). Run the gate from the Git worktree root. A chat-only model may draft artifacts, but must label checks `not run` and stop before claiming a phase passed. No subagents, subscription, specific model or MCP server is required.

Read [control.md](references/control.md) before routing, dispatch, resume or acceptance. It owns the decision matrix, deterministic backend selection, state and repair budget. **INLINE is the default**; `--serial` forces it. WAVES requires useful parallel work and a verified backend, not merely available worker slots.

## Commands and routing

```text
/spec-ops init [--tracked]        install the runtime; tracking is opt-in
/spec-ops plan <name>             create spec.md
/spec-ops tickets <name>          create tickets/NN-*.md
/spec-ops do [<name>|<NN>|<path>] execute or resume; implement is an alias
/spec-ops validate <name>         verify the assembled feature
/spec-ops reconcile <name>        reconcile evidence and ticket state
/spec-ops promote                add tracking to existing standalone features
```

Each phase finishes its artifacts and checks; apply control C4 at requested phase/approval boundaries. `do` without an argument resumes the uniquely identifiable active feature; ask when several match.

**Quick lane:** at most 3 files, 5 atomic steps, no design fork or cross-dependency. Declare `Where:`, follow the TDD table, snapshot, implement, gate, honesty, boundary with explicit `--where`, review, report. No spec/tickets required. If the scope grows, stop writing and take the full route while preserving partial work and recovery data.

**Full route:** PLAN -> TICKETS -> EXECUTE -> VALIDATE. Load only the current phase:

| Phase | Read |
| --- | --- |
| PLAN: requirements, seams, unknowns | [plan.md](references/plan.md) |
| TICKETS: vertical slices, risk, TDD | [tickets.md](references/tickets.md) |
| EXECUTE, quick lane, reconcile | [execute.md](references/execute.md) and [verify.md](references/verify.md) |
| VALIDATE: full gate, review, UAT | [verify.md](references/verify.md) |
| Parallel execution only | [waves.md](references/waves.md) |
| Choosing an optional worker/model | [cheap-workers.md](references/cheap-workers.md) |
| Maintaining/evaluating this skill, not delivering a feature | [evaluate.md](references/evaluate.md) |

An explicit `plan` owns discovery: reuse approved designs and research; do not repeat a brainstorming interview or create a second plan. Create `design.md` only for an architectural decision or detailed design that does not fit the behavioral spec.

## Safety and stopping

Apply control C1-C3 before continuation and C7 for exhausted verification. Live database writes, deploys and third-party messages require explicit, dated, action-scoped authorization checked by the actor; a ticket/gate alone is not permission. Preserve owner work and resolve worker liveness before fallback or handover. Record reversible assumptions under `Decidido sem perguntar`, never as observed facts.

## Context and ownership

Read repository instructions explicitly when the host does not preload them. Load the ticket, its `Implements:`/`UAT:` FRs **plus applicable seams, frozen contracts and decisions**, and `Reads:`. Review adds the scoped diff and evidence. Avoid unrelated features and doc sweeps, not necessary contract context.

The **main session** owns planning, ticket/INDEX edits, checkpoints, snapshot history, final validation and owner decisions. It may implement INLINE or dispatch builders. A **builder** owns only ticket code/tests. A **reviewer** reports findings without fixing them. An optional **coordinator** schedules and may execute snapshots/checks mechanically; the main session remains responsible for recording them and authoring artifacts.

## Repository state

Without `.specs/INDEX.md`, use **STANDALONE**: `.specs/features/<name>/`, decisions in the spec. With INDEX, use **TRACKED**: `## Active`, `## Done`, and `.specs/decisions/`. Never require tracking for execution.

`reconcile` follows control's state transitions and [execute.md](references/execute.md)'s evidence procedure. Feature Done requires all tickets `done`/`superseded` and VALIDATE passing under C11; files existing is not completion evidence.

`promote` requires feature directories and no INDEX. Inventory every feature; create INDEX without moving/deleting content. Run `spec`, `tickets` and the full gate before classifying a feature Done. Report invalid historical artifacts instead of normalizing them silently. Preserve old inline decisions; new tracked decisions use `decisions/`.

## Init and updates

Resolve the repository root and inspect existing files first. Report each item as created, present, or skipped with a reason. Never overwrite an existing installation implicitly; compare it with this skill, report drift, and request approval for an in-place update. Do not continue execution against a known incompatible runtime.

1. Copy `scripts/spec-gate.sh` unchanged to `.specs/bin/spec-gate.sh`, preserving executable permission. If absent during another command, perform this minimal bootstrap before its first check; do not create tracking implicitly.
2. Optionally install `agents/*.md` only if the host accepts their name/description Markdown format (for example, Claude Code's `.claude/agents/`). They have no fixed model or tool binding. Other hosts use their bodies as role instructions; no copied adapter is necessary. Verify available permissions separately.
3. Create `.specs/gate.conf` only for a discovered project-wide `GATE_CMD` or necessary overrides. Prefer documented commands over asking. The config is sourced shell and gate commands execute literally: inspect them before running. Use explicit ticket gates when no shared config is needed.
4. Only `init --tracked` creates a new INDEX. For existing standalone features, use `promote`. Create `PROJECT.md` only from useful known facts; do not create empty folders or placeholder documents.

## Examples

- `plan checkout --review`: research, probe seams, write/check the spec, present decisions, wait before tickets.
- `do checkout --serial`: resume tickets in dependency order, with snapshots, tests and review; no worker backend needed.
- `validate checkout`: run the full gate and assembled-flow checks; unchecked UAT stays open even when tests pass.
