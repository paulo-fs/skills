# Skills

Personal agent skills for software engineering workflows.

## Installation

Install with [skills.sh](https://skills.sh):

```bash
npx skills@latest add paulo-fs/skills
```

## Available skills

### spec-ops

Spec-driven planning and verified execution: write a spec, split it into tracer-bullet tickets, implement each slice, and validate the result.

Common commands:

```text
/spec-ops init [--tracked]
/spec-ops plan <name>
/spec-ops tickets <name>
/spec-ops do [<name>|<ticket>|<path>]
/spec-ops validate <name>
/spec-ops reconcile <name>
/spec-ops promote <name>
```

See [`skills/spec-ops/SKILL.md`](skills/spec-ops/SKILL.md) for the complete workflow.

## License

[MIT](LICENSE)
