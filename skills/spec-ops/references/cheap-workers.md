# Model Selection and Read-Only Help

Choose an available capable model at dispatch based on task risk, context, tool access and observed results. GPT, Claude, Gemini and other model families can follow the same workflow; provider names and prices are not capability contracts.

## Classes and execution

`scout`, `mechanical`, `standard` and `critical` are risk/work labels, not prescribed model tiers ([tickets.md](tickets.md)). No class guarantees correctness; commands, boundary checks, review and UAT remain necessary. A benchmark on one workload does not establish a universal delegation policy.

Select transport/mode through [control.md](control.md#backend-selection) and verify it through [waves.md](waves.md). Model choice never waives tool permissions or verification; no provider price or benchmark replaces those checks.

Models without tools may draft plans, tickets or review hypotheses from supplied evidence, but must report **checks not run**. They cannot claim observed execution, verified review or advance any success gate. A capable tool-equipped session must perform those checks.

## Optional read-only help

- **Scout:** investigate bounded questions and return evidence with paths and limitations. The planner classifies evidence and owns decisions. Inline read-only research is equally valid; scouts are not required.
- **Refuter:** examine one finding against evidence; report confirmed, refuted or uncertain with reasons. Prefer a fresh context, optionally another model family; difference alone proves neither independence nor correctness. Never default uncertainty to refuted.

Neither role counts toward builder width. Delegate only when available and useful; report unavailable independent research/review rather than imply it happened.

Provide relevant FRs **plus applicable seams, frozen contracts and decisions**, and necessary source/guideline paths. Keep scope bounded without stripping the contracts needed to judge the work. Evidence from any helper must be checked, not accepted because of the model label.
