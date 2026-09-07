#!/usr/bin/env bash
# spec-gate.sh — the mechanical half of review, at zero model cost.
#
# Everything here is a check an agent would otherwise perform by READING, which is both
# expensive and unreliable. Output is deliberately terse: it is agent input.
#
#   spec-gate.sh spec     <feature-dir>            spec size + template conformance
#   spec-gate.sh tickets  <feature-dir>            ticket header validity + edge sanity
#   spec-gate.sh snapshot <snapshot-file>           capture dirty state without touching the index
#   spec-gate.sh boundary <feature-dir> [options]   changed paths vs ticket/wave Where:
#                       [--since <snapshot>] [--ticket <ticket>]... [--where <pattern>]...
#   spec-gate.sh honesty  [base-ref]               explicit disables and deleted test files
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
  # shellcheck source=/dev/null
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

require_worktree() {
  local prefix
  [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]] \
    || { echo 'error: not a git worktree' >&2; exit 2; }
  prefix=$(git rev-parse --show-prefix) || exit 2
  [[ -z $prefix ]] || { echo 'error: run from the git worktree root' >&2; exit 2; }
}

encode_path() { printf '%s' "$1" | base64 | tr -d '\n'; }
decode_path() { printf '%s' "$1" | base64 --decode; }

status_records() {
  local entry status path encoded original raw
  raw=$(mktemp "${TMPDIR:-/tmp}/spec-gate-status.XXXXXX") \
    || { echo 'error: cannot create status buffer' >&2; return 2; }
  # Ignore settings must not hide dirty submodules from safety checks.
  if ! git status --porcelain=v1 -z --untracked-files=all --ignore-submodules=none >"$raw"; then
    rm -f "$raw"
    echo 'error: cannot read git status' >&2
    return 2
  fi
  # Error paths unlink our temporary buffer only immediately before returning.
  # shellcheck disable=SC2094
  while IFS= read -r -d '' entry; do
    status=${entry:0:2}
    path=${entry:3}
    encoded=$(encode_path "$path")
    printf '%s\t%s\n' "$status" "$encoded"
    if [[ $status == *R* || $status == *C* ]]; then
      IFS= read -r -d '' original \
        || { rm -f "$raw"; echo 'error: incomplete rename status' >&2; return 2; }
      encoded=$(encode_path "$original")
      printf '%s\t%s\n' "$status" "$encoded"
    fi
  done <"$raw"
  rm -f "$raw"
}

file_mode() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

worktree_hash() {
  local path=$1 target
  if [[ -L $path ]]; then
    target=$(readlink "$path") || return 2
    printf '%s' "$target" | git hash-object --stdin
  elif [[ -f $path ]]; then
    git hash-object -- "$path"
  elif [[ -d $path ]]; then
    echo "error: unsupported dirty directory/submodule: $path; preserve its changes and make it clean before retrying" >&2
    return 2
  else
    printf 'MISSING'
  fi
}

write_manifest() {
  local target=$1 status encoded path hash mode index_hash records
  records=$(status_records) || return 2
  : >"$target" || return 2
  while IFS=$'\t' read -r status encoded; do
    [[ -n $encoded ]] || continue
    path=$(decode_path "$encoded") || return 2
    case $path in .specs/*) continue;; esac
    hash=$(worktree_hash "$path") \
      || { echo "error: cannot hash worktree path: $path" >&2; return 2; }
    mode=MISSING
    if [[ -e $path || -L $path ]]; then
      mode=$(file_mode "$path") \
        || { echo "error: cannot read mode: $path" >&2; return 2; }
    fi
    index_hash=$(git ls-files -s -- "$path" | git hash-object --stdin) \
      || { echo "error: cannot hash index entry: $path" >&2; return 2; }
    printf '%s\t%s\t%s\t%s\t%s\n' "$encoded" "$status" "$hash" "$mode" "$index_hash" >>"$target" || return 2
  done <<<"$records"
  sort -u -o "$target" "$target" || return 2
}

cmd_spec() {
  local dir=${1:?feature dir} spec="$1/spec.md"
  [[ -f $spec ]] || { echo "error: no $spec" >&2; exit 2; }
  local bytes; bytes=$(wc -c <"$spec" | tr -d ' ') \
    || { echo "error: cannot read $spec" >&2; return 2; }
  if   (( bytes > SPEC_HARD_BYTES )); then say "spec ${bytes}B > hard ${SPEC_HARD_BYTES}B — split into design.md or ticket Notes"
  elif (( bytes > SPEC_SMELL_BYTES )); then say "spec ${bytes}B > smell ${SPEC_SMELL_BYTES}B — recipes or pasted evidence, almost always"
  else ok "spec ${bytes}B"; fi

  local h headings missing=0
  headings=$(sed -nE '/^## / { s/ +[(—\/].*$//; s/ +$//; p; }' "$spec") \
    || { echo "error: cannot read $spec" >&2; return 2; }
  local IFS='|'
  for h in $SPEC_REQUIRED_SECTIONS; do
    grep -qFx "$h" <<<"$headings" || { say "missing section: $h"; missing=1; }
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
    # Requirement IDs are whitespace-free tokens, not arbitrary input lines.
    # shellcheck disable=SC2013
    for fr in $(grep -oE "${FR_PREFIX}-[0-9]+" "$spec" | sort -u); do
      grep -qE "^Implements:.*\b$fr\b" "$dir"/tickets/*.md 2>/dev/null \
        || grep -qE "^UAT:.*\b$fr\b" "$dir"/tickets/*.md 2>/dev/null \
        || say "$fr implemented by no ticket (unimplemented, or a UAT id nobody owns)"
    done
  fi
  return 0
}

whole_tree_path() {
  case $1 in
    .|./|'*'|'**'|'**/*') return 0;;
    *) return 1;;
  esac
}

cmd_tickets() {
  local dir=${1:?feature dir}/tickets
  [[ -d $dir ]] || { echo "error: no $dir" >&2; exit 2; }
  local f n where pattern count=0 seen_ids=' '
  for f in "$dir"/*.md; do
    [[ -f $f ]] || continue
    count=$((count + 1))
    n=$(basename "$f")
    where=$(sed -nE 's/^Where: *//p' "$f" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') \
      || { echo "error: cannot read ticket $f" >&2; return 2; }
    local k
    for k in "Blocked by" Where Reads Class TDD UAT Implements Status; do
      grep -qE "^$k:" "$f" || say "$n: missing header field '$k:'"
    done
    grep -qE '^Class: (scout|mechanical|standard|critical)$'   "$f" || say "$n: invalid Class"
    grep -qE '^TDD: (red-green|ratchet|none)$'                 "$f" || say "$n: invalid TDD"
    grep -qE '^Status: (ready|dispatched|done|failed|superseded)$' "$f" || say "$n: invalid Status"
    grep -qE '^Where: *$'  "$f" && say "$n: empty Where: — no parallelism contract, no boundary check"
    while IFS= read -r pattern; do
      whole_tree_path "$pattern" && say "$n: Where: matches the whole tree"
    done <<<"$where"
    grep -qE '^## Done when' "$f" || say "$n: no '## Done when'"
    grep -qE '^- \[[ x]\] gate:' "$f" || say "$n: 'Done when' carries no literal gate line"
    # a mechanical ticket that asks for judgment is misclassified
    if grep -qE '^Class: mechanical$' "$f" && grep -qiE 'choose|decide|pick the|closest|as appropriate|escolh|decid' "$f"; then
      say "$n: Class: mechanical but the body asks for a judgment call — promote to standard"
    fi
    # blocked-by must point at a ticket that exists
    local dep current_id current_num dep_num
    current_id=${n%%-*}
    [[ $current_id =~ ^[0-9]+$ ]] \
      || { say "$n: filename must start with a numeric ticket id"; continue; }
    # Normalize decimal identities as strings, without integer overflow.
    current_num=${current_id#"${current_id%%[!0]*}"}
    current_num=${current_num:-0}
    if [[ $seen_ids == *" $current_num "* ]]; then
      say "$n: duplicate numeric ticket id $current_num -- use unique numeric prefixes"
    fi
    seen_ids="$seen_ids$current_num "
    for dep in $(sed -nE 's/^Blocked by: *//p' "$f" | tr ',' ' '); do
      [[ $dep == none ]] && continue
      if [[ ! $dep =~ ^[0-9]+$ ]]; then
        say "$n: Blocked by $dep — dependency id must be numeric"
        continue
      fi
      ls "$dir"/"$dep"-*.md >/dev/null 2>&1 || { say "$n: Blocked by $dep — no such ticket"; continue; }
      dep_num=$((10#$dep))
      (( dep_num < current_num )) || say "$n: Blocked by $dep — dependencies must have a lower ticket id"
    done
  done
  (( count > 0 )) || { echo "error: no tickets in $dir" >&2; exit 2; }
  (( findings == 0 )) && ok "$count tickets, headers valid"
  return 0
}

cmd_snapshot() {
  local target=${1:?snapshot file} parent recovery manifest encoded path recovery_key copy_failed=0
  require_worktree
  parent=$(dirname "$target")
  [[ -d $parent ]] || { echo "error: no $parent" >&2; exit 2; }
  [[ ! -e $target && ! -L $target ]] || { echo "error: snapshot exists: $target" >&2; exit 2; }

  recovery=$(git rev-parse --git-path "spec-ops/$(printf '%s' "$target" | git hash-object --stdin)") \
    || { echo "error: not a git worktree" >&2; exit 2; }
  [[ ! -e $recovery && ! -L $recovery ]] || { echo "error: recovery exists: $recovery" >&2; exit 2; }
  mkdir -p "$recovery/files" \
    || { echo "error: cannot create recovery directory: $recovery" >&2; return 2; }
  manifest=$(mktemp "${TMPDIR:-/tmp}/spec-gate-snapshot.XXXXXX") \
    || { echo 'error: cannot create snapshot manifest' >&2; return 2; }
  if ! write_manifest "$manifest"; then
    echo 'error: cannot read current worktree state' >&2
    rm -f "$manifest"
    rm -rf "$recovery"
    return 2
  fi
  if ! {
    printf '# spec-gate snapshot v1\n'
    printf '# recovery: %s\n' "$recovery"
    cat "$manifest"
  } >"$target"; then
    echo "error: cannot write snapshot: $target" >&2
    rm -f "$manifest" "$target"
    rm -rf "$recovery"
    return 2
  fi

  while IFS=$'\t' read -r encoded _; do
    path=$(decode_path "$encoded") || { copy_failed=1; break; }
    if [[ -e $path || -L $path ]]; then
      recovery_key=$(printf '%s' "$path" | git hash-object --stdin) || { copy_failed=1; break; }
      cp -pPR "./$path" "$recovery/files/$recovery_key" || copy_failed=1
    fi
  done <"$manifest"
  if (( copy_failed )) || ! cp "$target" "$recovery/manifest"; then
    echo 'error: recovery snapshot is incomplete' >&2
    rm -f "$manifest" "$target"
    rm -rf "$recovery"
    return 2
  fi
  rm -f "$manifest"
  ok "snapshot $target; recovery $recovery"
}

path_allowed() {
  local path=$1 patterns=$2 pattern
  while IFS= read -r pattern; do
    [[ -z $pattern ]] && continue
    if [[ $pattern == */ ]]; then
      [[ $path == "$pattern"* ]] && return 0
    elif [[ $pattern == *'*'* || $pattern == *'?'* || $pattern == *'['* ]]; then
      # Where explicitly authorizes Bash patterns.
      # shellcheck disable=SC2053
      [[ $path == $pattern ]] && return 0
    elif [[ $path == "$pattern" ]]; then
      return 0
    fi
  done <"$patterns"
  return 1
}

cmd_boundary() {
  local dir=${1:?feature dir} since='' ticket_files='' direct_where='' arg patterns current keys encoded old new path
  require_worktree
  shift
  while (( $# )); do
    arg=$1
    case $arg in
      --since)
        [[ $# -ge 2 ]] || { echo 'error: --since needs a snapshot' >&2; exit 2; }
        since=$2
        shift 2
        ;;
      --ticket)
        [[ $# -ge 2 ]] || { echo 'error: --ticket needs a path' >&2; exit 2; }
        ticket_files=${ticket_files}${2}$'\n'
        shift 2
        ;;
      --where)
        [[ $# -ge 2 ]] || { echo 'error: --where needs a pattern' >&2; exit 2; }
        direct_where=${direct_where}${2}$'\n'
        shift 2
        ;;
      *) echo "error: unknown boundary option: $arg" >&2; exit 2;;
    esac
  done

  patterns=$(mktemp "${TMPDIR:-/tmp}/spec-gate-patterns.XXXXXX") || return 2
  [[ -n $direct_where ]] && printf '%s' "$direct_where" >>"$patterns"
  if [[ -n $ticket_files ]]; then
    while IFS= read -r arg; do
      [[ -z $arg ]] && continue
      [[ -f $arg ]] || { rm -f "$patterns"; echo "error: no ticket $arg" >&2; exit 2; }
      sed -nE 's/^Where: *//p' "$arg" >>"$patterns" \
        || { rm -f "$patterns"; echo "error: cannot read ticket $arg" >&2; return 2; }
    done <<<"$ticket_files"
  elif [[ -z $direct_where ]]; then
    local found=0 file
    for file in "$dir"/tickets/*.md; do
      [[ -f $file ]] || continue
      found=1
      sed -nE 's/^Where: *//p' "$file" >>"$patterns" \
        || { rm -f "$patterns"; echo "error: cannot read ticket $file" >&2; return 2; }
    done
    (( found )) || { rm -f "$patterns"; echo "error: no tickets in $dir/tickets" >&2; exit 2; }
  fi
  if ! tr ',' '\n' <"$patterns" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;/^$/d' >"$patterns.clean" \
    || ! mv "$patterns.clean" "$patterns"; then
    rm -f "$patterns" "$patterns.clean"
    echo 'error: cannot read Where: paths' >&2
    return 2
  fi
  [[ -s $patterns ]] || { rm -f "$patterns"; echo 'error: no Where: paths' >&2; exit 2; }
  while IFS= read -r arg; do
    whole_tree_path "$arg" && say 'Where: matches the whole tree'
  done <"$patterns"
  (( findings == 0 )) || { rm -f "$patterns"; return 0; }

  current=$(mktemp "${TMPDIR:-/tmp}/spec-gate-current.XXXXXX") || { rm -f "$patterns"; return 2; }
  if ! write_manifest "$current"; then
    rm -f "$patterns" "$current"
    echo 'error: cannot read current worktree state' >&2
    exit 2
  fi
  if [[ -n $since ]]; then
    [[ -f $since ]] || { rm -f "$patterns" "$current"; echo "error: no snapshot $since" >&2; exit 2; }
    grep -qF '# spec-gate snapshot v1' "$since" \
      || { rm -f "$patterns" "$current"; echo "error: invalid snapshot $since" >&2; exit 2; }
    keys=$(mktemp "${TMPDIR:-/tmp}/spec-gate-keys.XXXXXX") || { rm -f "$patterns" "$current"; return 2; }
    if ! awk -F '\t' '!/^#/ {print $1}' "$since" "$current" | sort -u >"$keys"; then
      rm -f "$patterns" "$current" "$keys"
      echo 'error: cannot read snapshot keys' >&2
      return 2
    fi
    # Error cleanup unlinks this temporary key list only before returning.
    # shellcheck disable=SC2094
    while IFS= read -r encoded; do
      [[ -z $encoded ]] && continue
      if ! old=$(awk -F '\t' -v key="$encoded" '$1 == key' "$since") \
        || ! new=$(awk -F '\t' -v key="$encoded" '$1 == key' "$current"); then
        rm -f "$patterns" "$current" "$keys"
        echo 'error: cannot read snapshot entry' >&2
        return 2
      fi
      [[ $old == "$new" ]] && continue
      path=$(decode_path "$encoded")
      path_allowed "$path" "$patterns" || say "write outside selected Where:: $path"
    done <"$keys"
    rm -f "$keys"
  else
    while IFS=$'\t' read -r encoded _; do
      path=$(decode_path "$encoded")
      path_allowed "$path" "$patterns" || say "write outside selected Where:: $path"
    done <"$current"
  fi
  rm -f "$patterns" "$current"
  (( findings == 0 )) && ok "changed paths within selected Where:"
  return 0
}

cmd_honesty() {
  local base=${1:-HEAD}
  require_worktree
  git rev-parse --verify "$base^{commit}" >/dev/null 2>&1 \
    || { echo "error: invalid base ref: $base" >&2; exit 2; }
  local pat='\.(skip|only|todo)\(|xit\(|xdescribe\(|@pytest\.mark\.skip|@unittest\.skip|t\.Skip\(|#\[ignore\]|^[[:space:]]*pending\(|^[[:space:]]*skip '
  local status encoded path original added records changes patch view rc seen=0
  local diff_args
  records=$(status_records) || return 2
  while IFS=$'\t' read -r status encoded; do
    [[ $status == '??' ]] || continue
    path=$(decode_path "$encoded") || return 2
    [[ $path =~ $TEST_PATH_PATTERN ]] || continue
    seen=1
    added=$(grep -nE "$pat" -- "$path"); rc=$?
    (( rc <= 1 )) || { echo "error: cannot read test $path" >&2; return 2; }
    [[ -n $added ]] && say "test cases silently disabled in $path:"$'\n'"$added"
  done <<<"$records"

  changes=$(mktemp "${TMPDIR:-/tmp}/spec-gate-diff.XXXXXX") || return 2
  # Compare both publishable index content and current files against the requested base.
  for view in index worktree; do
    diff_args=("$base")
    [[ $view == index ]] && diff_args=(--cached "$base")
    if ! git diff --no-color --no-ext-diff --no-textconv --find-renames --name-status -z "${diff_args[@]}" -- >"$changes"; then
      rm -f "$changes"
      echo "error: cannot read $view diff" >&2
      return 2
    fi
    # Error cleanup unlinks this temporary diff buffer only before returning.
    # shellcheck disable=SC2094
    while IFS= read -r -d '' status; do
      IFS= read -r -d '' original \
        || { rm -f "$changes"; echo 'error: incomplete diff path' >&2; return 2; }
      path=$original
      if [[ $status == R* || $status == C* ]]; then
        IFS= read -r -d '' path \
          || { rm -f "$changes"; echo 'error: incomplete rename diff' >&2; return 2; }
      fi
      [[ $original =~ $TEST_PATH_PATTERN || $path =~ $TEST_PATH_PATTERN ]] || continue
      seen=1
      if [[ $status == D || ( $status == R* && ! $path =~ $TEST_PATH_PATTERN ) ]]; then
        say "test file DELETED: $original"
        continue
      fi
      [[ $path =~ $TEST_PATH_PATTERN ]] || continue
      if [[ $status == R* && ! $original =~ $TEST_PATH_PATTERN ]]; then
        # Entering test discovery introduces the entire test, even for an unchanged rename.
        if [[ $view == index ]]; then
          patch=$(git cat-file blob ":$path"); rc=$?
        else
          patch=$(cat -- "$path"); rc=$?
        fi
        if (( rc != 0 )); then
          rm -f "$changes"
          echo "error: cannot read renamed test $path" >&2
          return 2
        fi
        added=$(printf '%s\n' "$patch" | grep -nE "$pat"); rc=$?
      else
        if ! patch=$(git diff --no-color --no-ext-diff --no-textconv --find-renames -U0 "${diff_args[@]}" -- "$original" "$path"); then
          rm -f "$changes"
          echo "error: cannot read test diff $path" >&2
          return 2
        fi
        added=$(printf '%s\n' "$patch" | sed -n '/^+++ /d; s/^+//p' | grep -nE "$pat"); rc=$?
      fi
      if (( rc > 1 )); then
        rm -f "$changes"
        echo "error: cannot inspect test diff $path" >&2
        return 2
      fi
      [[ -n $added ]] && say "test cases silently disabled in $path:"$'\n'"$added"
    done <"$changes"
  done
  rm -f "$changes"
  (( seen == 0 )) && ok "no test files in the diff"
  (( seen > 0 && findings == 0 )) && ok "no skipped or deleted tests; assertion changes require review"
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

cmd_count() {
  local c=${1:?command} out rc
  out=$(eval "$c" 2>&1); rc=$?
  if (( rc != 0 )); then
    printf 'error: count command exited %d: %s\n' "$rc" "$out" >&2
    return 2
  fi
  if [[ ! $out =~ ^[0-9]+$ ]]; then
    printf 'error: count command must print one bare integer: %s\n' "$out" >&2
    return 2
  fi
  printf '%s\n' "$out"
}

[[ -n ${SPEC_GATE_CONF_USED:-} && ${1:-} != count ]] && printf 'conf: %s\n' "$SPEC_GATE_CONF_USED"

case ${1:-} in
  spec|tickets|snapshot|boundary|count)
    [[ -n ${2:-} ]] || { echo "error: $1 needs an argument" >&2; exit 2; }
    ;;
esac

case ${1:-} in
  spec)     shift; cmd_spec "$@";;
  tickets)  shift; cmd_tickets "$@";;
  snapshot) shift; cmd_snapshot "$@"; exit $?;;
  boundary) shift; cmd_boundary "$@";;
  honesty)  shift; cmd_honesty "$@";;
  gate)     shift; cmd_gate "$@"; exit $?;;
  count)    shift; cmd_count "$@"; exit $?;;
  *) sed -n '2,20p' "$0"; exit 2;;
esac
rc=$?
(( rc == 0 )) || exit "$rc"
(( findings > 0 )) && exit 1
exit 0
