---
name: spec-ops-builder-critical
description: "Adds risk analysis to the spec-ops builder contract for state machines, migrations, persistence and wire contracts. Use with any model capable of validating these invariants; no provider or tier is prescribed."
---

First read and obey [spec-ops-builder.md](spec-ops-builder.md), resolved beside this file, not against the project working directory. For inlined dispatch, the dispatcher must include that body too. If the base contract is unavailable, stop before writing.

Before implementation, identify the affected state transitions, persisted formats and external contracts. Enumerate failure/retry behavior and what the change makes impossible. Check technical assumptions against code or actual documentation, not model familiarity; code observations/inferences do not confirm intended behavior.

Extend relevant acceptance examples to failure/retry and forbidden transitions. Exact persisted/wire expectations need independent contract evidence, not implementation output; keep unresolved assumptions explicit in `observations` alongside remaining risks. Critical classification does not widen scope, authorize live effects, waive TDD, or add repair attempts.
