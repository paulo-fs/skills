# TICKETS — the slices, and how few of them there should be

**Completion criterion:** one file per ticket, numbered in dependency order, and
`scripts/spec-gate.sh tickets <feature-dir>` exits 0.

## 1. Fewer tickets than feels right

A ticket is a **tracer bullet** — a narrow but COMPLETE path through every layer it touches, demoable
or verifiable on its own, sized to one worker session. Vertical, never a horizontal slice of one
layer. A behavior-shaped ticket survives plan drift; "create component X that nothing uses yet" dies
with it.

**Every ticket costs a fixed toll**: at width 1 a context load and a gate run; at width > 1 a
dispatch, a report, a review touch and a worker release. Slicing thin buys nothing at width 1 — the work
serializes either way — and buys only scheduling at width > 1. So:

- **Merging is the default, splitting is the argument.** Same class, disjoint `Where:`, no edge
  between them → one ticket. Say so in the closing report.
- **Atomic tasks are allowed** for genuinely mechanical work (i18n keys, renames, barrels, token
  swaps) — `Class: mechanical`, and they merge with each other freely.
- **Split only for**: a real `Blocked by:` edge, a class change (`mechanical` next to `critical`), a
  `Where:` that would otherwise cover half the tree, or a slice too big for one session.

**Wide refactors are the exception.** One mechanical change whose blast radius fans across the
codebase (rename a shared symbol, retype a column) cannot land green as one slice. Sequence it
**expand–contract**: expand (new form beside the old) → migrate call sites in batches sized by blast
radius, each batch blocked by the expand → contract (delete the old) blocked by every batch. The gate
stays green batch to batch.

## 2. Ticket file — `features/<name>/tickets/NN-<slug>.md`

```markdown
# NN — <Title (behavior, not layer)>

Blocked by: <numbers, or "none">
Where: <file globs this ticket may touch — the boundary contract>
Reads: <guideline doc paths this ticket's work actually triggers, or "none">
Class: scout | mechanical | standard | critical
TDD: red-green | ratchet | none                      ← § 4b decision table
UAT: none | <FR-ids this ticket can only prove by hand or browser>
Implements: FR-3, FR-7
Status: ready | dispatched | done | failed | superseded

## What to build
<End-to-end behavior this ticket makes work, from the user's perspective.>

## Done when
- [ ] <checkable outcome — binary, no human judgment where avoidable>
- [ ] gate: <literal command> exits 0
- [ ] test count ≥ <N> (ratchet)
- [ ] UAT: <one line per UAT id — stays unchecked until walked; never closed by a green suite>

## Notes
<Design recipe pointers, gotchas, prior art. File paths allowed HERE — closest to execution, short
staleness window. Environment traps belong in .specs/codebase/ENVIRONMENT.md, referenced not copied.>
```

## 3. Field rules

- **`Where:` is the boundary contract in both modes.** At width > 1 it also authorizes parallelism; at
  width 1 it is still what `spec-gate.sh boundary` uses to catch scope creep and destroyed sibling
  work. A ticket that "might touch anything" defeats the check and serializes its wave — keep it as
  narrow as is honest, never narrower.
- **`Reads:` is the ticket's entire guideline budget** — the one or two doc paths this work actually
  triggers, resolved here, once, by the planner who already knows its shape. A mechanical rename reads
  nothing. Point it at `.specs/codebase/CONVENTIONS.md` when that file exists.
- **`Class:` follows SKILL.md § Where cheap tokens are safe.** `mechanical` requires **zero judgment
  calls in the body** — any "choose the closest…" promotes it to `standard`, and spec-gate greps for
  exactly that. `critical` = state machines, data migration, save/wire contracts, where errors are
  expensive. When unsure → `standard`. A stronger tier protects against *reasoning* failure only, not
  against scope drift, an undispositioned decision, or a test that observes nothing. **Never spend
  tier as insurance.**
- **`TDD:` comes from the table in § 4b**, by rule, not by vibe at implementation time.
- **`TDD:` and `UAT:` are orthogonal**, not alternatives. `red-green` + `UAT: FR-23` is the normal
  shape for user-facing work with both new logic and visual fidelity. Forcing one choice is how a
  declared UAT seam ends up owned by nobody and never walked.
- **Tests are co-located**: the ticket that creates behavior carries its tests. "Tested in a later
  ticket" is deferral — merge the tests forward, or absorb the blocker backward so it self-tests.

## 4b. `TDD:` — the decision table

Derived here, at TICKETS time. The red→green loop rules and the anti-patterns live where they are
executed: [verify.md](verify.md).

| Situation | Mode | Meaning |
| --- | --- | --- |
| New logic/behavior at an agreed, probed seam | `red-green` | failing test first; the test is the spec |
| Bug fix, suite exists | `red-green` | reproduce in a failing test before fixing |
| Mechanical change (rename, i18n, token swap, barrel) | `ratchet` | no new tests; suite must not regress; count verified |
| Behavior no seam observes here (pixel, safe area, overflow, real focus/pointer) | `ratchet` **+ `UAT:`** | never asserted in unit tests — asserting CSS classes to simulate coverage is forbidden |
| Project has no test suite | `none` | gate degrades to build + lint; flag `no-tests` in the plan |

## 4. Edges — `[wide]` only

At width 1 a false `Blocked by:` costs nothing: you execute in numeric order regardless. Above it,
each one costs a barrier, so apply the test then: *does B's **code** fail to compile or run without
A, or does B merely **demo** better after A?* Only the first is an edge; a demo relationship becomes
a line in `## Notes`. Full rule: [waves.md](waves.md) § 2.

## 5. Validation — by command, then by eye

```bash
scripts/spec-gate.sh tickets <feature-dir>   # headers, Blocked-by targets, Where: sanity,
scripts/spec-gate.sh spec    <feature-dir>   # misclassified mechanical, spec size/template,
                                             # duplicate FRs, FRs owned by no ticket
```

It prints its own findings. Three things it cannot see:

| Check | Failure it catches |
| --- | --- |
| `Blocked by:` ↔ a real code gate (§ 4) | false edges bought with a whole barrier `[wide]` |
| `TDD:` ↔ the § 4b table | ratchet where behavior is new |
| `Where:` overlap between tickets that would run together | two workers corrupting each other `[wide]` |

Any ❌ → restructure and re-check. **Never write out failing tickets.** Then set every unblocked
ticket `Status: ready` and continue to EXECUTE.
