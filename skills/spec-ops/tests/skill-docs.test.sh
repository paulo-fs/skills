#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/spec-ops-docs.XXXXXX")
trap 'rm -rf "$FIXTURE"' EXIT
failures=0
files=0
lines=0
words=0
link_pattern='\]\(([^)]+)\)'

fail() {
  printf 'not ok: %s\n' "$*"
  failures=$((failures + 1))
}

for file in "$ROOT/SKILL.md" "$ROOT"/references/*.md "$ROOT"/agents/*.md; do
  directory=${file%/*}
  files=$((files + 1))
  lines=$((lines + $(wc -l <"$file")))
  words=$((words + $(wc -w <"$file")))
  while IFS= read -r line; do
    while [[ $line =~ $link_pattern ]]; do
      target=${BASH_REMATCH[1]}
      line=${line#*')'}
      case $target in https://*|http://*|'#'*) continue;; esac
      target=${target%%#*}
      [[ -f $directory/$target ]] || fail "broken link in $file: $target"
    done
  done <"$file"
done

for file in "$ROOT/SKILL.md" "$ROOT"/agents/*.md; do
  IFS= read -r first <"$file"
  [[ $first == '---' ]] || fail "missing frontmatter: $file"
  frontmatter=$(awk 'NR == 1 {next} /^---$/ {exit} {print}' "$file")
  name=$(printf '%s\n' "$frontmatter" | sed -n 's/^name: //p')
  description=$(printf '%s\n' "$frontmatter" | sed -n 's/^description: //p')
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "invalid role/skill name: $file"
  [[ -n $description && ${#description} -lt 1024 && $description != *$'\n'* ]] \
    || fail "description must be a short single line: $file"
  if printf '%s\n' "$frontmatter" | grep -Eq '^(model|tools):'; then
    fail "provider-specific binding returned: $file"
  fi
done

# Exercise the actual documented templates against the runtime, not copied test fixtures.
feature="$FIXTURE/feature"
mkdir -p "$feature/tickets"
awk '/^```markdown$/ {inside=1; next} /^```$/ {inside=0} inside' \
  "$ROOT/references/plan.md" >"$feature/spec.md"
awk '/^```markdown$/ {inside=1; next} /^```$/ {inside=0} inside' \
  "$ROOT/references/tickets.md" >"$feature/tickets/01-example.md"
bash "$ROOT/scripts/spec-gate.sh" spec "$feature" || fail 'documented spec template rejected'
bash "$ROOT/scripts/spec-gate.sh" tickets "$feature" || fail 'documented ticket template rejected'

printf '%s instruction files, %s lines, %s words; %s documentation failures\n' \
  "$files" "$lines" "$words" "$failures"
(( failures == 0 ))
