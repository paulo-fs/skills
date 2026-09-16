# Trace changed contracts

Use only the sections relevant to the patch. The purpose of reading outside the diff is to validate its effects, not to search indefinitely for unrelated bugs.

## Runtime representation and public paths

For a changed field, trace:

```text
producer -> wire/storage representation -> hydration -> domain -> consumer -> write/response
```

- Identify whether each stage supplies a class instance, plain object, nullable value, string, integer, decimal, or Date. Verify conversion code, not only TypeScript/PHP declarations.
- Inspect nested associations and direct constructors. Fixing a standalone mapper does not fix callers that instantiate the entity themselves.
- Check both read and write mapping. A property can exist on the entity and read correctly while being silently omitted on save.
- Distinguish new records, updates, cloning, cache hits, and historical records; they may enter through different adapters.
- For value/default changes, check projections and entity constructors together. A missing status field that defaults to ACTIVE is more deceptive than undefined.

## Time, money, units, and formats

- Identify the concept before checking conversions: instant, business calendar day, local wall-clock time, duration, currency amount, minor units, or percentage.
- Trace both ends of a changed contract. A producer may send an end-of-day instant while a consumer now expects a date-only string. Choosing UTC fields does not automatically preserve the business day.
- For dates, establish process timezone, connection timezone, column behavior, parsing and rendering separately. Check raw SQL replacement serialization against the actual driver/version; do not assume it matches ORM serialization.
- Test midnight, end-of-day precision, month/year rollover, and relevant offset changes. Check inclusive versus half-open ranges and whether the final millisecond is lost.
- Exercise explicit/manual inputs as well as defaults. Moving normalization out of a shared helper changes every caller's responsibilities.
- For money, check currency provenance, decimal scale, rounding order, maximums, and serialization. Do not infer business precision from the JS/SQL type alone.

## Statuses, gates, and reachability

For each new/renamed status or narrowed condition:

1. Search relevant writers and readers, including string literals in SQL, workers, serializers, guards, and external contracts.
2. Identify values newly admitted or excluded and why.
3. Trace the state, token, event, or job produced by the gated path to its consumers.
4. Verify that retries, reversal, reactivation, and cancellation can still reach required work.
5. Check persisted old values and rollout compatibility. A renamed enum does not rewrite stored rows or queued payloads.

Do not require every switch to handle a new value if that value is intentionally impossible at that boundary. Demonstrate that it can reach the switch before reporting omission.

## Cross-service and rollout compatibility

Pin a revision for each reviewed repository. Build a compact matrix only for affected boundaries:

| Producer revision | Representation | Consumer revision | Accepted representation |
| --- | --- | --- | --- |
| Current producer | Full ISO instant | Proposed consumer | Date-only string |

Inspect the actual producer and consumer, including the deployed version when that is available. `main` is source evidence, not proof of what is deployed. Name that limitation when it affects the conclusion.

- Follow shared schema fields, cache/read-model payloads, API responses, and queue messages.
- Check whether a rolling deploy requires old/new coexistence, or a documented pause/drain/backfill establishes a different supported sequence. Do not claim that unsupported deployment order is an unconditional bug.
- A schema or connection change can break untouched raw SQL. Check predicates, grouping, casts, and presentation independently; fixing a label does not fix the query window.
- If another repository is inaccessible, report the precise contract assumption rather than inventing a producer behavior.
- Group a shared root cause once and identify all affected PRs. Keep independently fixable failures as distinct findings.
