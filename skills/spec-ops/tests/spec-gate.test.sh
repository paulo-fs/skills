#!/usr/bin/env bash

set -uo pipefail

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/spec-gate-test.XXXXXX")
SCRIPT=$(cd "$(dirname "$0")/.." && pwd)/scripts/spec-gate.sh
passed=0
failed=0

cleanup() {
  rm -rf "$ROOT"
}
trap cleanup EXIT

new_repo() {
  local name=$1 dir="$ROOT/$1"
  mkdir -p "$dir/.specs/features/example/tickets" "$dir/src" "$dir/tests"
  git -C "$dir" init -q
  git -C "$dir" config user.email spec-gate@example.test
  git -C "$dir" config user.name spec-gate
  printf 'fixture\n' >"$dir/.fixture"
  printf '%s\n' "$dir"
}

ticket() {
  local repo=$1 number=$2 where=$3
  printf 'Where: %s\n' "$where" >"$repo/.specs/features/example/tickets/$number-test.md"
}

full_ticket() {
  local repo=$1 where=$2
  cat >"$repo/.specs/features/example/tickets/01-test.md" <<EOF
# 01 — Test

Blocked by: none
Where: $where
Reads: none
Class: standard
TDD: red-green
UAT: none
Implements: FR-1
Status: ready

## Done when
- [ ] gate: true exits 0
EOF
}

dependency_ticket() {
  local repo=$1 number=$2 blocked=$3
  cat >"$repo/.specs/features/example/tickets/$number-test.md" <<EOF
# $number — Test

Blocked by: $blocked
Where: src/$number.ts
Reads: none
Class: standard
TDD: red-green
UAT: none
Implements: FR-$number
Status: ready

## Done when
- [ ] gate: true exits 0
EOF
}

commit_all() {
  local repo=$1
  git -C "$repo" add -A
  git -C "$repo" commit -qm baseline
}

expect_status() {
  local expected=$1 name=$2
  shift 2
  "$@" >/dev/null 2>&1
  local actual=$?
  if [[ $actual -eq $expected ]]; then
    printf 'ok: %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'not ok: %s (expected %s, got %s)\n' "$name" "$expected" "$actual"
    failed=$((failed + 1))
  fi
}

expect_value() {
  local expected=$1 actual=$2 name=$3
  if [[ $actual == "$expected" ]]; then
    printf 'ok: %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'not ok: %s (expected %s, got %s)\n' "$name" "$expected" "$actual"
    failed=$((failed + 1))
  fi
}

test_exact_path() {
  local repo
  repo=$(new_repo exact-path)
  ticket "$repo" 01 src/exact.ts
  printf 'baseline\n' >"$repo/src/exact.ts"
  commit_all "$repo"
  printf 'unauthorized\n' >"$repo/src/exact.ts.bak"

  expect_status 1 "exact Where rejects suffix" env -C "$repo" "$SCRIPT" boundary .specs/features/example
}

test_ticket_scope() {
  local repo
  repo=$(new_repo ticket-scope)
  ticket "$repo" 01 src/current.ts
  ticket "$repo" 02 src/sibling.ts
  printf 'baseline\n' >"$repo/src/current.ts"
  printf 'baseline\n' >"$repo/src/sibling.ts"
  commit_all "$repo"
  printf 'changed\n' >"$repo/src/sibling.ts"

  expect_status 1 "ticket boundary rejects sibling scope" env -C "$repo" "$SCRIPT" boundary .specs/features/example --ticket .specs/features/example/tickets/01-test.md
}

test_inline_where() {
  local repo
  repo=$(new_repo inline-where)
  commit_all "$repo"
  printf 'changed\n' >"$repo/src/outside.ts"

  expect_status 1 "inline Where works without ticket artifacts" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where src/allowed.ts
}

test_whole_tree_where() {
  local repo
  repo=$(new_repo whole-tree)
  full_ticket "$repo" .

  expect_status 1 "tickets reject whole-tree Where" env -C "$repo" "$SCRIPT" tickets .specs/features/example
}

test_dependency_order() {
  local repo
  repo=$(new_repo dependency-order)
  dependency_ticket "$repo" 01 02
  dependency_ticket "$repo" 02 none

  expect_status 1 "tickets reject later dependencies" env -C "$repo" "$SCRIPT" tickets .specs/features/example
}

test_rename_destination() {
  local repo
  repo=$(new_repo rename)
  ticket "$repo" 01 src/old.ts
  printf 'baseline\n' >"$repo/src/old.ts"
  commit_all "$repo"
  git -C "$repo" mv src/old.ts src/new.ts

  expect_status 1 "rename destination must be authorized" env -C "$repo" "$SCRIPT" boundary .specs/features/example
}

test_nested_untracked() {
  local repo
  repo=$(new_repo nested-untracked)
  ticket "$repo" 01 generated/allowed.ts
  mkdir -p "$repo/generated"
  commit_all "$repo"
  printf 'generated\n' >"$repo/generated/allowed.ts"

  expect_status 0 "nested untracked file matches Where" env -C "$repo" "$SCRIPT" boundary .specs/features/example
}

test_snapshot_dirty_change() {
  local repo recovery recovery_key recovered
  repo=$(new_repo dirty-change)
  ticket "$repo" 01 src/current.ts
  printf 'baseline\n' >"$repo/legacy.txt"
  commit_all "$repo"
  printf 'owner edit\n' >"$repo/legacy.txt"
  env -C "$repo" "$SCRIPT" snapshot .specs/features/example/.before >/dev/null 2>&1
  local snapshot_status=$?
  recovery=$(sed -n 's/^# recovery: //p' "$repo/.specs/features/example/.before")
  recovery_key=$(printf '%s' legacy.txt | git -C "$repo" hash-object --stdin)
  recovered=$(<"$repo/$recovery/files/$recovery_key")
  expect_value "owner edit" "$recovered" "snapshot preserves recoverable content"
  printf 'overwritten\n' >"$repo/legacy.txt"

  if [[ $snapshot_status -ne 0 ]]; then
    printf 'not ok: snapshot captures dirty state (snapshot failed)\n'
    failed=$((failed + 1))
    return
  fi

  expect_status 1 "snapshot detects changed dirty file" env -C "$repo" "$SCRIPT" boundary .specs/features/example --ticket .specs/features/example/tickets/01-test.md --since .specs/features/example/.before
}

test_snapshot_read_failure() {
  local repo
  repo=$(new_repo snapshot-failure)
  printf 'secret\n' >"$repo/secret.txt"
  commit_all "$repo"
  printf 'owner edit\n' >"$repo/secret.txt"
  chmod 000 "$repo/secret.txt"

  expect_status 2 "snapshot fails when recovery is incomplete" env -C "$repo" "$SCRIPT" snapshot .specs/features/example/.unreadable
}

test_boundary_read_failure() {
  local repo
  repo=$(new_repo boundary-failure)
  ticket "$repo" 01 src/allowed.ts
  printf 'secret\n' >"$repo/secret.txt"
  commit_all "$repo"
  printf 'owner edit\n' >"$repo/secret.txt"
  chmod 000 "$repo/secret.txt"

  expect_status 2 "boundary propagates manifest failure" env -C "$repo" "$SCRIPT" boundary .specs/features/example --ticket .specs/features/example/tickets/01-test.md
}

test_honesty_untracked_skip() {
  local repo
  repo=$(new_repo honesty-untracked)
  commit_all "$repo"
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/new.test.ts"

  expect_status 1 "honesty checks untracked tests" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_honesty_space_path() {
  local repo
  repo=$(new_repo honesty-space)
  printf 'it("works", () => {})\n' >"$repo/tests/value with space.test.ts"
  commit_all "$repo"
  printf 'it.skip("works", () => {})\n' >"$repo/tests/value with space.test.ts"

  expect_status 1 "honesty handles spaces in paths" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_honesty_todo() {
  local repo
  repo=$(new_repo honesty-todo)
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  printf 'it.todo("disabled")\n' >"$repo/tests/value.test.ts"

  expect_status 1 "honesty rejects todo tests" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_honesty_assertion_update() {
  local repo
  repo=$(new_repo honesty-update)
  printf 'expect(value).toBeGreaterThan(0)\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  printf 'expect(value).toBe(1)\n' >"$repo/tests/value.test.ts"

  expect_status 0 "honesty leaves assertion updates to review" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_count_failure() {
  expect_status 2 "count propagates command failure" "$SCRIPT" count "sh -c 'printf 42; exit 7'"
  expect_status 2 "count rejects non-integer output" "$SCRIPT" count "printf no-digits"
}

test_status_failure() {
  local repo
  repo=$(new_repo status-failure)
  commit_all "$repo"
  printf 'invalid index\n' >"$repo/.git/index"

  expect_status 2 "boundary propagates status failure" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where src/allowed.ts
  expect_status 2 "honesty propagates status failure" env -C "$repo" "$SCRIPT" honesty HEAD
  expect_status 2 "snapshot propagates status failure" env -C "$repo" "$SCRIPT" snapshot .specs/features/example/.before
  expect_status 0 "failed snapshot leaves no manifest" test ! -e "$repo/.specs/features/example/.before"
}

test_honesty_read_failure() {
  local repo
  repo=$(new_repo honesty-read-failure)
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/new.test.ts"
  chmod 000 "$repo/tests/new.test.ts"

  expect_status 2 "honesty rejects unreadable untracked tests" env -C "$repo" "$SCRIPT" honesty HEAD
  chmod 600 "$repo/tests/new.test.ts"
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/value.test.ts"
  chmod 000 "$repo/tests/value.test.ts"
  expect_status 2 "honesty rejects unreadable tracked tests" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_root_required() {
  local repo
  repo=$(new_repo root-required)
  printf 'baseline\n' >"$repo/src/outside.ts"
  commit_all "$repo"
  printf 'owner edit\n' >"$repo/src/outside.ts"

  expect_status 2 "snapshot rejects subdirectory invocation" env -C "$repo/src" "$SCRIPT" snapshot ../.specs/features/example/.before
  expect_status 2 "boundary rejects subdirectory invocation" env -C "$repo/src" "$SCRIPT" boundary ../.specs/features/example --where src/allowed.ts
  expect_status 2 "honesty rejects subdirectory invocation" env -C "$repo/src" "$SCRIPT" honesty HEAD
  expect_status 0 "subdirectory snapshot creates no recovery" test ! -e "$repo/.git/spec-ops"
}

test_honesty_committed() {
  local repo base
  repo=$(new_repo honesty-committed)
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  base=$(git -C "$repo" rev-parse HEAD)
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"

  expect_status 1 "honesty checks committed skips against base" env -C "$repo" "$SCRIPT" honesty "$base"
  expect_status 0 "honesty ignores skips unchanged from base" env -C "$repo" "$SCRIPT" honesty HEAD
  git -C "$repo" rm -q tests/value.test.ts
  commit_all "$repo"
  expect_status 1 "honesty checks committed deletions against base" env -C "$repo" "$SCRIPT" honesty "$base"
}

test_honesty_index() {
  local repo
  repo=$(new_repo honesty-index)
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/value.test.ts"
  git -C "$repo" add tests/value.test.ts
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"

  expect_status 1 "honesty checks staged skips hidden by worktree" env -C "$repo" "$SCRIPT" honesty HEAD
  git -C "$repo" add tests/value.test.ts
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/value.test.ts"
  expect_status 1 "honesty checks unstaged skips" env -C "$repo" "$SCRIPT" honesty HEAD
  git -C "$repo" rm -q --cached tests/value.test.ts
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  expect_status 1 "honesty checks staged deletion restored in worktree" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_honesty_renames() {
  local repo base
  repo=$(new_repo honesty-renames)
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  base=$(git -C "$repo" rev-parse HEAD)
  git -C "$repo" mv tests/value.test.ts tests/renamed.test.ts

  expect_status 0 "honesty permits renames within test discovery" env -C "$repo" "$SCRIPT" honesty HEAD
  git -C "$repo" mv tests/renamed.test.ts src/archive.txt
  expect_status 1 "honesty rejects staged rename out of discovery" env -C "$repo" "$SCRIPT" honesty HEAD
  commit_all "$repo"
  expect_status 1 "honesty rejects committed rename out of discovery" env -C "$repo" "$SCRIPT" honesty "$base"

  repo=$(new_repo honesty-existing-skip-rename)
  printf 'it.skip("existing", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  git -C "$repo" mv tests/value.test.ts tests/renamed.test.ts
  expect_status 0 "honesty does not treat moved existing skips as added" env -C "$repo" "$SCRIPT" honesty HEAD
}

test_where_list() {
  local repo pattern
  repo=$(new_repo where-list)
  commit_all "$repo"
  for pattern in . ./ '*' '**' '**/*'; do
    full_ticket "$repo" "src/allowed.ts, $pattern"
    expect_status 1 "tickets reject trailing whole-tree pattern $pattern" env -C "$repo" "$SCRIPT" tickets .specs/features/example
    full_ticket "$repo" "$pattern, src/allowed.ts"
    expect_status 1 "tickets reject leading whole-tree pattern $pattern" env -C "$repo" "$SCRIPT" tickets .specs/features/example
  done

  full_ticket "$repo" 'src/allowed.ts, **'
  expect_status 1 "boundary rejects whole-tree ticket pattern" env -C "$repo" "$SCRIPT" boundary .specs/features/example
  expect_status 1 "boundary rejects whole-tree inline pattern" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where 'src/allowed.ts, **'
  full_ticket "$repo" 'src/allowed.ts, tests/'
  printf 'allowed\n' >"$repo/src/allowed.ts"
  expect_status 0 "tickets permit bounded Where lists" env -C "$repo" "$SCRIPT" tickets .specs/features/example
  expect_status 0 "boundary permits bounded Where lists" env -C "$repo" "$SCRIPT" boundary .specs/features/example
}

test_snapshot_exact_key() {
  local repo
  repo=$(new_repo snapshot-exact-key)
  printf 'baseline\n' >"$repo/config.json"
  printf 'baseline\n' >"$repo/my_config.json"
  commit_all "$repo"
  printf 'owner edit\n' >"$repo/config.json"
  printf 'initial dirty\n' >"$repo/my_config.json"

  expect_status 0 "snapshot captures encoded suffix paths" env -C "$repo" "$SCRIPT" snapshot .specs/features/example/.before
  printf 'allowed edit\n' >"$repo/my_config.json"
  expect_status 0 "snapshot compares complete encoded keys" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where my_config.json --since .specs/features/example/.before
  printf 'overwritten\n' >"$repo/config.json"
  expect_status 1 "exact key matching still detects owner edits" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where my_config.json --since .specs/features/example/.before
}

test_spec_headings() {
  local repo heading
  repo=$(new_repo spec-headings)
  for heading in Problem 'Functional requirements' 'Seams under test' 'Out of scope'; do
    printf 'Prose cites ## %s\n' "$heading"
  done >"$repo/.specs/features/example/spec.md"
  expect_status 1 "spec rejects required headings appearing only in prose" env -C "$repo" "$SCRIPT" spec .specs/features/example

  for heading in Problem 'Functional requirements' 'Seams under test' 'Out of scope'; do
    printf '### %s\n' "$heading"
  done >"$repo/.specs/features/example/spec.md"
  expect_status 1 "spec rejects wrong heading levels" env -C "$repo" "$SCRIPT" spec .specs/features/example

  printf '%s\n' '## Problem (context)' '## Functional requirements / scope' '## Seams under test' '## Out of scope' >"$repo/.specs/features/example/spec.md"
  expect_status 0 "spec accepts headings with supported qualifiers" env -C "$repo" "$SCRIPT" spec .specs/features/example
}

test_command_status() {
  local command output
  expect_status 0 "gate succeeds on successful command" "$SCRIPT" gate true
  expect_status 1 "gate maps command failure to finding status" "$SCRIPT" gate "sh -c 'exit 7'"
  output=$("$SCRIPT" gate "sh -c 'exit 7'")
  expect_status 0 "gate prints original command exit code" grep -qFx 'exit: 7' <<<"$output"
  expect_value 42 "$("$SCRIPT" count 'printf 42')" "count prints bare successful output"

  for command in spec tickets snapshot boundary count; do
    expect_status 2 "$command rejects missing required argument" "$SCRIPT" "$command"
  done
}

test_snapshot_symlinks() {
  local repo destination recovery output rc
  local target=.specs/features/example/.baseline
  repo=$(new_repo snapshot-symlink)
  commit_all "$repo"
  destination="$ROOT/snapshot-unrelated.txt"
  ln -s "$destination" "$repo/$target"

  expect_status 2 "snapshot rejects dangling target symlink" env -C "$repo" "$SCRIPT" snapshot "$target"
  expect_status 0 "snapshot preserves target symlink" test -L "$repo/$target"
  expect_value "$destination" "$(readlink "$repo/$target")" "snapshot preserves target link destination"
  expect_status 0 "snapshot does not create symlink destination" test ! -e "$destination"
  expect_status 0 "rejected target creates no recovery" test ! -e "$repo/.git/spec-ops"

  repo=$(new_repo snapshot-symlink-failure)
  commit_all "$repo"
  ln -s "$ROOT/missing-parent/snapshot.txt" "$repo/$target"
  expect_status 2 "snapshot rejects target with missing destination parent" env -C "$repo" "$SCRIPT" snapshot "$target"
  expect_status 0 "snapshot failure does not unlink pre-existing symlink" test -L "$repo/$target"

  repo=$(new_repo recovery-symlink)
  commit_all "$repo"
  recovery="$repo/.git/spec-ops/$(printf '%s' "$target" | git -C "$repo" hash-object --stdin)"
  destination="$ROOT/recovery-unrelated"
  mkdir -p "$repo/.git/spec-ops"
  ln -s "$destination" "$recovery"
  output=$(env -C "$repo" "$SCRIPT" snapshot "$target" 2>&1); rc=$?
  expect_value 2 "$rc" "snapshot rejects dangling recovery symlink"
  expect_status 0 "recovery guard rejects symlink before mkdir" grep -qF 'error: recovery exists:' <<<"$output"
  expect_status 0 "snapshot preserves recovery symlink" test -L "$recovery"
  expect_status 0 "snapshot does not create recovery link destination" test ! -e "$destination"
  expect_status 0 "rejected recovery creates no snapshot" test ! -e "$repo/$target"
}

test_honesty_color() {
  local repo
  repo=$(new_repo honesty-color)
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  printf 'it.skip("disabled", () => {})\n' >"$repo/tests/value.test.ts"

  expect_status 1 "honesty detects tracked skips with forced color" env -C "$repo" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always "$SCRIPT" honesty HEAD
  git -C "$repo" add tests/value.test.ts
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  expect_status 1 "honesty detects hidden staged skips with forced color" env -C "$repo" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always "$SCRIPT" honesty HEAD
}

test_honesty_new_test_rename() {
  local repo base
  repo=$(new_repo honesty-new-test-rename)
  printf 'it.skip("existing", () => {})\n' >"$repo/src/archive.txt"
  commit_all "$repo"
  base=$(git -C "$repo" rev-parse HEAD)
  git -C "$repo" mv src/archive.txt tests/value.test.ts

  expect_value R100 "$(git -C "$repo" diff --no-color --cached --name-status | cut -f1)" "newly discovered test is an unchanged rename"
  expect_status 1 "honesty inspects staged rename into discovery" env -C "$repo" "$SCRIPT" honesty "$base"
  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  expect_status 1 "new test rename reads staged content despite worktree edit" env -C "$repo" "$SCRIPT" honesty "$base"
  printf 'it.skip("existing", () => {})\n' >"$repo/tests/value.test.ts"
  commit_all "$repo"
  expect_status 1 "honesty inspects committed rename into discovery" env -C "$repo" "$SCRIPT" honesty "$base"

  printf 'it("works", () => {})\n' >"$repo/tests/value.test.ts"
  git -C "$repo" add tests/value.test.ts
  expect_status 0 "honesty permits enabled newly discovered tests" env -C "$repo" "$SCRIPT" honesty "$base"
  printf 'it.skip("existing", () => {})\n' >"$repo/tests/value.test.ts"
  expect_status 1 "new test rename reads worktree content despite staged edit" env -C "$repo" "$SCRIPT" honesty "$base"
}

test_duplicate_ticket_ids() {
  local repo pair output rc
  for pair in 01:01 01:1 000:0; do
    repo=$(new_repo "duplicate-id-$pair")
    dependency_ticket "$repo" "${pair%%:*}" none
    cp "$repo/.specs/features/example/tickets/${pair%%:*}-test.md" "$repo/.specs/features/example/tickets/${pair#*:}-other.md"

    output=$(env -C "$repo" "$SCRIPT" tickets .specs/features/example 2>&1); rc=$?
    expect_value 1 "$rc" "tickets reject duplicate numeric ids $pair"
    expect_status 0 "duplicate ids $pair have an actionable finding" grep -qF 'duplicate numeric ticket id' <<<"$output"
  done

  repo=$(new_repo distinct-ticket-ids)
  dependency_ticket "$repo" 00 none
  dependency_ticket "$repo" 01 00
  dependency_ticket "$repo" 11 01
  expect_status 0 "tickets distinguish numeric ids without substring collisions" env -C "$repo" "$SCRIPT" tickets .specs/features/example

  repo=$(new_repo large-ticket-ids)
  dependency_ticket "$repo" 1 none
  dependency_ticket "$repo" 18446744073709551617 none
  expect_status 0 "duplicate detection does not wrap large numeric ids" env -C "$repo" "$SCRIPT" tickets .specs/features/example
}

test_dirty_submodule() {
  local repo source encoded index_hash ignore output rc target recovery
  local path='vendor/dirty module'
  source=$(new_repo submodule-source)
  commit_all "$source"
  repo=$(new_repo dirty-submodule)
  git -C "$repo" -c protocol.file.allow=always submodule add -q "$source" "$path" || exit 1
  git -C "$repo" config -f .gitmodules "submodule.$path.ignore" all
  git -C "$repo" config diff.ignoreSubmodules all
  chmod 755 "$repo/$path"
  commit_all "$repo"
  expect_status 0 "clean submodule permits snapshot" env -C "$repo" "$SCRIPT" snapshot .specs/features/example/.clean

  printf 'owner edit\n' >"$repo/$path/.fixture"
  encoded=$(printf '%s' "$path" | base64 | tr -d '\n')
  index_hash=$(git -C "$repo" ls-files -s -- "$path" | git -C "$repo" hash-object --stdin)
  # Pre-fix v1 snapshots recorded DIR even when the submodule was already dirty.
  printf '# spec-gate snapshot v1\n%s\t M\tDIR\t755\t%s\n' "$encoded" "$index_hash" >"$repo/.specs/features/example/.legacy-dirty"
  printf 'overwritten\n' >"$repo/$path/.fixture"

  for ignore in none dirty all; do
    git -C "$repo" config "submodule.$path.ignore" "$ignore"
    target=".specs/features/example/.dirty-$ignore"
    recovery="$repo/.git/spec-ops/$(printf '%s' "$target" | git -C "$repo" hash-object --stdin)"
    output=$(env -C "$repo" "$SCRIPT" snapshot "$target" 2>&1); rc=$?
    expect_value 2 "$rc" "snapshot rejects dirty submodule with ignore=$ignore"
    expect_status 0 "snapshot explains unsupported submodule with ignore=$ignore" grep -qF "unsupported dirty directory/submodule: $path; preserve its changes and make it clean before retrying" <<<"$output"
    expect_status 0 "rejected submodule snapshot leaves no manifest with ignore=$ignore" test ! -e "$repo/$target"
    expect_status 0 "rejected submodule snapshot leaves no recovery with ignore=$ignore" test ! -e "$recovery"
    expect_status 2 "no-since boundary rejects even authorized dirty submodule with ignore=$ignore" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where "$path"

    output=$(env -C "$repo" "$SCRIPT" boundary .specs/features/example --where src/allowed.ts --since .specs/features/example/.legacy-dirty 2>&1); rc=$?
    expect_value 2 "$rc" "boundary rejects overwritten already-dirty submodule with ignore=$ignore"
    expect_status 0 "snapshot boundary explains unsupported submodule with ignore=$ignore" grep -qF "unsupported dirty directory/submodule: $path; preserve its changes and make it clean before retrying" <<<"$output"
  done

  expect_status 2 "snapshot boundary rejects submodule dirtied after clean baseline" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where "$path" --since .specs/features/example/.clean
  expect_value overwritten "$(<"$repo/$path/.fixture")" "submodule rejection preserves current content"
}

test_directory_record() {
  local repo nested
  repo=$(new_repo directory-record)
  commit_all "$repo"
  nested=$(new_repo nested-directory)
  mv "$nested" "$repo/nested"

  expect_status 2 "snapshot rejects untracked nested Git directory" env -C "$repo" "$SCRIPT" snapshot .specs/features/example/.before
  expect_status 2 "boundary rejects untracked nested Git directory" env -C "$repo" "$SCRIPT" boundary .specs/features/example --where nested/
}

test_exact_path
test_ticket_scope
test_inline_where
test_whole_tree_where
test_dependency_order
test_rename_destination
test_nested_untracked
test_snapshot_dirty_change
test_snapshot_read_failure
test_boundary_read_failure
test_honesty_untracked_skip
test_honesty_space_path
test_honesty_todo
test_honesty_assertion_update
test_count_failure
test_status_failure
test_honesty_read_failure
test_root_required
test_honesty_committed
test_honesty_index
test_honesty_renames
test_where_list
test_snapshot_exact_key
test_spec_headings
test_command_status
test_snapshot_symlinks
test_honesty_color
test_honesty_new_test_rename
test_duplicate_ticket_ids
test_dirty_submodule
test_directory_record

printf '%s passed, %s failed\n' "$passed" "$failed"
(( failed == 0 ))
