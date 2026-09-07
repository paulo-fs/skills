# EXECUTE — run the slices, prove each by command, reconcile

**Completion criterion:** every ticket `done` (or explicitly `failed`/`superseded` with the user
informed), final review clean, tickets/INDEX reconciled, working-tree diff summarized for the user's
manual commit, and the closing report printed (§ 5).

## 1. Measure width, then take one of two paths

Width counts **builders that can run at the same time** — not delegation in general. Scouts and
refuters are read-only, verifiable at a glance, and available in every mode
([cheap-workers.md](cheap-workers.md)).

```
WIDTH = builders that can run CONCURRENTLY here
   a subagent facility  → its concurrency cap, default 4
   a shell agent CLI    → how many you are willing to run at once
   neither              → 1
```

**Width 1 → INLINE.** Read `Blocked by:` in order and do one ticket at a time **in this session**.
Per ticket: load it, the FRs its `Implements:` names, its `Reads:` paths → build → `spec-gate.sh gate
"<literal>"` → `spec-gate.sh boundary <feature-dir>` → review (verify.md) → `Status: done` → next.
No dispatch, no report schema, no worker release, no `Where:` partitioning: at width 1 the partition
guards a race that cannot happen. The invariant below still binds — it binds *you*. **Say
`mode: INLINE` in the run header.**

**Width > 1 → [waves.md](waves.md)** for the backend contract, compile, dispatch, report and
escalation. Everything else in this file applies to both.

Write `.baseline` before the first ticket:
`git status --porcelain > .specs/features/<f>/.baseline`.

## 2. The invariant — one copy, in the actor's own file

The rules that bind whoever writes code live in
[`agents/spec-ops-builder.md`](../agents/spec-ops-builder.md): never commit, never weaken or delete a
test, never touch a file outside your `Where:`, never rewrite a shared artifact, read only the FRs
your `Implements:` names, and report outcomes you actually observed. They are written there because
that file **is** the worker's system prompt — a rule the actor reads every turn beats a rule the
orchestrator remembers to send.

**At width 1 you are the builder. Read that file and treat it as your own contract** — the session
holds no exemption from it. Above width 1 the rules arrive with the worker definition (rung 1) or are
inlined per call (rungs 2–3); either way, never paraphrase them per ticket.

The session adds one rule of its own: **at each clean ticket, run `git add -A`.** That is not a step
toward committing — `git checkout -- <path>` restores from the **index**, so staging makes the most
common way work gets destroyed a no-op.

## 3. Boundary enforcement — by script, both directions

`spec-gate.sh boundary <feature-dir>` after every ticket. It compares `git status --porcelain` against
the union of `Where:` globs and against `.baseline`:

- new/changed path outside every glob → **stray write** → a failed gate; the fix removes or relocates it.
- path in `.baseline`, absent now → **vanished work**. Checked against the index first (the `git add
  -A` above usually means nothing was really lost); if the index cannot restore it, **wall 3** — stop.

The baseline is the **feature's**, not the wave's — work delivered early stays uncommitted for the
whole feature, so a narrower baseline cannot see it disappear. It is also the only state here that
cannot be rebuilt from the tickets, which is what makes this session resettable (§ 6).

## 4. Reconcile

At each clean ticket or wave:

1. `git add -A`. Nothing is committed.
2. **Reconcile**: diverged tickets get body and `Status:` updated (`superseded` + one line pointing at
   what replaced them); INDEX lines updated; architectural divergence in TRACKED mode gets a
   `decisions/<slug>.md`. Unresolved `observations` are dispositioned here — into a ticket, the debt
   ledger, or the spec's fog with an owner. **The plan never lies.**
3. Shared-artifact work reported and stopped on (lockfile, generated barrel, shared stub, migration)
   happens **here, between tickets** — never inside one.

**A fix for review findings is a ticket in THIS feature, never a new feature.** A new `features/<f>/`
is for work the user asked for, or a bug found later in UAT or production. A process that spawns
features about its own findings is feeding on itself, and the directory count is the tell.

## 5. Closing report

One block, no prose. This replaces every approval gate the run did not ask for:

```
Mode:      INLINE | WAVES (width N) · backend · fallbacks taken
Diff:      git diff HEAD — files per ticket, net test delta, deviations accepted
Decidido sem perguntar:
   · 03+05 merged (mechanical, disjoint Where:) — one ticket
   · 04 promoted standard → critical (touches the status state machine)
   · fog "romaneio timezone" → assumed America/Sao_Paulo, recorded in spec § Decisions
Left open: walls hit, debt ledger, unwalked UAT boxes
```

Ten seconds to smell a bad call, and the tree is uncommitted, so every one is reversible.

## 6. Resettable, and resumable

**State lives on disk, not in chat memory.** Ticket `Status:` rebuilds the frontier, `Blocked by:`
rebuilds the order, `.baseline` holds the only irreducible snapshot. So this session can be reset at
any ticket boundary and reconstruct itself.

`do` with no argument resumes: read `Status:` → rebuild the frontier → if the tree changed outside the
plan since the last run, reconcile FIRST, then continue. A ticket stuck `dispatched` with no live
dispatch behind it is an orphan from a dead session: reset it to `ready` and let reconcile decide
whether its partial work stands.
