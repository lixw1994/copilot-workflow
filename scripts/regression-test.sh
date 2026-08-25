#!/usr/bin/env bash
# Focused regressions for installer recovery and squad name collision handling.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/copilot-workflow-regressions.XXXXXX")"

cleanup() {
  [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ] && rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

test_openspec_recovery() {
  local target="$TEST_ROOT/installer-target"
  local fake_bin="$TEST_ROOT/installer-bin"
  local state="$TEST_ROOT/openspec-state"
  local calls="$TEST_ROOT/openspec-calls"
  local first_output="$TEST_ROOT/installer-first-output"
  local second_output="$TEST_ROOT/installer-second-output"

  mkdir -p "$target" "$fake_bin"
  cat > "$fake_bin/openspec" <<'FAKE_OPEN_SPEC'
#!/usr/bin/env bash
set -eu
: "${FAKE_OPEN_SPEC_STATE:?}"
: "${FAKE_OPEN_SPEC_CALLS:?}"
printf 'init\n' >> "$FAKE_OPEN_SPEC_CALLS"
mkdir -p "$PWD/openspec"
if [ ! -f "$FAKE_OPEN_SPEC_STATE" ]; then
  : > "$FAKE_OPEN_SPEC_STATE"
  exit 1
fi
mkdir -p "$PWD/.agents/skills"
: > "$PWD/.agents/skills/.openspec-target"
[ -f "$PWD/openspec/config.yaml" ] || printf 'schema: spec-driven\n' > "$PWD/openspec/config.yaml"
FAKE_OPEN_SPEC
  chmod +x "$fake_bin/openspec"

  if (
    cd "$target"
    PATH="$fake_bin:$PATH" FAKE_OPEN_SPEC_STATE="$state" FAKE_OPEN_SPEC_CALLS="$calls" \
      "$REPO_ROOT/init.sh" --with openspec
  ) >"$first_output" 2>&1; then
    fail "first incomplete OpenSpec initialization unexpectedly succeeded"
  fi
  [ -d "$target/openspec" ] || fail "failed initialization did not leave the partial openspec directory"
  [ ! -f "$target/.agents/skills/.openspec-target" ] || fail "failed initialization unexpectedly created the skills marker"

  (
    cd "$target"
    PATH="$fake_bin:$PATH" FAKE_OPEN_SPEC_STATE="$state" FAKE_OPEN_SPEC_CALLS="$calls" \
      "$REPO_ROOT/init.sh" --with openspec
  ) >"$second_output" 2>&1 || fail "rerun did not repair the incomplete OpenSpec initialization"

  [ "$(wc -l < "$calls" | tr -d ' ')" = "2" ] || fail "openspec init was not invoked on both runs"
  [ -f "$target/.agents/skills/.openspec-target" ] || fail "rerun did not restore the workflow skills marker"
  [ -d "$target/openspec/schemas/spec-driven-with-adr" ] || fail "rerun did not install the default schema"
  [ -f "$target/openspec/schemas/spec-driven-with-adr/LICENSE" ] || fail "default schema license was not installed"
  [ -f "$target/openspec/schemas/minimalist/LICENSE" ] || fail "minimalist schema license was not installed"
  [ ! -e "$target/openspec/schemas/LICENSE" ] || fail "installer leaked a license into the schemas parent directory"
  grep -q '^  - openspec$' "$target/.copilot-workflow.yaml" \
    || fail "manifest did not record the repaired OpenSpec component"

  printf 'ok: incomplete OpenSpec initialization self-heals on rerun\n'
}

test_squad_double_name_collision() {
  local project="$TEST_ROOT/myproj"
  local fake_bin="$TEST_ROOT/squad-bin"
  local mutation_log="$TEST_ROOT/herdr-mutations"
  local output="$TEST_ROOT/squad-output"

  mkdir -p "$project/.herdr/scripts" "$project/.herdr/roles" "$fake_bin"
  cp "$REPO_ROOT/squad/scripts/squad.sh" "$project/.herdr/scripts/squad.sh"
  cp "$REPO_ROOT/squad/roles/researcher.md" "$project/.herdr/roles/researcher.md"
  printf 'researcher codex\n' > "$project/.herdr/squad.conf"

  cat > "$fake_bin/herdr" <<'FAKE_HERDR'
#!/usr/bin/env bash
set -eu
: "${FAKE_HERDR_MUTATIONS:?}"
case "${1:-} ${2:-}" in
  "agent list")
    printf '%s\n' '{"result":{"agents":[{"name":"researcher","workspace_id":"other-1"},{"name":"myproj-researcher","workspace_id":"other-2"}]}}'
    ;;
  "tab create"|"agent start")
    printf '%s\n' "$*" >> "$FAKE_HERDR_MUTATIONS"
    printf '%s\n' '{"result":{"root_pane":{"pane_id":"unexpected-pane"}}}'
    ;;
  *)
    printf 'unexpected fake herdr call: %s\n' "$*" >&2
    exit 1
    ;;
esac
FAKE_HERDR
  chmod +x "$fake_bin/herdr"

  if PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=current \
    FAKE_HERDR_MUTATIONS="$mutation_log" \
    "$project/.herdr/scripts/squad.sh" up researcher >"$output" 2>&1; then
    fail "double name collision unexpectedly succeeded"
  fi

  grep -q 'both bare and prefixed names' "$output" \
    || fail "double name collision did not report the conflicting candidates"
  [ ! -s "$mutation_log" ] \
    || fail "double name collision created a tab or attempted to start an agent"

  printf 'ok: double agent-name collision fails before tab creation\n'
}

test_openspec_recovery
test_squad_double_name_collision
printf 'All regression tests passed.\n'
