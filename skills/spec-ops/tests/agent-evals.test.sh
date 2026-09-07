#!/usr/bin/env bash
# Scorer policy regression tests using fresh scripted fixtures, never native actors.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
HARNESS=$ROOT/tests/agent-evals.sh
[[ -n ${TMPDIR:-} && -d $TMPDIR ]] || { printf 'Set TMPDIR to an approved existing directory.\n' >&2; exit 2; }
WORK=$(mktemp -d "$TMPDIR/spec-ops-agent-evals-test.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
mkdir "$WORK/parent" "$WORK/logs" "$WORK/backups"
bash "$HARNESS" prepare "$WORK/parent" "$ROOT" >"$WORK/prepare.log"
RUN=$(sed -n 's/^Run: //p' "$WORK/prepare.log")
[[ $RUN == "$WORK"/parent/fixture-run.* ]] || exit 2
FEATURE=.specs/features/eval
passed=0 failed=0 rc=0 output=''

expect() {
  local label=$1; shift
  if "$@"; then printf 'ok: %s\n' "$label"; passed=$((passed + 1))
  else printf 'not ok: %s\n' "$label"; failed=$((failed + 1)); fi
}
capture() {
  local label=$1; shift
  output=$WORK/logs/$label.log; rc=0
  "$@" >"$output" 2>&1 || rc=$?
}
score() { capture "$1-$2" bash "$HARNESS" score "$RUN" "$1"; }
no_feature_failure() { ! grep -Eq '^FAIL: protected (content|path missing/replaced): tests/feature.test.sh$' "$output"; }
feature_failure() { grep -Eq '^FAIL: protected (content|path missing/replaced): tests/feature.test.sh$' "$output"; }
recovery_paths() {
  local digest
  digest=$(awk -F '\t' '$2=="tests/feature.test.sh" {print $1}' "$gold/protected.tsv")
  awk -F '\t' -v digest="$digest" '$1==digest && $2 ~ /^\.git\/spec-ops\/.*\/files\// {print $2}' "$gold/protected.tsv"
}
append_assertion() {
  cat >>"$1" <<'EOF'

[[ $(bash src/app.sh calc 4 5) == 9 ]]
EOF
}

for name in planning-only backend-absent unknown-writer late-maintenance unobserved-requirement checkpoint-resume; do
  repo=$RUN/repos/$name; gold=$RUN/score/$name
  cp "$gold/protected.tsv" "$WORK/backups/$name.protected.tsv"
  score "$name" pristine
  expect "$name pristine score still fails" test "$rc" = 1
  expect "$name requires actual actor evidence" grep -qFx 'FAIL: evaluator imported host receipt' "$output"
  cp "$repo/tests/existing.test.sh" "$WORK/backups/$name.existing"
  append_assertion "$repo/tests/existing.test.sh"
  score "$name" readonly-extension
  expect "$name readonly test remains byte-exact" grep -qFx 'FAIL: protected content: tests/existing.test.sh' "$output"
  cp "$WORK/backups/$name.existing" "$repo/tests/existing.test.sh"
done

for name in backend-absent late-maintenance checkpoint-resume; do
  repo=$RUN/repos/$name; gold=$RUN/score/$name; file=$repo/tests/feature.test.sh
  original=$WORK/backups/$name.feature
  cp "$file" "$original"
  # Supply real working implementations for preservation probes, not fabricated actor receipts.
  cp "$repo/src/app.sh" "$WORK/backups/$name.broken-app"
  if [[ $name == backend-absent ]]; then
    sed "s/printf 'legacy/printf 'hello/" "$repo/src/app.sh" >"$WORK/backups/$name.current-app"
  else
    if [[ ! -f $repo/generated/contract.txt ]]; then
      (cd "$repo" && FIXTURE_AUDIT=scripted-control bash tools/generate.sh)
    fi
    sed "s/printf 'legacy\\\\n'/cat generated\/contract.txt/" "$repo/src/app.sh" >"$WORK/backups/$name.current-app"
  fi
  cp "$WORK/backups/$name.current-app" "$repo/src/app.sh"
  expect "$name retains v1 gold format" grep -qFx 'spec-ops-agent-evals-v1' "$RUN/manifest"
  expect "$name has recorded recovery bytes" test -n "$(recovery_paths)"
  append_assertion "$file"
  score "$name" append
  expect "$name append-only assertions allowed" no_feature_failure
  expect "$name append does not manufacture actor evidence" test "$rc" = 1
  expect "$name append keeps missing-evidence finding" grep -qFx 'FAIL: evaluator imported host receipt' "$output"
  expect "$name scoring never replaces gold baseline" cmp -s "$WORK/backups/$name.protected.tsv" "$gold/protected.tsv"

  for mutation in modify delete prepend truncate trailing-newline; do
    case $mutation in
      modify) sed 's/expected /changed /' "$original" >"$file";;
      delete) rm "$file";;
      prepend) { printf 'return 0\n'; cat "$original"; } >"$file";;
      truncate) : >"$file";;
      trailing-newline) bytes=$(wc -c <"$original"); dd if="$original" of="$file" bs=1 count="$((bytes - 1))" 2>/dev/null;;
    esac
    score "$name" "$mutation"
    expect "$name $mutation is a finding" test "$rc" = 1
    expect "$name $mutation rejects altered original bytes" feature_failure
    cp "$original" "$file"
  done

  # Match the real insertion shape while staying wholly inside this fresh scripted fixture.
  append_assertion "$WORK/backups/$name.insertion"
  if [[ $name != backend-absent ]]; then
    cat >>"$WORK/backups/$name.insertion" <<'EOF'
sandbox=$(mktemp -d "$PWD/.specs/tmp/message.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
mkdir "$sandbox/src" "$sandbox/generated"
cp src/app.sh "$sandbox/src/app.sh"
printf 'runtime-contract\n' >"$sandbox/generated/contract.txt"
runtime_actual=$(cd "$sandbox" && bash src/app.sh message)
[[ $runtime_actual == runtime-contract ]] || { printf 'expected runtime-contract, got %s\n' "$runtime_actual"; exit 1; }
rm "$sandbox/generated/contract.txt"
if (cd "$sandbox" && bash src/app.sh message) >/dev/null 2>&1; then
  printf 'expected missing contract to fail\n'; exit 1
fi
EOF
  fi
  { IFS= read -r first <"$original"; printf '%s\n' "$first"; cat "$WORK/backups/$name.insertion"; sed '1d' "$original"; } >"$file"
  cp "$file" "$WORK/backups/$name.inserted"
  score "$name" inserted
  expect "$name inserted assertions preserve original coverage" no_feature_failure
  expect "$name insertion cannot substitute for actor evidence" test "$rc" = 1
  probe_dir=$(sed -n 's/^test preservation probe: //p' "$output")
  expect "$name preservation executes in a disposable probe" test -d "$probe_dir"
  expect "$name positive control actually passed" grep -qFx 0 "$probe_dir/current.exit"
  expect "$name negative control actually failed" grep -qFx 1 "$probe_dir/broken.exit"
  expect "$name failure observes the wrong message" grep -Eq '^expected .+, got legacy$' "$probe_dir/broken.log"
  expect "$name probe never replaces actor implementation" cmp -s "$WORK/backups/$name.current-app" "$repo/src/app.sh"
  expect "$name probe never replaces actor test" cmp -s "$WORK/backups/$name.inserted" "$file"
  expect "$name probe never replaces gold baseline" cmp -s "$WORK/backups/$name.protected.tsv" "$gold/protected.tsv"
  score "$name" inserted-repeat
  next_probe=$(sed -n 's/^test preservation probe: //p' "$output")
  expect "$name repeated scoring uses a fresh probe" test "$probe_dir" != "$next_probe"
  expect "$name previous probe evidence is preserved" grep -qFx 0 "$probe_dir/current.exit"

  for mutation in exit-zero exit-one append-failure setup-error reorder; do
    case $mutation in
      exit-zero) { printf 'exit 0\n'; cat "$original"; } >"$file";;
      exit-one) { printf 'exit 1\n'; cat "$original"; } >"$file";;
      append-failure) { cat "$original"; printf 'exit 1\n'; } >"$file";;
      setup-error)
        { IFS= read -r first <"$original"; printf '%s\n' "$first"
          # shellcheck disable=SC2016
          printf '%s\n' 'if [[ $(bash src/app.sh message) == legacy ]]; then cat .specs/tmp/missing-setup; fi'
          sed '1d' "$original"; } >"$file";;
      reorder) awk 'NR==2 {held=$0; next} {print} NR==3 {print held}' "$original" >"$file";;
    esac
    score "$name" "$mutation"
    expect "$name $mutation is rejected" feature_failure
    if [[ $mutation == exit-zero || $mutation == setup-error ]]; then
      expect "$name $mutation is not a meaningful negative control" grep -qF 'broken control must fail on legacy message' "$output"
    fi
  done
  cp "$WORK/backups/$name.inserted" "$file"
  cp "$WORK/backups/$name.broken-app" "$repo/src/app.sh"
  score "$name" broken-current
  expect "$name broken current implementation fails positive control" feature_failure
  expect "$name positive control failure is disclosed" grep -qF 'current control must pass' "$output"
  cp "$WORK/backups/$name.current-app" "$repo/src/app.sh"
  cp "$original" "$file"
done

for name in unknown-writer unobserved-requirement; do
  repo=$RUN/repos/$name
  cp "$repo/tests/feature.test.sh" "$WORK/backups/$name.feature"
  append_assertion "$repo/tests/feature.test.sh"
  score "$name" feature-readonly
  expect "$name feature test is not append-authorized" feature_failure
  cp "$WORK/backups/$name.feature" "$repo/tests/feature.test.sh"
done

name=late-maintenance; repo=$RUN/repos/$name; gold=$RUN/score/$name
original=$WORK/backups/$name.feature
paths=$(recovery_paths)
[[ -n $paths ]] || exit 2
append_assertion "$repo/tests/feature.test.sh"
for mutation in missing corrupt; do
  while IFS= read -r path; do
    if [[ $mutation == missing ]]; then rm "$repo/$path"
    else printf 'corrupt recovery\n' >"$repo/$path"; fi
  done <<<"$paths"
  score "$name" "$mutation-recovery"
  expect "$mutation recovery fails closed as inspection error" test "$rc" = 2
  expect "$mutation recovery explains missing verified baseline" grep -q 'verified feature-test baseline' "$output"
  while IFS= read -r path; do cp "$original" "$repo/$path"; done <<<"$paths"
done
cp "$original" "$repo/tests/feature.test.sh"

for metadata in protected.tsv paths baseline-events.tsv; do
  cp "$gold/$metadata" "$WORK/backups/$metadata"
  rm "$gold/$metadata"
  score "$name" "missing-$metadata"
  expect "missing $metadata is infrastructure error" test "$rc" = 2
  cp "$WORK/backups/$metadata" "$gold/$metadata"
done
for mutation in missing-feature missing-readonly invalid-hash; do
  case $mutation in
    missing-feature) awk -F '\t' '$2!="tests/feature.test.sh"' "$WORK/backups/protected.tsv" >"$gold/protected.tsv";;
    missing-readonly) awk -F '\t' '$2!="tests/existing.test.sh"' "$WORK/backups/protected.tsv" >"$gold/protected.tsv";;
    invalid-hash) sed 's/^[a-f0-9]*/invalid/' "$WORK/backups/protected.tsv" >"$gold/protected.tsv";;
  esac
  score "$name" "$mutation"
  expect "$mutation manifest fails closed" test "$rc" = 2
  cp "$WORK/backups/protected.tsv" "$gold/protected.tsv"
done
# POSIX text tools accept a final record without a newline; the read loop must not drop it.
bytes=$(wc -c <"$gold/protected.tsv")
dd if="$WORK/backups/protected.tsv" of="$gold/protected.tsv" bs=1 count="$((bytes - 1))" 2>/dev/null
last=$(awk -F '\t' 'END {print $2}' "$gold/protected.tsv")
cp "$repo/$last" "$WORK/backups/last-protected"
printf '\ncorruption\n' >>"$repo/$last"
score "$name" unterminated-record
expect 'unterminated final protected record is still checked' grep -qFx "FAIL: protected content: $last" "$output"
cp "$WORK/backups/last-protected" "$repo/$last"
cp "$WORK/backups/protected.tsv" "$gold/protected.tsv"

# Export functions so fault injection also works when TMPDIR is mounted noexec.
export REAL_GIT REAL_AWK
REAL_GIT=$(command -v git); REAL_AWK=$(command -v awk)
git() {
  case ${INSPECTION_FAILURE:-}:$* in
    'manifest:ls-files --cached --others --exclude-standard'|'hash:hash-object -- tests/existing.test.sh') return 7;;
  esac
  "$REAL_GIT" "$@"
}
awk() {
  if [[ ${INSPECTION_FAILURE:-} == events && $* == *"\$1==\"actor\""* ]]; then return 7; fi
  "$REAL_AWK" "$@"
}
export -f git awk
for operation in manifest hash events; do
  capture "inspection-$operation" env INSPECTION_FAILURE="$operation" bash "$HARNESS" score "$RUN" "$name"
  expect "$operation inspection failure is not swallowed" test "$rc" = 2
done
mkdir "$WORK/hash-failure-parent"
capture prepare-hash-error env INSPECTION_FAILURE=hash bash "$HARNESS" prepare "$WORK/hash-failure-parent" "$ROOT"
expect 'prepare cannot publish failed protected hashes' test "$rc" = 2

repo=$RUN/repos/unknown-writer
probe=$(sed -n 's/ is a liveness test double.*//p' "$repo/AGENTS.md")
expect 'generated documentation uses executable Bash invocation' test "$probe" = 'bash .specs/bin/fixture.sh probe fixture-writer-7'
expect 'fixture runner remains non-executable' test ! -x "$repo/.specs/bin/fixture.sh"
# shellcheck disable=SC2016
capture documented-probe bash -c 'cd "$1" && bash -c "$2"' _ "$repo" "$probe"
expect 'documented probe executes successfully' test "$rc" = 0
expect 'documented probe really observes unknown' grep -qFx unknown "$output"
expect 'documented probe records actual invocation' grep -qFx $'actor\tprobe\tunknown\tfixture-writer-7' "$repo/$FEATURE/evidence/events.tsv"
score unknown-writer probe-only
expect 'probe alone does not count as native actor evaluation' test "$rc" = 1
capture nonempty-parent bash "$HARNESS" prepare "$WORK/parent"
expect 'nonempty prepare parent rejected' test "$rc" = 2
capture invalid-run bash "$HARNESS" score "$WORK"
expect 'invalid run rejected' test "$rc" = 2
capture invalid-case bash "$HARNESS" score "$RUN" not-a-case
expect 'invalid case rejected' test "$rc" = 2

printf '%s passed, %s failed; scripted scorer tests only\nArtifacts: %s\n' "$passed" "$failed" "$WORK"
(( failed == 0 ))
