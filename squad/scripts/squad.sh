#!/usr/bin/env bash
# copilot-workflow squad lifecycle manager (compatible with macOS stock bash 3.2)
# Runs from the installed instance .herdr/scripts/squad.sh (source lives in the
# template repository under squad/scripts/, installed by init.sh).
#
# Usage:
#   squad.sh up [role [kind]]  Launch the squad / one role (kind defaults: config → HERDR_AGENT_KIND → codex)
#   squad.sh down [role]       Stop the squad / one role (closes its role-named tab; the agent exits)
#   squad.sh restart [role]    Restart the squad / one role (down + up)
#   squad.sh status            Show each role's config and liveness
#   squad.sh print             Print the launch plan (no Herdr environment needed)
#
# Config: .herdr/squad.conf (installer-managed)
#         .herdr/squad.local.conf (local override, whole-file precedence, never touched by the installer)
# Each role occupies one tab named after it in the current workspace.
# Agent names are session-unique: a taken bare role name falls back to
# "<project-prefix>-<role>"; the actual name is whatever up/status prints.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERDR_DIR="$REPO_ROOT/.herdr"
DEFAULT_KIND="${HERDR_AGENT_KIND:-codex}"

log()  { printf '[squad] %s\n' "$*"; }
die()  { printf '[squad] error: %s\n' "$*" >&2; exit 1; }

conf_file() {
  if [ -f "$HERDR_DIR/squad.local.conf" ]; then
    printf '%s' "$HERDR_DIR/squad.local.conf"
  else
    printf '%s' "$HERDR_DIR/squad.conf"
  fi
}

# Parse the config into a normalized plan: one line per role, "role<TAB>kind<TAB>args..."
parse_conf() {
  local file="$1" line role kind args lineno=0
  [ -f "$file" ] || die "config file not found: $file"
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    line="${line%%#*}"
    # shellcheck disable=SC2086
    set -f; set -- $line; set +f
    [ "$#" -eq 0 ] && continue
    role="$1"; kind="${2:-$DEFAULT_KIND}"; shift; [ "$#" -gt 0 ] && shift
    args="$*"
    printf '%s' "$role" | grep -Eq '^[a-z][a-z0-9_-]*$' \
      || die "invalid role name on config line ${lineno} (must match ^[a-z][a-z0-9_-]*\$): $role"
    [ -f "$HERDR_DIR/roles/$role.md" ] \
      || die "config line ${lineno} references an unknown role (missing .herdr/roles/${role}.md): $role"
    printf '%s\t%s\t%s\n' "$role" "$kind" "$args"
  done < "$file"
}

sanitize_prefix() {
  local p
  p="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
  while [ -n "$p" ]; do
    case "$p" in
      [a-z]*) break ;;
      *) p="${p#?}" ;;
    esac
  done
  printf '%s' "$p"
}

agent_exists() {
  herdr agent list 2>/dev/null | jq -e --arg n "$1" \
    '.result.agents[]? | select(.name == $n)' >/dev/null 2>&1
}

# Does a live agent with this name belong to this project's squad (same workspace)?
agent_ours() {
  herdr agent list 2>/dev/null | jq -e --arg n "$1" --arg w "${HERDR_WORKSPACE_ID:-}" \
    '.result.agents[]? | select(.name == $n and .workspace_id == $w)' >/dev/null 2>&1
}

prefixed_name() {
  local role="$1" prefix max_prefix
  prefix="$(sanitize_prefix "$(basename "$REPO_ROOT")")"
  [ -n "$prefix" ] || return 1
  max_prefix=$((32 - 1 - ${#role}))
  [ "$max_prefix" -ge 1 ] || return 1
  if [ "${#prefix}" -gt "$max_prefix" ]; then
    prefix="$(printf '%s' "$prefix" | cut -c1-"$max_prefix")"
  fi
  printf '%s-%s' "$prefix" "$role"
}

# For up: reuse this project's live agent name; fall back to the prefixed name
# when the bare name is taken by another project
pick_name() {
  local role="$1" name
  if agent_ours "$role" || ! agent_exists "$role"; then
    printf '%s' "$role"
    return
  fi
  name="$(prefixed_name "$role")" || die "bare name for role ${role} is taken and no valid prefixed name can be generated"
  if agent_exists "$name" && ! agent_ours "$name"; then
    die "both bare and prefixed names for role ${role} are taken by other projects: $name"
  fi
  printf '%s' "$name"
}

# For down/status: return the role's currently live agent name (this workspace
# only); empty output when not running
resolve_live_name() {
  local role="$1" name
  if agent_ours "$role"; then
    printf '%s' "$role"
    return
  fi
  name="$(prefixed_name "$role" 2>/dev/null || true)"
  if [ -n "$name" ] && agent_ours "$name"; then
    printf '%s' "$name"
  fi
}

# Tab ids named after the role in the current workspace
tabs_for_role() {
  herdr tab list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
    | jq -r --arg l "$1" '.result.tabs[]? | select(.label == $l) | .tab_id // empty'
}

# Syntax verified against herdr 0.8.2: herdr tab close <tab_id>
close_tab() {
  local id="$1" out
  out="$(herdr tab close "$id" 2>&1)" && return 0
  log "cannot close tab ${id}: ${out}"
  return 1
}

# herdr agent start, retrying on agent_pane_busy (the shell may not be ready
# right after tab creation)
start_agent() {
  local name="$1" kind="$2" pane="$3" args="$4" attempt=1 out code
  while :; do
    if [ -n "$args" ]; then
      # shellcheck disable=SC2086
      set -f; set -- $args; set +f
      out="$(herdr agent start "$name" --kind "$kind" --pane "$pane" -- "$@" 2>&1)" && return 0
    else
      out="$(herdr agent start "$name" --kind "$kind" --pane "$pane" 2>&1)" && return 0
    fi
    code="$(printf '%s' "$out" | jq -r '.error.code // empty' 2>/dev/null || true)"
    # Some agents (e.g. codex) show a startup screen briefly detected as blocked,
    # making start report agent_not_ready even though registration succeeded;
    # treat a registered agent as successfully started
    if [ "$code" = "agent_not_ready" ] && agent_ours "$name"; then
      log "note: ${name} was briefly judged blocked during startup; registration confirmed, continuing"
      return 0
    fi
    if [ "$code" != "agent_pane_busy" ] || [ "$attempt" -ge 10 ]; then
      printf '%s\n' "$out" >&2
      return 1
    fi
    sleep 1
    attempt=$((attempt + 1))
  done
}

# Inject the role definition; retry once, then leave manual guidance (non-fatal)
inject_role() {
  local name="$1" role="$2" msg
  msg="Your role definition file is .herdr/roles/${role}.md. Read it in full first and follow its responsibilities and hard rules in all subsequent work. After reading, reply only: role ready. Then wait for tasks."
  herdr agent prompt "$name" "$msg" --wait --timeout 120000 >/dev/null 2>&1 && return 0
  herdr agent prompt "$name" "$msg" --wait --timeout 120000 >/dev/null 2>&1 && return 0
  log "note: role injection for ${name} was not confirmed. Once it is idle, run manually: herdr agent prompt ${name} \"Read .herdr/roles/${role}.md and follow it strictly\""
}

launch_role() {
  local role="$1" kind="$2" args="$3" name pane res
  if ! name="$(pick_name "$role")"; then
    log "failed: ${role} (no available agent name; no tab created)"
    FAILED="${FAILED}- ${role}"$'\n'
    return 1
  fi
  if [ -z "$name" ]; then
    log "failed: ${role} (name selection returned empty; no tab created)"
    FAILED="${FAILED}- ${role}"$'\n'
    return 1
  fi
  if agent_ours "$name"; then
    log "reuse: $role → ${name} (already alive)"
    ROSTER="${ROSTER}- ${role} → ${name}"$'\n'
    return 0
  fi
  res="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --label "$role" --cwd "$REPO_ROOT" --no-focus)"
  pane="$(printf '%s' "$res" | jq -r '.result.root_pane.pane_id // empty')"
  [ -n "$pane" ] || { log "failed: ${role} (tab creation returned no pane id)"; FAILED="${FAILED}- ${role}"$'\n'; return 1; }
  if start_agent "$name" "$kind" "$pane" "$args"; then
    inject_role "$name" "$role"
    log "ready: $role → ${name} (kind=${kind}${args:+, args: ${args}})"
    ROSTER="${ROSTER}- ${role} → ${name}"$'\n'
  else
    log "failed: $role → ${name} (agent start failed; pane ${pane} kept for inspection)"
    FAILED="${FAILED}- ${role}"$'\n'
    return 1
  fi
}

down_role() {
  local role="$1" name tabs id closed=0
  name="$(resolve_live_name "$role")"
  tabs="$(tabs_for_role "$role")"
  if [ -z "$name" ] && [ -z "$tabs" ]; then
    log "skip: $role is not running"
    return 0
  fi
  if [ -z "$tabs" ]; then
    log "note: ${role} (agent ${name}) is alive but no role-named tab was found; it may have been started elsewhere — handle manually"
    FAILED="${FAILED}- ${role}"$'\n'
    return 1
  fi
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if close_tab "$id"; then
      closed=$((closed + 1))
    else
      FAILED="${FAILED}- ${role}"$'\n'
      return 1
    fi
  done <<EOF
$tabs
EOF
  log "stopped: $role${name:+ (agent ${name})}, closed ${closed} tab(s)"
}

require_herdr_env() {
  command -v jq >/dev/null || die "missing dependency: jq"
  command -v herdr >/dev/null || die "missing dependency: herdr"
  [ "${HERDR_ENV:-}" = "1" ] || die "not inside a Herdr-managed pane (HERDR_ENV != 1)"
  [ -n "${HERDR_WORKSPACE_ID:-}" ] || die "HERDR_WORKSPACE_ID is missing (run inside a Herdr-managed pane)"
}

guard_role() {
  local role="$1"
  [ "$role" = "tech-lead" ] && die "tech-lead is you in the main pane; this script does not manage it"
  [ -f "$HERDR_DIR/roles/$role.md" ] || die "unknown role (missing .herdr/roles/${role}.md): $role"
}

cmd_print() {
  local file plan
  file="$(conf_file)"
  plan="$(parse_conf "$file")"
  echo "Config file: $file"
  echo "Launch plan (role / kind / args):"
  printf '%s\n' "$plan" | awk -F'\t' '{ printf "  %-12s %-8s %s\n", $1, $2, $3 }'
}

cmd_status() {
  local file plan role kind args name
  file="$(conf_file)"
  plan="$(parse_conf "$file")"
  require_herdr_env
  echo "Config file: $file"
  echo "Squad status:"
  while IFS=$'\t' read -r role kind args; do
    [ -n "$role" ] || continue
    name="$(resolve_live_name "$role")"
    if [ -n "$name" ]; then
      printf '  %-12s alive → %s (kind=%s%s)\n' "$role" "$name" "$kind" "${args:+, args: ${args}}"
    else
      printf '  %-12s not running (kind=%s%s)\n' "$role" "$kind" "${args:+, args: ${args}}"
    fi
  done <<EOF
$plan
EOF
}

cmd_up() {
  local file plan role kind args found
  file="$(conf_file)"
  plan="$(parse_conf "$file")"
  if [ "$#" -ge 1 ]; then
    role="$1"
    guard_role "$role"
    found="$(printf '%s\n' "$plan" | awk -F'\t' -v r="$role" '$1 == r { print; exit }')"
    if [ -n "${2:-}" ]; then
      kind="$2"; args=""
    elif [ -n "$found" ]; then
      kind="$(printf '%s' "$found" | cut -f2)"
      args="$(printf '%s' "$found" | cut -f3)"
    else
      kind="$DEFAULT_KIND"; args=""
    fi
    require_herdr_env
    launch_role "$role" "$kind" "$args" || true
  else
    [ -n "$plan" ] || die "no role enabled in config $file"
    require_herdr_env
    log "=== launching squad per $file ==="
    while IFS=$'\t' read -r role kind args; do
      [ -n "$role" ] || continue
      launch_role "$role" "$kind" "$args" || true
    done <<EOF
$plan
EOF
  fi
  echo
  if [ -n "$ROSTER" ]; then
    echo "Actual agent name per role (use these when delegating):"
    printf '%s' "$ROSTER"
  fi
}

cmd_down() {
  local file plan role
  file="$(conf_file)"
  plan="$(parse_conf "$file")"
  [ "$#" -ge 1 ] && guard_role "$1"
  require_herdr_env
  if [ "$#" -ge 1 ]; then
    down_role "$1" || true
  else
    log "=== stopping squad ==="
    while IFS=$'\t' read -r role _ _; do
      [ -n "$role" ] || continue
      down_role "$role" || true
    done <<EOF
$plan
EOF
  fi
}

ROSTER=""
FAILED=""

finish() {
  if [ -n "$FAILED" ]; then
    echo
    echo "Roles that failed:"
    printf '%s' "$FAILED"
    exit 1
  fi
}

main() {
  local cmd="${1:-}"
  [ "$#" -gt 0 ] && shift
  case "$cmd" in
    up)       cmd_up "$@"; finish ;;
    down)     cmd_down "$@"; finish ;;
    restart)  cmd_down "$@"; FAILED=""; cmd_up "$@"; finish ;;
    status)   cmd_status ;;
    print|--print) cmd_print ;;
    -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; [ "$cmd" = "" ] && exit 2 || exit 0 ;;
    *) die "unknown subcommand: ${cmd} (available: up / down / restart / status / print)" ;;
  esac
}

main "$@"
