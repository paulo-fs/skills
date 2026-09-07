# PLAN — seams, fog, and the spec

**Completion criterion:** every FR testable at a seam **proven to observe it**, every decision's
consequences enumerated, every fog item dispositioned, out-of-scope written down, and
`scripts/spec-gate.sh spec <feature-dir>` exits 0.

Runs to completion; only the four walls interrupt (SKILL.md). `--review` restores a gate here.

## 1. Synthesize, don't interview

Work from what the conversation and the codebase already hold. Explore the repo first — `CONTEXT.md`,
ADRs, `.specs/codebase/*` when present — and use the project's own vocabulary. This phase carries no
tickets, so its class lives here: **all exploration is `Class: scout`**, read-only, never inheriting
the session tier ([cheap-workers.md](cheap-workers.md)).

## 2. Agree the seams — then prove they observe

A **seam** is the public interface where behavior is observed — where tests will live.

- Prefer **existing** seams. Use the **highest** seam that can observe the behavior. Fewer seams beat
  more; the ideal number is one.
- **Probe each new seam.** Write one throwaway assertion at the seam for the behavior you intend to
  test, run it, and require it to **fail for the right reason**. A probe that cannot be made to fail
  means the seam does not observe the FR in this environment — jsdom that never loads CSS, a global
  passthrough mock, an attribute the accessibility tree ignores. Cost: one scoped test run. Delete
  the probe afterwards.
- **State how every declared seam executes here.** A row reading "manual UAT" or "browser" is not a
  seam until the spec says *by what mechanism, in this environment* — e.g. driving an already-running
  app instance, never starting a server. A seam with no executable path is not a seam: its FRs move
  to a seam that does observe them, or become explicitly **accepted-unverified**, listed as such.

A probe that fails to fail is the cheapest signal in this skill: it is what stops a feature from
paying for hundreds of assertions that pass by construction. Skip nothing else before skipping this.

## 3. Fog — research before asking, always

Models ask obvious questions. An obvious question is one whose answer was already on disk, so the
guard is mechanical: **no fog item reaches the user until a scout has gone after it.**

1. **Write each fog item as a specific question**, never a topic. "Which timezone does the romaneio
   use?" qualifies; "timezone questions" is an unwritten note. Test: *can I state the question
   precisely?* — not *can I answer it?*
2. **Batch every question to scouts at once** — they are independent, they are cheap, and each
   returns **raw evidence with paths**, classifying nothing.
3. **Classify the evidence** — the planner's call, never the scout's:

| Verdict | Criterion | Destination |
| --- | --- | --- |
| **resolved** | the answer is in code, schema, docs or history | `## Decisions` with its evidence **path**. Never reaches the user |
| **decidable** | unstated, but a defensible default follows from repo convention or precedent | assumed, recorded, listed under `Decidido sem perguntar`. Reversible |
| **open** | evidence contradicts itself, or it is a business decision no artifact can hold | reaches the user — **wall 4** |

4. **An open question is presented with its research attached**: what was searched, what was found,
   the options, and a recommendation. Assembling that evidence answers the easy ones on the way,
   which is what actually kills the obvious question.

Watch for fog hiding a **runtime default** ("unclear what X shows in state Y"). A default value is
never fog — it is a missing FR, and it ships as whatever the code happens to do.

Every surviving item carries a disposition: → an FR · → a ticket (even a blocked one) · → a `UAT:`
item on a named ticket · → **accepted-unknown**, with an owner and what would resolve it. "I can't
phrase it better yet" is a description, not a disposition.

## 4. The spec — `features/<name>/spec.md`

```markdown
# <Feature> — Spec

## Problem
<2-3 sentences from the user's perspective. Why now.>

## Functional requirements
- **FR-1** <testable statement>
<IDs are load-bearing: tickets and validation trace back to them. Define each id ONCE, on its own
 `- **FR-n**` line — spec-gate checks for duplicate definitions.>

## Seams under test
| Seam | Existing/new | What it observes | Probed? | How it executes here |
<The last two columns are never blank. "manual" is not a mechanism.>

## Implementation decisions
<Modules, interfaces, contracts, schema changes. NO file paths, NO code — they go stale and belong in
tickets. Exception: a snippet that encodes a decision more precisely than prose.>

## Testing decisions
<Which seams get which test type; prior art; which FRs are UAT-only.>

## Frozen contracts
<Things that must NOT change, as auditable statements. Scope: the PRE-FEATURE tree only.>

## Not yet specified
<Fog surviving § 3, each with its disposition and the evidence already gathered, cited by path.>

## Out of scope
| Item | Why excluded |
<Never graduates — returns only as a new effort.>

## Carried debt
<med/low review findings deferred to VALIDATE. Empty at PLAN time.>

## Decisions          ← STANDALONE mode only
<In TRACKED mode write decisions/<slug>.md + an INDEX line instead.>
```

**The budget is enforced, not suggested.** `spec-gate.sh spec` fails the phase past ~24 KB and smells
past ~15 KB, and it lists any off-template `##` section. Both overruns are the same two things every
time: recipes that belong in `design.md` or a ticket's `## Notes`, and fog evidence pasted where a
path belongs. A kilobyte here is read by the planner, by every worker and by the reviewer — it is
paid more times than a kilobyte anywhere else in the pipeline.

## 5. Rules

- **Challenge vagueness.** "Fast", "simple", "users" — make each concrete or cut it. Every FR must be verifiable at an agreed, **probed** seam. An FR testable at no seam is a smell:
  either the seam set is wrong or the FR is decoration.
- **Every decision carries its consequences** — a decision entry is not done until it answers *what
  does this now make impossible, and what survives that shouldn't?* Structural decisions ("stacked
  views instead of a route", "second mount point instead of hoisting") silently keep alive whatever
  the discarded alternative would have destroyed: a shell that no longer unmounts, a control that
  stays mounted but inert, chrome that no longer disappears on navigation. Free to enumerate now,
  expensive to find in review. Same line as the decision.
- **Frozen contracts are scoped to the pre-feature tree** — never an artifact the feature itself
  created a wave earlier. And **frozen ≠ read-only**: a frozen test file accepts *new* cases freely;
  frozen means its existing assertions and expected values do not change. Forbidding extension pushes
  workers into parallel sibling test files, or into a worse design that keeps the old assertions true.
- The spec names behavior, not layout. Pixel and class recipes belong in `design.md` or ticket bodies.
