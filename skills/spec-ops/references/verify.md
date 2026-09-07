# VERIFY — what the session decides; the actors carry their own rules

Actor-bound rules live with the actor, so they are read by whoever must obey them and exist in one
place: the TDD loop and the ratchet in [`agents/spec-ops-builder.md`](../agents/spec-ops-builder.md);
the review axes, test anti-patterns and composition checklist in
[`agents/spec-ops-reviewer.md`](../agents/spec-ops-reviewer.md). **At width 1 you are both** — read
those two files as your own contract. What stays here is what the session decides: when to run, what
blocks, what ships.

## The script runs first, every time

```bash
scripts/spec-gate.sh gate     ["<literal command>"]   # or GATE_CMD from .specs/gate.conf
scripts/spec-gate.sh honesty  HEAD           # skipped, deleted or shrunk tests in the diff
scripts/spec-gate.sh boundary <feature-dir>  # stray writes, vanished work
scripts/spec-gate.sh spec     <feature-dir>  # size, template, FRs owned by no ticket
```

Exit codes are the verdict. **Trust exit codes over printed summaries**: tooling that rewrites its own
stdout exists, so do wrappers that mask exit status, and so do "changed files" gates that diff against
a merge-base and therefore inspect nothing mid-feature. A gate that inspected nothing is not green.

`TDD:` was decided at TICKETS time from the table in [tickets.md](tickets.md) § 4b. The builder runs
the mode; you only check that the mode matches what the ticket claimed.

## Who reviews

Never the context that wrote the code — its judgment is already committed to the result. INLINE: a
fresh subagent bound to the reviewer definition. `[wide]`: bound at the wave's highest class, kept
warm across fix rounds of **that wave only**, then released.

The reviewer reports findings on two axes, separately, and never fixes what it finds. Both axes and
the honesty checks are in its definition; do not restate them in a dispatch.

## Fix rounds — the session's call, not the reviewer's

**Only `high` blocks.** `med` and `low` accumulate into `spec.md` § Carried debt and are handled once,
at VALIDATE, with the user deciding what ships. A cosmetic finding must never cost a fixer plus a
re-review plus a gate run mid-feature — that is a whole cycle for a nit, and the most expensive unit
in this loop.

`needs-fix` → cluster findings by file or area → one fixer per cluster, at the cluster's ticket class
→ re-review, which re-runs the script but re-reads only the findings and the fix diff. **Max 2
rounds.** Still failing → wall 1 (escalation exhausted): stop and hand the user the findings and the
diff. Never loop. **The fix is a ticket in this feature, never a new feature** (execute.md § 4).

## SPEC_DEVIATION

Diverged from the spec for a defensible reason → the code carries `// SPEC_DEVIATION: <what>` +
`// Reason: <why>`, and review records it. Unmarked deviations are review findings.

A cluster of markers all saying the same thing — most often *"the shared stub had to be taught this so
the seam could observe it"* — is **not several deviations. It is one seam that does not observe**: the
FRs behind it belong in `UAT:`, and the stub edit belongs to the session, between tickets.

# VALIDATE

**Completion criterion:** full gate green, FR coverage accounted, every `UAT:` box walked for
user-facing work, debt triaged, diff summarized for manual commit.

**1. Full gate.** The project's complete gate — from `.specs/gate.conf` `GATE_CMD`,
`.specs/codebase/TESTING.md`, or package scripts: typecheck, lint, format check, full suite,
translation checks when locales were touched. Run it through `spec-gate.sh gate` so the literal string
and the exit code are on the record.

**2. Traceability sweep.** `spec-gate.sh spec` already proves every FR is owned by some ticket. What
it cannot judge, you state explicitly — never leave implied:

| FR | Ticket(s) | Verified at seam | How verified | Status |

- **FRs whose only seam was UAT** — verified by the walk in § 4 or not verified at all. A green suite
  is not evidence for them.
- **FRs marked accepted-unverified** at PLAN time — restate them at handover, when the cost of not
  knowing is concrete.
- **Every remaining fog item.** Re-read spec § Not yet specified against the code that now exists. An
  item unformulable at PLAN time is often trivially answerable now — and if it hid a runtime default,
  the code has already picked one. **Say which default shipped.**
- Account for every `SPEC_DEVIATION`: user-accepted, or a defect.

**3. Composition pass** — non-optional for user-facing work, and distinct from per-wave reviews, which
only ever see slices. Checklist: the reviewer definition's § Composition, end to end, plus frozen
contracts **observed rather than asserted**.

Mechanism, stated because this is where the pass usually dies: **drive the app instance that is already
running — never start one.** Starting a dev server on a project's fixed port kills the running
integration, and a headless DOM sees none of what this pass is for (no CSS, `inert` absent from the
accessibility tree, `invisible` unresolved). If no instance is reachable, say so and mark the pass
**not run**. Do not substitute unit assertions for it.

**4. Interactive UAT.** Walk the `UAT:` boxes **one at a time** — one action, one expected result, wait
for confirmation before the next. Source of truth is the union of every ticket's `UAT:` field; if that
union is empty for user-facing work, TICKETS lost the UAT seam and validation is incomplete. Cover the
happy path per FR, the frozen contracts, and visual fidelity against the design source when one exists
(light and dark where applicable). Every ❌ routes back through the fix loop under the same bounds —
never patched ad hoc here. A box that cannot be walked in this environment stays unchecked and is
reported as such. **Never close it by inference.**

**5. Debt triage.** The deferred `med`/`low` findings arrive as one list. Present it **ordered by
return, not by severity**, and let the user decide what ships now, what becomes a ticket, and what is
accepted. Nothing in this list silently disappears.

**6. Handover.** Working-tree diff summary (`git diff HEAD`) · the closing report block (execute.md
§ 5), including `Decidido sem perguntar` · INDEX line → `## Done` in tracked mode · **the user
commits** — suggest a Conventional Commits message per logical unit if asked.
