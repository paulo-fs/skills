---
name: spec-ops
description: "Spec-driven planning and verified execution — spec, tracer-bullet tickets, then one worker at a time inline or waves when real parallelism exists. Backend-agnostic: ships its own worker definitions and binds to whatever can run them. Use when the user wants to (1) plan a feature (\"plan\", \"planejar\"), (2) break work into tickets (\"tickets\", \"quebrar em tickets\"), (3) implement planned work (\"do\", \"implementar\", \"continua a feature\"), (4) run a quick fix, (5) manage .specs state (\"promote\", \"reconcile\"), (6) prepare a repository to run this skill (\"init\", \"setup\", \"roster\"). Inline by default; waves only at width > 1. Not for read-only investigation or full ownership handoffs."
license: MIT
metadata:
  author: paulo-fs
  lineage: spec-driven v1.3.1 → 2.0 (roster) → 3.0 (width-branched, script-gated) → 3.1 (backend by contract, one init)
  version: 3.1.0
---

# spec-ops

The spec says WHAT and where the **seams** are; **tracer-bullet** tickets say the slices; execution
proves each slice by command. **Nothing here ever commits** — the user reviews the working tree and
commits manually.

## Width decides the shape — measure it before anything else

Orchestration machinery is only worth its cost when workers run **at the same time**. Measured on a
cohesive build, strong-planner-plus-cheap-executor loses to the strong model alone on quality *and*
wall clock, and frontier models free to delegate did not (numbers: [cheap-workers.md](references/cheap-workers.md)).
So the first question is never *which worker* — it is **how many at once**.

```
WIDTH = BUILDERS that can run CONCURRENTLY on this machine for this feature
├─ 1  → INLINE (default). No dispatch, no reports, no worker resets, no Where: partitioning.
│       One ticket at a time in this session, spec-gate between tickets.
│       Everything marked [wide] is skipped — it guards a race that cannot happen.
└─ >1 → WAVES. execute.md applies in full.
```

INLINE is **not** degraded mode. It keeps everything that carries value — the spec, the probe, the
tickets, the literal gate, review, reconcile — and drops only the transport that parallelism pays for.
Declare the mode in the run header either way; `--serial` forces INLINE.

**Width counts builders, not delegation.** Read-only **scouts** and the adversarial **refuter** are
verifiable at a glance and cost almost nothing, so they are available in every mode, INLINE included
([cheap-workers.md](references/cheap-workers.md)).

## Where cheap tokens are safe

Class is not "which model is good enough". It is **where the verifier is stronger than the
generator** — the only place a cheap worker's failure is caught for free.

| Work | What verifies it | Class | Cheap model? |
| --- | --- | --- | --- |
| Read-only sweep, volume over depth | the paths it hands back | `scout` | **yes** |
| `Done when` fully checkable by command | the gate | `mechanical` | **yes** |
| Adversarial second opinion on a finding | decorrelation, not competence | — | **yes** |
| Feature code in a codebase with invariants | nobody, until review/UAT | `standard` / `critical` | no |
| Planning, composing waves, judging fidelity | nothing | — | **never** |

Criteria per class and the "never spend tier as insurance" rule: [tickets.md](references/tickets.md).
Running the gate is not model work at all: it is `scripts/spec-gate.sh` — a worker whose whole job is
to run commands is a permission problem you invented. A project tunes it (gate command, spec section
names, requirement-id prefix, test paths) through an optional `.specs/gate.conf`; absent, defaults
apply and a fresh project needs no setup.

## Runs to completion

Every phase runs end to end. Choices that were approval gates — granularity, edges, merges, class,
order — are **decided, recorded, and listed at the end** under `Decidido sem perguntar`: ten seconds
to smell a bad call, and the tree is uncommitted so every one is reversible. `--review` restores a
gate for one phase. Three walls stop a run, each detected by command, never by taste:

1. `[wide]` **Escalation exhausted** — failed twice at its tier and the tier-up also failed.
2. **Vanished work the index cannot restore** (`spec-gate.sh boundary`). Data loss; stop immediately.
3. **Architectural fork with no defensible default.** A fork *with* a default is assumed and recorded.

## Modes and pipeline

`.specs/INDEX.md` present → **TRACKED** (INDEX + decisions/ + features/); absent → **STANDALONE**
(`features/<f>/` only, decisions inline in the spec). Only `init --tracked` creates the chassis;
`promote` upgrades standalone → tracked later. **Standalone is the lighter default — never force the
chassis on a repo that did not ask for it.**

| Scope | Route |
| --- | --- |
| ≤3 files, zero design decisions | **Quick lane**: atomic steps inline → execute. No artifacts (1 INDEX line if tracked). >5 steps or cross-deps → stop, take the full route. |
| Everything else | PLAN → TICKETS → EXECUTE → VALIDATE |

- **PLAN** — seams, probes, FRs, fog → [references/plan.md](references/plan.md)
- **TICKETS** — tracer-bullet slices, `Where:`, `Class:` → [references/tickets.md](references/tickets.md)
- **EXECUTE** — width branch, invariant, boundary, reconcile → [references/execute.md](references/execute.md)
- **VERIFY** — the TDD loop, review, VALIDATE, UAT → [references/verify.md](references/verify.md)
- Scouts, refuters and the cheap-model gateway → [references/cheap-workers.md](references/cheap-workers.md)
- `[wide]` only — the backend contract, compile, dispatch → [references/waves.md](references/waves.md)

`design.md` exists only when a real architectural decision needs recording.

## Context budget

Whatever the session-long participant loads is re-paid every turn of the feature.

| Moment | Load |
| --- | --- |
| Session start (tracked) | `sed -n '/^## Active/,/^## /p' .specs/INDEX.md` — nothing else |
| Building a ticket | that ticket · only the FRs its `Implements:` names · its `Reads:` paths |
| Reviewing | the diff · only those FR-ids · the tickets' `Reads:` — never a sweep of `docs/` |
| Never | other features' specs · `## Done` entries · unreferenced decision files |
| Never [wide] | orchestrator reading spec bodies, ticket bodies, diffs, or test output |

## Command surface

```
/spec-ops init [--tracked]        prepare this repository to run the skill (see below)
/spec-ops plan <name>             PLAN → features/<name>/spec.md
/spec-ops tickets <name>          TICKETS → features/<name>/tickets/NN-*.md
/spec-ops do [<name>|<NN>|<path>] EXECUTE. `implement` aliases it
/spec-ops validate <name>         VALIDATE phase
/spec-ops reconcile <name>        re-sync tickets/INDEX with what the code actually became
/spec-ops promote <name>          standalone feature → tracked project
```

Flags: `--review` gates that phase · `--serial` forces INLINE. `do` with no argument resumes from
ticket `Status:` — **state lives in the tickets, not in chat memory.**

## `init` — prepare the repository

Runs anywhere, needs no prior state, and is the only command that writes outside `.specs/features/`.
Three independent parts; do every one that applies and **report each as created, already present, or
skipped with the reason**.

**Two rules over all of it.** It is **idempotent** — never overwrite a file that exists; report it and
move on. And it **creates nothing empty**: a stub config or a placeholder doc is worse than its
absence, because the next reader treats it as a decision that was made.

1. **Worker definitions — always.** Copy this skill's `agents/*.md` into the directory this harness
   reads worker definitions from (Claude Code: `<repo>/.claude/agents/`). Five files, no edits. This
   is what **decouples the worker's model from the session's**: without them a subagent inherits the
   session model, so a cheap session silently downgrades the reviewer and every `critical` ticket.
2. **`.specs/gate.conf` — only when it earns the file.** Ask for the project's gate command and put it
   in `GATE_CMD`. Add `TEST_PATH_PATTERN` only after the default misfires — run `spec-gate.sh honesty`
   and look at what it actually matched. **Skip the file entirely** when tickets carry their own literal
   gate line and no project-wide gate is wanted.
3. **Chassis — only with `--tracked`.** `.specs/INDEX.md` + a `PROJECT.md` stub. A repo whose `.specs/`
   holds features and no `INDEX.md` has *chosen* standalone; say `promote` exists and leave it alone.

Then report what the repo already gives a worker for free — its agent instructions (`CLAUDE.md`,
`AGENTS.md`), any convention or environment docs a ticket's `Reads:` could point at. That inventory is
the answer to "does this project need `.specs/codebase/`?", and the answer is usually no.

Rationale, the bar for adding a fifth definition, and why domain knowledge never goes in one:
[references/waves.md](references/waves.md) § 2.
