# PLAN - Seams, Fog, and Spec

**Complete when:** FRs have proven observation seams or explicit accepted-unverified dispositions, applicable acceptance examples have independent sources or explicit assumption labels, decisions include consequences, fog and exclusions are recorded, and `.specs/bin/spec-gate.sh spec <feature-dir>` exits 0. Apply [control C1-C4](control.md#decision-matrix) to blockers and phase boundaries; planning-only never implies permission to implement.

## 1. Synthesize, don't interview

Read the conversation, relevant code, repository instructions, existing context and decisions before asking questions. Use repository vocabulary. Research may run read-only inline or through available scouts; scouts are optional and do not count toward builder width. Report unavailable checks as not run; a tool-less model may draft but cannot pass PLAN.

## 2. Agree the seams, then prove they observe

- A **seam** is a public interface where behavior is observable. Prefer existing seams and the highest level that actually observes the FR; avoid redundant seams.
- **Probe each new seam before investing in tests:** run one disposable assertion and observe failure for the intended reason. Record the command and result. A passing assertion against absent behavior proves nothing; CSS-less DOMs and passthrough mocks can hide defects. Remove only the disposable probe you created, never existing tests. The probe does not replace implementation's red-green loop.
- Before a repository-mutating probe, declare narrow `Where:` paths and snapshot to a unique file under `.specs/.boundaries/` using the bootstrapped runtime. Prefer a new uniquely named probe over editing existing tests. After removing only your probe changes, run `boundary .specs --where <pattern> --since <snapshot>`; preserve recovery evidence. This safety step applies during PLAN, not only EXECUTE.
- Record how every seam executes in this environment, including existing evidence or a new probe. "Browser" or "manual" alone is insufficient: name the runner or reachable app and interaction mechanism. If observation is unavailable, find another seam or explicitly record the FR as **accepted-unverified**, with owner, reason and remaining check; never imply verification.

## 3. Fog - research before asking

1. State a specific question, not a topic: "Which timezone does this export use?"
2. Search code, schemas, docs and history inline, or delegate independent searches when useful. Collect paths and evidence, not invented answers. If access is unavailable, disclose the research not run.
3. Classify: **resolved** has evidence; **decidable** has a defensible, reversible default recorded under `Decidido sem perguntar`; **open** needs an owner decision. Record evidence and assumptions in Decisions. Present open questions with searches, findings, options and a recommendation.
4. Give each surviving item a destination: FR, named ticket, named ticket's `UAT:` item, or **accepted-unknown** with an owner and resolution condition. Ticket destinations become concrete during TICKETS.

Runtime defaults are behavior, not a fog escape hatch: specify the default as an FR or expose the unresolved choice. Do not let incidental implementation choose silently.

## 4. The spec - `.specs/features/<name>/spec.md`

Define each requirement once on its own `- **FR-n**` line. Replace placeholders below; preserve the section names consumed by spec-gate. Keep `## Decisions` for STANDALONE; TRACKED uses `.specs/decisions/<slug>.md` and an INDEX entry instead.

For ambiguous, numeric, default or error requirements, add concise acceptance examples under Testing decisions or beneath the defining FR. Reference the FR-id without defining it again. Independent sources are explicit owner statements, pre-feature frozen behavior, or approved policy/doc examples; cite evidence that actually specifies the expected result and preserved/forbidden behavior. Never derive expectations from the current implementation or invent product numbers, rounding or currency defaults. Exact expected values must be independently specified to count as confirmed evidence. If a source is absent, record the researched question or defensible default as an **assumption**, with its disposition in Decisions/Not yet specified, not as confirmed evidence.

```markdown
# <Feature> - Spec

## Problem
<User problem and why now, in 2-3 sentences.>

## Functional requirements
- **FR-1** <Concrete observable behavior, including relevant defaults and failures.>

## Seams under test
| Seam | Existing/new | What it observes | Probed? | How it executes here |
| --- | --- | --- | --- | --- |
| <Public interface> | <existing or new> | <FR-ids> | <Evidence or explicit limitation> | <Command or reachable app and mechanism> |

## Implementation decisions
<Modules, interfaces and contracts; each decision with its consequences.>

## Testing decisions
<Seam/test mapping, prior art, probe evidence, UAT-only FRs and verification limitations.>

### Acceptance examples
| FR | Input/context | Observable expected result | Preserved/forbidden behavior | Independent source / status |
| --- | --- | --- | --- | --- |
| <FR-id reference> | <Concrete input and relevant state> | <Exact observable outcome> | <What must remain unchanged or never happen> | <Source citation and what it establishes; label assumptions explicitly> |

## Frozen contracts
<Auditable pre-feature behavior, identifiers, payloads and existing assertions that must not change.>

## Not yet specified
<Remaining questions, evidence paths, dispositions and owners; or none.>

## Out of scope
| Item | Why excluded |
| --- | --- |
| <Excluded behavior> | <Reason; requires a separate effort> |

## Carried debt
<Deferred med/low review findings for VALIDATE; none at PLAN.>

## Decisions
<Resolved evidence and reversible assumptions with consequences.>
```

For example, this skill's existing-file install contract gives: `init` encounters an existing worker definition -> reports already present and leaves its contents unchanged -> overwriting is forbidden. The source is `SKILL.md`'s explicit `init` idempotency rule, not an implementation run that happened not to overwrite the file.

## 5. Rules

- **Consequences belong beside each decision:** what becomes impossible, and what survives that should not? Include lifecycle effects such as mounted-but-inert controls, not just the chosen structure.
- **Frozen means pre-feature contracts, not read-only files.** New tests may extend frozen files; existing assertions and expected values remain unchanged. Artifacts created earlier in this feature are not pre-feature contracts.
- **Execution context is not FR-only:** builders and reviewers need relevant `Implements:`/`UAT:` FRs plus applicable acceptance examples and their sources, seams, frozen contracts, implementation/testing decisions and referenced decisions. Identify those sections or paths in ticket Notes without copying the spec or loading unrelated features.
- Keep behavior and decisions here; file-level recipes belong in tickets, architectural detail in `design.md` only when needed. Cite research paths instead of pasting evidence. The default gate flags size above 15 KiB, with a hard threshold at 24 KiB; resolve findings before proceeding.
