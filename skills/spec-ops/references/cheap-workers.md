# CHEAP WORKERS — the two delegations that never depend on width

Width measures **builder** concurrency (SKILL.md). Two kinds of worker are not builders and are
therefore available in every mode, INLINE included:

- **`scout`** — read-only sweep, fog research. Returns raw evidence **with paths**, classifies
  nothing. Every PLAN-phase exploration is one.
- **the refuter** — an adversarial second opinion on a single finding. You are buying decorrelation,
  not competence, so it must be a *different* model family from whatever produced the finding.

Both are safe because their output is verifiable at a glance: a path you open, or a verdict you can
test. That is the whole criterion — **cheap tokens are safe exactly where the verifier is stronger
than the generator** (SKILL.md § Where cheap tokens are safe).

## The gateway

A cheap-model subscription (here **OpenCode Go**, ~$10/mo, ~$60 credit-equivalent, ~100k requests,
OpenAI-compatible) buys one thing that matters, and it is **neither quality nor dollars**: **budget
isolation.** Tokens spent there do not consume the frontier subscription's limit, which is the real
ceiling on a long feature.

`opencode run -m opencode-go/<model> "<prompt>"` is a one-shot — no session, no canvas, no
orchestration. `opencode models` lists what is current; seen: `mimo-v2.5`, `kimi-k3`, `qwen3.8-max`,
`glm-5.3`, `grok-4.5`, `minimax-m3`.

| Job | Model | Why it is safe |
| --- | --- | --- |
| `scout` | `mimo-v2.5` | output is paths you can open; volume over depth |
| `mechanical` — `Done when` fully checkable by command | `kimi-k3` | the gate catches its failures for free; the only cheap executor below that did not lose quality |
| refuter | any *different* family | decorrelation, not competence |

```bash
opencode run -m opencode-go/kimi-k3 "Refute this or confirm it, briefly. Default to REFUTED when \
unsure. Claim: <finding>. Evidence: <paths + the assertion>. Would this test still pass against a \
component that does nothing?"
```

**Never** put a cheap model on planning, composing waves, judging spec fidelity, or feature code in a
codebase with invariants.

## The measurements behind all of the above

Do not rediscover these — they are why INLINE is the default and why cheap models are scoped this
narrowly ([akitaonrails.com, 2026-04-25](https://akitaonrails.com/2026/04/25/llm-benchmarks-vale-a-pena-misturar-2-modelos/)):

| One cohesive app build | Score | Wall clock |
| --- | --- | --- |
| Strong model **solo** | **97** | **18 min** |
| Strong planner + Kimi executor, hand-orchestrated | 97 | 30–40 min |
| Strong planner + mid executor, delegation forced | 92 | 25 min |
| Strong planner + small executor, delegation forced | 90 | 19 min |
| A cheap open model **as orchestrator** vs the same model working directly | **24 vs 91** | — |

With delegation *optional*, 7 of 7 frontier setups delegated **zero** times on a cohesive build.
Splitting cohesive work across models costs quality, wall clock, or both. The case the same benchmark
admits it did not test is **numerous independent tasks** — which is the `Where:`-disjoint case, and
exactly when width > 1 earns its keep ([waves.md](waves.md)).
