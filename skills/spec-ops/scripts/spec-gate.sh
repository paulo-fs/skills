#!/usr/bin/env bash
# spec-gate.sh — the mechanical half of review, at zero model cost.
#
# Everything here is a check an agent would otherwise perform by READING, which is both
# expensive and unreliable. Output is deliberately terse: it is agent input.
#
#   spec-gate.sh spec     <feature-dir>            spec size + template conformance
#   spec-gate.sh tickets  <feature-dir>            ticket header validity + edge sanity
#   spec-gate.sh boundary <feature-dir>            worktree vs union of Where: + vanished work
#   spec-gate.sh honesty  [base-ref]               skipped/deleted/weakened tests in the diff
#   spec-gate.sh gate     ["<literal command>"]    run it, print the literal string + exit code
#   spec-gate.sh count    "<count command>"        print a bare integer (ratchet)
#
# Exit 0 = clean, 1 = findings, 2 = usage/environment error. Findings go to stdout, one per line.
#
# Optional per-project config: `.specs/gate.conf`, sourced when present (KEY="value" shell syntax).
# Absent, every default below applies and a fresh project needs no setup at all. Keys:
#   GATE_CMD                 the project's literal gate command, used by `gate` with no argument
#   SPEC_REQUIRED_SECTIONS   pipe-separated `## ` headings a spec must carry
#   SPEC_KNOWN_SECTIONS      pipe-separated headings that are on-template (no leading `## `)
#   FR_PREFIX                requirement id prefix, e.g. RF for a Portuguese spec (default FR)
#   TEST_PATH_PATTERN        regex matching this stack's test files
#   SPEC_SMELL_BYTES / SPEC_HARD_BYTES

set -uo pipefail

# Load the project's config first; every default below yields to it.
for _c in "${SPEC_GATE_CONF:-}" .specs/gate.conf; do
  [[ -n ${_c:-} && -f $_c ]] && { . "$_c"; SPEC_GATE_CONF_USED=$_c; break; }
done

SPEC_SMELL_BYTES=${SPEC_SMELL_BYTES:-15360}   # ~15 KB — smell
SPEC_HARD_BYTES=${SPEC_HARD_BYTES:-24576}     # ~24 KB — fail
FR_PREFIX=${FR_PREFIX:-FR}
SPEC_REQUIRED_SECTIONS=${SPEC_REQUIRED_SECTIONS:-'## Problem|## Functional requirements|## Seams under test|## Out of scope'}
SPEC_KNOWN_SECTIONS=${SPEC_KNOWN_SECTIONS:-'Problem|Functional requirements|Seams under test|Implementation decisions|Testing decisions|Frozen contracts|Not yet specified|Out of scope|Decisions|Carried debt'}
TEST_PATH_PATTERN=${TEST_PATH_PATTERN:-'(^|/)(test|tests|spec|specs|__tests__)/|_test\.|\.test\.|\.spec\.|test_.*\.(py|gd)$|_spec\.rb$'}
GATE_CMD=${GATE_CMD:-}
findings=0
say() { printf '%s\n' "$*"; findings=$((findings + 1)); }
ok()  { printf 'ok: %s\n' "$*"; }

cmd_spec() {
  local dir=${1:?feature dir} spec="$1/spec.md"
  [[ -f $spec ]] || { echo "error: no $spec" >&2; exit 2; }
  local bytes; bytes=$(wc -c <"$spec" | tr -d ' ')
  if   (( bytes > SPEC_HARD_BYTES )); then say "spec ${bytes}B > hard ${SPEC_HARD_BYTES}B — split into design.md or ticket Notes"
  elif (( bytes > SPEC_SMELL_BYTES )); then say "spec ${bytes}B > smell ${SPEC_SMELL_BYTES}B — recipes or pasted evidence, almost always"
  else ok "spec ${bytes}B"; fi

  local h missing=0
  local IFS='|'
  for h in $SPEC_REQUIRED_SECTIONS; do
    grep -qF "$h" "$spec" || { say "missing section: $h"; missing=1; }
  done
  unset IFS

  # Off-template sections are only meaningful for a spec that FOLLOWS the template. A document
  # missing required sections was written under another process (or another skill); enumerating its
  # sections produces noise with no action attached, so the check is skipped and says so.
  local known="$SPEC_KNOWN_SECTIONS"
  if (( missing )); then
    echo "skip: off-template scan (this spec does not follow the template)"
    known='.*'
  fi
  # A heading may carry a qualifier — `## Problema (UAT do dono 2026-07-25)` is good practice, not a
  # violation. Match the stem: everything before the first " (", " —" or " /", case-insensitively.
  grep -E '^## ' "$spec" | sed -E 's/^## //; s/ +[(—\/].*$//; s/ +$//' | tr '[:upper:]' '[:lower:]' \
    | while read -r h; do
        [[ $h =~ ^($(echo "$known" | tr '[:upper:]' '[:lower:]'))$ ]] || echo "off-template section: ## $h"
      done | sort -u | grep . && findings=$((findings + 1))

  # Evidence pasted where a path belongs
  local fences; fences=$(grep -c '^```' "$spec")
  (( fences > 8 )) && say "$((fences / 2)) fenced blocks — fog evidence belongs cited by path, not pasted"

  # FR ids must be unique and referenced by at least one ticket
  local dupes; dupes=$(grep -oE "^- \*\*${FR_PREFIX}-[0-9]+\*\*" "$spec" | grep -oE "${FR_PREFIX}-[0-9]+" | sort | uniq -d)
  [[ -n $dupes ]] && say "duplicate ${FR_PREFIX} ids: $(echo "$dupes" | tr '\n' ' ')"
  if [[ -d $dir/tickets ]]; then
    local fr
    for fr in $(grep -oE "${FR_PREFIX}-[0-9]+" "$spec" | sort -u); do
      grep -qE "^Implements:.*\b$fr\b" "$dir"/tickets/*.md 2>/dev/null \
        || grep -qE "^UAT:.*\b$fr\b" "$dir"/tickets/*.md 2>/dev/null \
        || say "$fr implemented by no ticket (unimplemented, or a UAT id nobody owns)"
    done
  fi
  return 0
}

cmd_tickets() {
  local dir=${1:?feature dir}/tickets
  [[ -d $dir ]] || { echo "error: no $dir" >&2; exit 2; }
  local f n
  for f in "$dir"/*.md; do
    n=$(basename "$f")
    local k
    for k in "Blocked by" Where Reads Class TDD UAT Implements Status; do
      grep -qE "^$k:" "$f" || say "$n: missing header field '$k:'"
    done
    grep -qE '^Class: (scout|mechanical|standard|critical)$'   "$f" || say "$n: invalid Class"
    grep -qE '^TDD: (red-green|ratchet|none)$'                 "$f" || say "$n: invalid TDD"
    grep -qE '^Status: (ready|dispatched|done|failed|superseded)$' "$f" || say "$n: invalid Status"
    grep -qE '^Where: *$'  "$f" && say "$n: empty Where: — no parallelism contract, no boundary check"
    grep -qE '^Where:.*(\*\*/\*|^Where: \.$| \. )' "$f" && say "$n: Where: matches the whole tree"
    grep -qE '^## Done when' "$f" || say "$n: no '## Done when'"
    grep -qE '^- \[[ x]\] gate:' "$f" || say "$n: 'Done when' carries no literal gate line"
    # a mechanical ticket that asks for judgment is misclassified
    if grep -qE '^Class: mechanical$' "$f" && grep -qiE 'choose|decide|pick the|closest|as appropriate|escolh|decid' "$f"; then
      say "$n: Class: mechanical but the body asks for a judgment call — promote to standard"
    fi
    # blocked-by must point at a ticket that exists
    local dep
    for dep in $(sed -nE 's/^Blocked by: *//p' "$f" | tr ',' ' '); do
      [[ $dep == none ]] && continue
      ls "$dir"/"$dep"-*.md >/dev/null 2>&1 || say "$n: Blocked by $dep — no such ticket"
    done
  done
  (( findings == 0 )) && ok "$(ls "$dir"/*.md | wc -l | tr -d ' ') tickets, headers valid"
  return 0
}

cmd_boundary() {
  local dir=${1:?feature dir} base="$1/.baseline"
  local globs; globs=$(sed -nE 's/^Where: *//p' "$dir"/tickets/*.md 2>/dev/null | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$')
  [[ -z $globs ]] && { echo "error: no Where: globs in $dir/tickets" >&2; exit 2; }
  local changed; changed=$(git status --porcelain | cut -c4- | sed 's/^"//; s/"$//')
  local p g hit
  while IFS= read -r p; do
    [[ -z $p ]] && continue
    case $p in .specs/*) continue;; esac      # orchestrator-owned, outside every ticket by design
    # If the file was already in baseline, it's not a stray write from this feature
    if [[ -f $base ]] && grep -qF "$p" "$base"; then continue; fi
    hit=0
    while IFS= read -r g; do
      # shellcheck disable=SC2053
      [[ $p == $g || $p == ${g%/}/* || $p == ${g%\*}* ]] && { hit=1; break; }
    done <<<"$globs"
    (( hit )) || say "stray write outside every Where:: $p"
  done <<<"$changed"
  if [[ -f $base ]]; then
    while IFS= read -r p; do
      [[ -z $p ]] && continue
      [[ -e $p ]] || git diff --cached --name-only | grep -qxF "$p" || say "VANISHED (wall 3 unless the index restores it): $p"
    done < <(cut -c4- "$base" | sed 's/^"//; s/"$//')
  fi
  (( findings == 0 )) && ok "worktree within Where:, nothing vanished"
  return 0
}

cmd_honesty() {
  local base=${1:-HEAD}
  local testfiles; testfiles=$(git diff --name-only "$base" 2>/dev/null | grep -iE "$TEST_PATH_PATTERN")
  [[ -z $testfiles ]] && { ok "no test files in the diff"; return 0; }
  local pat='\.skip\(|\.only\(|xit\(|xdescribe\(|@pytest\.mark\.skip|@unittest\.skip|t\.Skip\(|#\[ignore\]|^\s*pending\(|^\+\s*skip '
  local added; added=$(git diff -U0 "$base" -- $testfiles | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nE "$pat")
  [[ -n $added ]] && say "test cases silently disabled:"$'\n'"$added"
  local del; del=$(git diff --numstat "$base" -- $testfiles | awk '$2 > 0 {rm += $2} END {print rm + 0}')
  (( del > 0 )) && say "$del lines removed from test files — an intentional behavior change is named in the report, not left implicit"
  local gone; gone=$(git diff --diff-filter=D --name-only "$base" -- $testfiles)
  [[ -n $gone ]] && say "test files DELETED: $(echo "$gone" | tr '\n' ' ')"
  (( findings == 0 )) && ok "no skipped, deleted or shrunk tests"
  return 0
}

cmd_gate() {
  local c=${1:-$GATE_CMD}
  [[ -z $c ]] && { echo "error: no command given and no GATE_CMD in .specs/gate.conf" >&2; exit 2; }
  local out rc
  out=$(eval "$c" 2>&1); rc=$?
  printf 'gate: %s\nexit: %d\n' "$c" "$rc"
  (( rc != 0 )) && { printf '%s\n' "$out" | tail -40; return 1; }
  return 0
}

cmd_count() { local c=${1:?command}; eval "$c" 2>/dev/null | grep -oE '[0-9]+' | tail -1; }

[[ -n ${SPEC_GATE_CONF_USED:-} && ${1:-} != count ]] && printf 'conf: %s\n' "$SPEC_GATE_CONF_USED"

case ${1:-} in
  spec)     shift; cmd_spec "$@";;
  tickets)  shift; cmd_tickets "$@";;
  boundary) shift; cmd_boundary "$@";;
  honesty)  shift; cmd_honesty "$@";;
  gate)     shift; cmd_gate "$@"; exit $?;;
  count)    shift; cmd_count "$@"; exit 0;;
  *) sed -n '2,20p' "$0"; exit 2;;
esac
(( findings > 0 )) && exit 1
exit 0
