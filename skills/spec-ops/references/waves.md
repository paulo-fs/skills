# WAVES — everything that exists only above width 1

None of this loads at width 1. If you are reading it, `execute.md § 1` measured width > 1: more than
one **builder** can run at the same time here. Scouts and refuters are not builders and never
depended on width ([cheap-workers.md](cheap-workers.md)).

## 1. The backend contract

This skill never requires a named tool. It asks five questions of whatever can run a worker, plus
width. Answer them for what is actually present, and record the answers in the run header:

| Question | What the answer must give you |
| --- | --- |
| **Dispatch** | how to hand one worker one ticket path, and how to issue several at once |
| **Report** | how the worker's report gets back — or whether it arrives by itself |
| **Release** | how a worker's context is discarded between unrelated tickets |
| **Write prerequisite** | whether the worker can write files unattended, or halts on its first write |
| **Invariant** | where § 3's contract is written **once**, so it is not re-sent per ticket |
| **Width** | how many builders it can run concurrently |

### Detection ladder — capability first, tool name never

Take the highest rung that answers all six. Named products appear only as examples of a rung.

1. **Named subagents** — the harness reads worker definitions from a directory in the repo
   (Claude Code: `.claude/agents/*.md`; an SDK's `agents` map is the same rung). Best answer to every
   question: identity is durable so the invariant lives in the definition; the model is per-role
   frontmatter; the definitions are versioned **with the repo**, so the team travels with a clone;
   and each call starts clean — which is the release, for free, with no ceremony and no human.
   `/spec-ops init` materializes this skill's four definitions here (§ 2).
2. **Anonymous subagents** — a subagent facility with no stored definitions. Same properties, except
   the invariant must be **inlined per call**: ~20 lines, once per dispatch. Small; do not trade it
   away for something more complicated.
3. **A shell-invocable agent CLI** — one command runs a full non-interactive agent session
   (`opencode run -m <provider>/<model> "<prompt>"`, and equivalents). The rung for **models the
   harness cannot run natively**: budget isolation, or a cheap executor on a `mechanical` ticket
   ([cheap-workers.md](cheap-workers.md)). Stateless, so release is free and the invariant is inlined.
4. **Nothing** → INLINE (execute.md). Not a failure; it is the default.

**Persistent-worker canvases are a rung 0, and deliberately unlisted.** A worker that outlives a
ticket must be reset between unrelated ones — this skill's own rule (§ 3, warm context) — so its
defining feature is the one thing you then pay to undo, sometimes by interrupting a human. Such a
tool is a good surface for a person to *watch* work; it is a poor backend for running it. If one is
open on this machine, leave it to the human and pick a rung above.

Whatever you pick, **declare it in the run header** with the width it gave you. A backend swap is
never a class downgrade — it is another transport for the same class table.

## 2. Where the four worker definitions come from

`agents/` in this skill ships four definitions that carry the **contract and nothing else**:
`spec-ops-scout`, `spec-ops-builder`, `spec-ops-builder-critical`, `spec-ops-reviewer`. They hold no
project knowledge, no language, no framework — which is exactly what makes them correct on the first
day of a project in a stack none of them has heard of. Domain reaches the worker by two channels that
already exist and cost nothing: the repo's own agent instructions, loaded automatically, and the
ticket's `Reads:`, resolved once at TICKETS time.

`/spec-ops init` installs them (procedure: SKILL.md § `init`). It never invents roles by discovery.

**The bar for any further agent, so this never becomes a catalogue:**

> Can you name something this agent knows that **no document a ticket could point at** contains?

If no, it is a `Reads:` line, not an agent. A project-local agent is legitimate when it encodes a
**procedure or a tool access** — driving a live editor over MCP, an interactive device harness — and
never when it encodes knowledge. "A builder that knows framework X" is always the second kind.

## 3. Dispatch is a path, not a packet

Tell the worker which ticket to build. That is the whole per-dispatch payload.

Everything a packet used to carry — `Implements:`, `Reads:`, `TDD:` — is a **literal copy of that
ticket's header**, sitting in the file the worker is about to open. Copying it into the message
imposes no constraint the file does not already impose: a worker that ignores its own header ignores
the message too. What looked like the packet's job was the *rule* — "read only the FRs your
`Implements:` names; `Reads:` is your entire guideline budget" — and a rule that never varies per
ticket belongs in the invariant (execute.md § 2), written once.

| Rung | Invariant + report schema live… | Per dispatch |
| --- | --- | --- |
| 1 (named) | in the worker definition | the ticket path |
| 2, 3 (anonymous, CLI) | inlined in every call | the ticket path |

**One wave, one batch:** every ticket goes out together and you wait for all of them before closing
the wave. The barrier costs rolling per-ticket review and buys a drastically simpler control loop.

**Warm context follows the work item and never crosses it.** Keep a worker's conversation only while
its own item can still come back — fix rounds of the same ticket, the same wave for a reviewer — then
release it. Reusing a warm worker for an unrelated ticket drags the old transcript as input tokens on
every turn and biases the new judgment. The reviewer is the worst offender: consecutive reviews of
unrelated waves have no continuity worth keeping.

## 4. Compile

Everything this needs is in the ticket **headers** — one command reads them all, no body is opened:

```bash
grep -E '^(Blocked by|Where|Reads|Class|TDD|UAT|Implements|Status):' .specs/features/<f>/tickets/*.md
```

1. **Toposort** `Blocked by:` → waves. Tickets are numbered in dependency order, so this is usually
   reading the numbers.
2. **Partition within a wave by `Where:` intersection** (prefix/glob match is enough). Disjoint →
   parallel batch. Overlapping → serialize. This is the only thing preventing two workers corrupting
   each other in a shared worktree, and the only reason `Where:` disjointness has value at all.
3. **Bind** class → worker definition; record the binding in the closing report, never in the ticket.

Wave width is capped by the backend's width for that class. Needing more is the user's call — surface
it in the report, do not stall on it.

**Edges pay for themselves only here.** At width 1 a false `Blocked by:` costs nothing (you execute in
order regardless); here each one costs a barrier. The test, applied when tickets were authored:
*does B's **code** fail to compile or run without A, or does B merely **demo** better after A?* Only
the first is an edge — "B is the button that reaches A's screen" is a demo relationship, and B can
drive the state directly in its own tests and ship in the same wave.

## 5. The report — fixed schema, literal gate

Part of the invariant, not of a dispatch. Exactly once per worker, ≤12 lines:

```
files touched · net test delta · gate command (literal) + exit status ·
deviations (SPEC_DEVIATION markers) · blockers · observations
```

- **The gate command must be literal** — the exact string that ran. Paraphrased gate lines are how a
  fabricated success reaches the user. Verify with `spec-gate.sh`, never by reading a diff.
- **`observations`** is where "if this looks wrong, report it" gets answered: fog the ticket asked
  about, a default that seems off, a control that appears inert — each with a verdict. Without this
  slot such a finding is neither deviation nor blocker and evaporates. An empty line here when the
  ticket asked a question is itself a finding.
- No transcripts, no diffs.

## 6. Escalation ladder

Failed its gate 2× at its tier → redispatch **once** at the next tier up, with the failure context
appended (gate output, what was attempted, findings) — a blind retry repeats the mistake. Still
failing, or already top tier → **wall 2**: stop and hand the user the findings. Never loop, never
demote after a failure. A ladder that never fires across a whole feature means the floor is too high
to learn from.

## 7. Write prerequisite

A worker in a normal permission mode **halts on its first file write** and waits, which is what every
builder ticket does continuously. Measure it before the first dispatch, never mid-wave.

- Subagent rungs inherit the session's permission mode and add **no** permission surface. Nothing to do.
- A shell-invoked CLI has its own permission model. Grant at **user level, scoped to the projects
  root** — not one repo (this skill runs across projects) and not the whole disk.
- A worker that is **read-only by role** needs no grant at all; leaving its edit permission asking
  turns the role boundary into an enforced one.

Answering a worker's prompt on its behalf is a bypass through another door, and so is working around a
host guardrail that refuses to *write* the grant. Hand the user the exact configuration and stop.

**Never make a worker out of the gate.** Running commands is `scripts/spec-gate.sh`: a worker whose
whole job is to execute a fixed command buys nothing and costs a context, an allowlist and a release.
