# Skills

Personal agent skills for software engineering workflows.

## Installation

Install with [skills.sh](https://skills.sh):

```bash
npx skills@latest add paulo-fs/skills
```

## Available skills

### code-review

Evidence-driven review of backend, frontend, and full-stack PRs, local diffs, and cross-service changes. Load the relevant technical lens, trace affected contracts, require a reachable failure and a patch connection for each finding, and prioritize by impact. UI layout and focus claims require browser evidence. The default output is the conversation; reports and GitHub publication are opt-in.

Example requests:

```text
Review these PRs; exclude migrations and do not create a worktree.
Review my staged changes for regressions.
Review this React form and its API change.
Publish the findings to their respective PRs.
```

See [`skills/code-review/SKILL.md`](skills/code-review/SKILL.md). Validate its documents with Python 3.9+:

```bash
python3 skills/code-review/tests/validate.py
```

Behavioral evaluation scenarios and their expected results are in [`references/evaluate.md`](skills/code-review/references/evaluate.md). Structural checks do not establish reviewer accuracy.

### spec-ops

Model-neutral spec-driven delivery: write a spec with sourced acceptance examples, split it into vertical tickets, implement each slice, and validate the result. A shared decision policy governs backend selection, checkpoints, retries, and completion; INLINE is the default and parallel workers are optional.

Common commands:

```text
/spec-ops init [--tracked]
/spec-ops plan <name>
/spec-ops tickets <name>
/spec-ops do [<name>|<ticket>|<path>]
/spec-ops validate <name>
/spec-ops reconcile <name>
/spec-ops promote
```

See [`skills/spec-ops/SKILL.md`](skills/spec-ops/SKILL.md) for the complete workflow.

## Validation

Run from the repository root with Bash 3.2+, Git, and standard macOS/Linux utilities:

```bash
export TMPDIR="$(mktemp -d)"
bash skills/spec-ops/tests/spec-gate.test.sh
bash skills/spec-ops/tests/skill-docs.test.sh
bash skills/spec-ops/tests/workflow.test.sh
bash skills/spec-ops/tests/agent-evals.test.sh
```

The suites use isolated temporary repositories, not the working tree. Evaluator test artifacts remain under the printed temporary path for inspection. These commands do not launch LLMs.

With ShellCheck installed:

```bash
shellcheck skills/spec-ops/scripts/spec-gate.sh skills/spec-ops/tests/*.sh
```

For actual agent runs, use the fixtures and trace-based review procedure in [`references/evaluate.md`](skills/spec-ops/references/evaluate.md). Scripted tests alone do not establish model or backend compatibility.

## License

[MIT](LICENSE)
