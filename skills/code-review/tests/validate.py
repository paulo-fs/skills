"""Validate the code-review skill documents without external dependencies."""

import re
import sys
from pathlib import Path


def validate(root: Path) -> list[str]:
    errors = []
    skill = root / "SKILL.md"
    if not skill.is_file():
        return ["Missing SKILL.md"]

    text = skill.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return ["Missing opening frontmatter delimiter"]

    try:
        end = lines.index("---", 1)
    except ValueError:
        return ["Missing closing frontmatter delimiter"]

    frontmatter = "\n".join(lines[1:end])
    for field in ("name", "description", "license"):
        matches = re.findall(rf"^{field}: (.+)$", frontmatter, re.MULTILINE)
        if len(matches) != 1:
            errors.append(f"Expected one inline {field} field")

    name = re.search(r"^name: (.+)$", frontmatter, re.MULTILINE)
    if name and (name[1] != root.name or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name[1])):
        errors.append("Skill name must match its kebab-case directory")

    description = re.search(r"^description: (.+)$", frontmatter, re.MULTILINE)
    if description:
        value = description[1].strip('"')
        if not 1 <= len(value) < 1024 or value.startswith((">", "|")):
            errors.append("Description must be a nonempty inline value under 1024 characters")
        if not all(term in value.lower() for term in ("review", "not for")):
            errors.append("Description must identify its use and exclusions")

    if "<" in frontmatter or ">" in frontmatter:
        errors.append("Frontmatter must not contain angle brackets")
    if re.search(r"^(model|tools):", frontmatter, re.MULTILINE):
        errors.append("Provider-specific tool/model bindings are not supported")
    if len(lines[end + 1:]) >= 500:
        errors.append("Keep the main skill body below 500 lines")
    if any(path.name.lower() == "readme.md" for path in root.rglob("*")):
        errors.append("Keep human onboarding in the repository README, outside the skill")

    for document in sorted(root.rglob("*.md")):
        body = document.read_text(encoding="utf-8")
        relative = document.relative_to(root)
        if not body.endswith("\n"):
            errors.append(f"{relative}: missing final newline")
        if any(line != line.rstrip() for line in body.splitlines()):
            errors.append(f"{relative}: trailing whitespace")
        prose = re.sub(r"^```[^\n]*\n.*?^```\s*$", "", body, flags=re.MULTILINE | re.DOTALL)
        for target in re.findall(r"\]\(([^)]+)\)", prose):
            if target.startswith(("https://", "http://", "#", "mailto:")):
                continue
            destination = (document.parent / target.split("#", 1)[0]).resolve()
            if not destination.is_file():
                errors.append(f"{relative}: broken local link {target}")

    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    errors = validate(root)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1

    count = len(list(root.rglob("*.md")))
    print(f"PASS: {count} Markdown files; frontmatter, links, size, and document hygiene")
    return 0


if __name__ == "__main__":
    sys.exit(main())
