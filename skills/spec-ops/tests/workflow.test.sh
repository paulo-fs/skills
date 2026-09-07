#!/usr/bin/env bash
# Mechanical protocol integration, not autonomous scheduling or LLM orchestration proof.
set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)/workflow.test.sh
SCRIPT=${SELF%/tests/*}/scripts/spec-gate.sh
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
if [[ ${1:-} == --resume || ${1:-} == --checkpoint ]]; then
  cd "$2"
else
  ROOT=$(mktemp -d "${TMPDIR:-/tmp}/spec-ops-workflow-test.XXXXXX")
  trap 'rm -rf "$ROOT"' EXIT
  cd "$ROOT"
fi
feature=.specs/features/example
ticket=$feature/tickets/01-feature.md
evidence=$feature/evidence
passed=0

gate() { "$BASH" .specs/bin/spec-gate.sh "$@"; }
check() {
  local expected=$1 fragment=$2 label=$3 output rc=0
  shift 3
  output=$("$@" 2>&1) || rc=$?
  printf '%s\n' "$output" >"$evidence/$label.log"
  if [[ $rc != "$expected" || $output != *"$fragment"* ]]; then
    printf 'not ok: %s (expected exit %s and <%s>, got %s)\n%s\n' \
      "$label" "$expected" "$fragment" "$rc" "$output" >&2
    exit 1
  fi
  passed=$((passed + 1))
  printf 'ok: %s\n' "$label"
}

if [[ ${1:-} == --resume ]]; then
  # Only this fixture-owned context crosses the process boundary; no exported shell state.
  # shellcheck source=/dev/null
  source "$feature/resume.env"
  [[ ${next_phase:?} == implementation && ${repair_count:?} == 0 ]]
  check 0 '' preserved-red-before-resume test "$red_hash" = "$(git hash-object tests/feature.test.sh)"
  check 1 "$red_output" still-red-on-resume gate gate "$full_gate"
  check 0 'within selected Where:' maintenance-rechecked gate boundary "$feature" \
    --since "$maintenance" --where generated/value.txt
  check 0 'snapshot' resume-snapshot gate snapshot "$resume"
  cat >src/app.sh <<'EOF'
case ${1:-feature} in
  existing) printf 'stable\n';;
  *) cat generated/value.txt;;
esac
EOF
  check 0 $'existing: PASS\nregression: PASS' resumed-tests "$BASH" tools/check.sh
  check 0 '' unchanged-literal-gate grep -qFx -- "- [ ] gate: $full_gate exits 0" "$ticket"
  check 0 'exit: 0' full-gate gate gate "$full_gate"
  check 0 'no skipped or deleted tests' honesty gate honesty "$base"
  check 0 'within selected Where:' implementation-boundary gate boundary "$feature" \
    --since "$resume" --where src/app.sh
  check 0 'within selected Where:' original-unit-boundary gate boundary "$feature" \
    --since "$original" --ticket "$ticket"
  check 0 '' regression-hash test "$red_hash" = "$(git hash-object tests/feature.test.sh)"
  check 0 '' regression-content cmp tests/feature.test.sh "$evidence/red.test.sh"
  check 0 '' existing-test-hash test "$(git rev-parse "$base:tests/existing.test.sh")" = \
    "$(git hash-object tests/existing.test.sh)"
  check 0 '' existing-test-content cmp tests/existing.test.sh <(git show "$base:tests/existing.test.sh")
  check 0 '' owner-index-content cmp "$evidence/owner.index" <(git show :owner.txt)
  check 0 '' owner-worktree-content cmp "$evidence/owner.worktree" owner.txt
  check 0 '' index-unchanged cmp "$evidence/index.entries" <(git ls-files -s)
  check 0 '' owner-staged-diff cmp "$evidence/owner.staged" <(git diff --cached --binary -- owner.txt)
  check 0 '' owner-unstaged-diff cmp "$evidence/owner.unstaged" <(git diff --binary -- owner.txt)
  check 0 '' original-snapshot-preserved cmp "$evidence/original.snapshot" "$original"
  check 0 '' no-new-commits test "$base" = "$(git rev-parse HEAD)"
  check 0 '' baseline-is-only-commit test "$(git rev-list --all --count)" = 1
  check 0 '1 tickets, headers valid' resumed-ticket gate tickets "$feature"
  printf 'resume: verified (%s checks); review and scheduling not exercised\n' "$passed"
  exit 0
fi

# The initial phase exits at its checkpoint; maintenance cannot use its shell variables.
if [[ ${1:-} == --checkpoint ]]; then
  mkdir -p .specs/bin "$feature/tickets" "$feature/.boundaries" "$evidence" src tests tools schema generated
  cp "$SCRIPT" .specs/bin/spec-gate.sh
  git init -q --template=
  cat >src/app.sh <<'EOF'
case ${1:-feature} in
  existing) printf 'stable\n';;
  *) printf 'legacy\n';;
esac
EOF
  cat >tests/existing.test.sh <<'EOF'
set -euo pipefail
[[ $("$BASH" src/app.sh existing) == stable ]]
printf 'existing: PASS\n'
EOF
  cat >tools/check.sh <<'EOF'
set -euo pipefail
for file in src/*.sh tools/*.sh tests/*.test.sh; do "$BASH" -n "$file"; done
for file in tests/*.test.sh; do "$BASH" "$file"; done
EOF
  cat >tools/generate.sh <<'EOF'
set -euo pipefail
IFS= read -r version <schema/version
printf 'v%s\n' "$version" >generated/value.txt
printf 'generated: v%s\n' "$version"
EOF
  printf '2\n' >schema/version
  printf 'baseline owner content\n' >owner.txt
  # Expand BASH in the gate process, not while recording the literal command.
  # shellcheck disable=SC2016
  full_gate='"$BASH" tools/check.sh'
  cat >"$ticket" <<EOF
# 01 - Generated feature
Blocked by: none
Where: src/app.sh, tests/feature.test.sh
Reads: tools/generate.sh, schema/version
Class: mechanical
TDD: red-green
UAT: none
Implements: FR-1
Status: ready

## Done when
- [ ] gate: $full_gate exits 0
- [ ] Existing behavior stays stable and feature returns v2.

## Notes
Phase order, snapshots, literal gate and shared repair count: ../resume.env.
EOF
  git add -A
  git -c user.name=workflow-test -c user.email=workflow@example.test \
    -c commit.gpgsign=false commit -qm baseline
  base=$(git rev-parse HEAD)
  check 0 'exit: 0' baseline-green gate gate "$full_gate"
  printf 'owner staged\n' >owner.txt
  git add owner.txt
  printf 'owner unstaged\n' >>owner.txt
  git show :owner.txt >"$evidence/owner.index"
  cp owner.txt "$evidence/owner.worktree"
  git ls-files -s >"$evidence/index.entries"
  git diff --cached --binary -- owner.txt >"$evidence/owner.staged"
  git diff --binary -- owner.txt >"$evidence/owner.unstaged"
  original=$feature/.boundaries/01-initial.snapshot
  maintenance=$feature/.boundaries/01-maintenance.snapshot
  resume=$feature/.boundaries/01-resume.snapshot
  check 0 'snapshot' baseline-snapshot gate snapshot "$feature/.baseline"
  check 0 'snapshot' initial-snapshot gate snapshot "$original"
  cp "$original" "$evidence/original.snapshot"
  cat >tests/feature.test.sh <<'EOF'
set -euo pipefail
actual=$("$BASH" src/app.sh feature)
if [[ $actual != v2 ]]; then
  printf 'regression: expected v2, got %s\n' "$actual"
  exit 1
fi
printf 'regression: PASS\n'
EOF
  red_output=$'exit: 1\nexisting: PASS\nregression: expected v2, got legacy'
  check 1 "$red_output" tdd-red gate gate "$full_gate"
  red_hash=$(git hash-object tests/feature.test.sh)
  cp tests/feature.test.sh "$evidence/red.test.sh"
  check 0 'within selected Where:' previous-phase-boundary gate boundary "$feature" \
    --since "$original" --ticket "$ticket"
  check 0 '' codegen-blocker test ! -e generated/value.txt

  # Explicit checkpoint, not a simulated dispatcher. The initial TDD red costs no repair.
  printf 'base=%q\nfull_gate=%q\noriginal=%q\nmaintenance=%q\nresume=%q\nred_hash=%q\nred_output=%q\n' \
    "$base" "$full_gate" "$original" "$maintenance" "$resume" "$red_hash" "$red_output" >"$feature/resume.env"
  printf 'repair_count=0\nnext_phase=maintenance\n' >>"$feature/resume.env"
  printf 'Interrupted with diagnosed TDD red; generated/value.txt is absent. All writers stopped.\n' >>"$ticket"
  printf 'checkpoint: persisted (%s checks); initial phase exits\n' "$passed"
  exit 0
fi

mkdir -p "$evidence"
check 0 'checkpoint: persisted' initial-phase "$BASH" "$SELF" --checkpoint "$ROOT"
cat "$evidence/initial-phase.log"
# shellcheck source=/dev/null
source "$feature/resume.env"
[[ ${next_phase:?} == maintenance && ${repair_count:?} == 0 ]]
# Extend scope prospectively only after checking the original phase; keep the same unit and gate.
sed 's@^Where:.*@Where: src/app.sh, tests/feature.test.sh, generated/value.txt@' "$ticket" >"$feature/expanded.md"
mv "$feature/expanded.md" "$ticket"
cat >>"$ticket" <<'EOF'
Maintenance Where: generated/value.txt; local check: generated value equals v2.
Implementation Where: src/app.sh; resume only after maintenance local check and boundary.
No separate prerequisite: full gate and acceptance remain pending on this ticket.
EOF
check 0 '1 tickets, headers valid' absorbed-ticket gate tickets "$feature"
check 0 'snapshot' maintenance-snapshot gate snapshot "$maintenance"
check 0 'generated: v2' codegen "$BASH" tools/generate.sh
# The gate must read the generated artifact itself.
# shellcheck disable=SC2016
check 0 'exit: 0' maintenance-local gate gate 'test "$(cat generated/value.txt)" = v2'

# Deliberately violate this phase inside our disposable fixture, then undo only that probe.
cp src/app.sh "$evidence/before-probe.sh"
printf '\n# Out-of-phase probe\n' >>src/app.sh
check 1 'write outside selected Where:: src/app.sh' phase-denial gate boundary "$feature" \
  --since "$maintenance" --where generated/value.txt
cp "$evidence/before-probe.sh" src/app.sh
check 0 'within selected Where:' maintenance-boundary gate boundary "$feature" \
  --since "$maintenance" --where generated/value.txt
check 1 "$red_output" maintenance-not-completion gate gate "$full_gate"
printf 'next_phase=implementation\n' >>"$feature/resume.env"
printf 'Maintenance local check and boundary passed; full gate retains the original red.\n' >>"$ticket"

# A fresh shell reads disk context, rechecks the red and maintenance boundary, then implements.
check 0 'resume: verified' fresh-resume env -i PATH="$PATH" TMPDIR="${TMPDIR:-/tmp}" \
  "$BASH" "$SELF" --resume "$ROOT"
cat "$evidence/fresh-resume.log"
printf '%s post-checkpoint checks passed; workflow integration passed\n' "$passed"
