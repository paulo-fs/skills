# Backend review lenses

Load the applicable sections when a patch touches these mechanisms. These are investigative questions, not automatic rejection rules.

## Input, authorization, and external calls

- Can the changed entry point receive the failing input? Trace validation, coercion, ownership checks, tenant scope, and authorization before sensitive work. Unknown fields matter when they can cross a mass-assignment or trust boundary; rejection is not universally required.
- Are interpolated SQL, shell, URL, or template values actually user-controlled? Verify parameterization and the correct escaping boundary. For external requests, check applicable destination restrictions, timeouts, and retry semantics.
- Does new logging or response data expose secrets or sensitive fields? Name the exact new field and sink without copying real credentials into the review.
- Investigate dependency vulnerabilities only for changed dependencies or an explicitly requested audit; distinguish advisory exposure from a demonstrated reachable exploit.

## Queries and ORM integrity

- Trace every field accessed downstream to `attributes`, `select`, `include`, scopes, aliases, or explicit hydration. Model typing does not guarantee selected data.
- Check nullability, empty results, raw results versus instances, virtual getters, nested associations, and constructor defaults.
- Compare new fields against write-side allowlists, insert/update mappers, bulk writes, and cache serializers. Verify that patching a field actually persists it.
- Check joins and aggregates against all sources of the affected activity, such as initial sales and renewal charges. Do not expand unrelated reporting definitions without a patch connection.
- Trace raw SQL literals to domain constants where semantics changed. Search for older writers as well as readers.

## Transactions, caches, and side effects

- Identify the atomic unit and confirm that every intended query uses its transaction. Merely creating a transaction is not sufficient.
- Follow each changed write to cache invalidation, secondary read models, events, audit trails, and external side effects. Raw SQL and bulk writes often bypass the repository's normal synchronization path.
- Determine what happens if the process dies between the durable write and each side effect. Is there a transactional outbox, persisted checkpoint, idempotent consumer, reconciliation, or another durable retry?
- Do not prescribe `try/catch` for every post-commit call. Propagation may be correct, and logging-and-swallowing may lose work. Require a truthful response and a recoverable delivery contract appropriate to the operation.
- For batches, verify effects are durably recorded/dispatched per committed unit or recoverable through an equivalent mechanism. In-memory accumulation followed by one final flush may lose already-committed work on a later failure.
- When semantics of cached values change, inspect invalidation/versioning or compatibility. Assess TTL, rollout, and actual harm before prioritizing stale entries; a transient cache is not automatically critical.

## Concurrency, cascades, and retry

- Construct the concrete interleaving for a race: reads, decisions, writes, constraints, and transaction isolation. A read-then-write pattern is not proof of a race if a lock or unique constraint prevents it.
- For retryable money movement, check idempotency keys, conditional writes, external-provider behavior, and what happens after an ambiguous timeout.
- For partial cascades, test retry from the persisted intermediate state. An early parent terminal status must not make unfinished dependents unreachable. A checkpoint/state machine can be valid; parent-last is not the only solution.
- For reversal, establish the domain policy: reversible operation, intentionally irreversible action, or manual recovery. Require a symmetric inverse only when the business contract promises one.
- For cron/worker changes, identify process ownership. An exit in a shared scheduler can kill unrelated work; termination of a dedicated one-shot CLI/job can be correct. Assess the caller and deployment model before flagging `process.exit()`.

## Performance and operability

- For changed hot queries, establish data size, cardinality, frequency, added queries, and relevant indexes. Use existing plans or authorized EXPLAIN evidence where available; label unmeasured concerns.
- Analyze composite indexes by access pattern: equality prefix, range, ordering, covering benefit, leftmost-prefix reuse, and write cost. There is no universal best order independent of the query.
- Check pagination, materialization, unbounded loops, and retry amplification only where the patch creates or worsens cost.
- Identify which failure becomes undetectable or unrecoverable before alleging an observability gap. Do not require new metrics/traces for every function.
- Raise layering, coupling, or complexity only with a specific correctness, testability, or change-cost consequence, or an explicit repository rule. Avoid architectural purity as a merge gate.

## Schema changes, when in scope

Honor migration exclusions. Application/schema contract checks can still be necessary to review an ORM change; state assumptions without auditing excluded migration internals.

When schema work is included, inspect compatibility of old/new readers and writers, null/default behavior, data conversion, backfill completeness, deployment order, locking/rebuild implications, and resumability. Follow the database version and documented project migration conventions; do not impose raw SQL or a particular ALTER algorithm universally.

For rollback, simulate the real reverse order and account for writes after deployment. A down migration that drops new data is not a safe rollback merely because it exists. Use schema evidence available in a local fixture, supplied DDL, or authorized read-only inspection; never claim production verification from a model declaration.
