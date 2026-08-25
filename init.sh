#!/usr/bin/env bash
# copilot-workflow one-command installer
#
# Installs the engineering workflow (OpenSpec + ADR + skills + discipline hooks)
# into the project in the current directory, plus the optional Herdr squad
# enhancement (into .herdr/, gitignored as a whole — it never enters version control).
# Merge-based and idempotent: existing user content is never overwritten; rerunning
# upgrades managed content.
#
# Usage:
#   ./init.sh [--with squad,openspec,adr,skills,hooks] [--tools agents] [--language English]
#   curl -fsSL https://raw.githubusercontent.com/lixw1994/copilot-workflow/main/init.sh | bash
#
# Environment variables:
#   COPILOT_WORKFLOW_REPO   Template repository URL (default https://github.com/lixw1994/copilot-workflow)
set -euo pipefail

MARKER_BEGIN="<!-- copilot-workflow:begin -->"
MARKER_END="<!-- copilot-workflow:end -->"
DEFAULT_REPO="${COPILOT_WORKFLOW_REPO:-https://github.com/lixw1994/copilot-workflow}"
ALL_COMPONENTS="squad openspec adr skills hooks"
MANIFEST=".copilot-workflow.yaml"

COMPONENTS="$ALL_COMPONENTS"
# agents = universal target (.agents/skills/, discoverable by every coding agent)
TOOLS="agents"
LANGUAGE="English"
SRC=""
SRC_TMP=""
SRC_VERSION="unknown"
INSTALLED=""
TARGET="$PWD"
HAD_EXISTING_CODE=0

log()  { printf '\033[1;34m[copilot-workflow]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[copilot-workflow]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[copilot-workflow]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,16p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
  exit 0
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --with)     COMPONENTS="$(printf '%s' "${2:?--with requires a value}" | tr ',' ' ')"; shift 2 ;;
      --tools)    TOOLS="${2:?--tools requires a value}"; shift 2 ;;
      --language) LANGUAGE="${2:?--language requires a value}"; shift 2 ;;
      -h|--help)  usage ;;
      *) die "Unknown argument: ${1} (see --help)" ;;
    esac
  done
  for c in $COMPONENTS; do
    case " $ALL_COMPONENTS " in
      *" $c "*) ;;
      *) die "Unknown component: ${c} (available: ${ALL_COMPONENTS// /, })" ;;
    esac
  done
}

has_component() { case " $COMPONENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
mark_installed() { INSTALLED="$INSTALLED $1"; }

# Progressive installation: when a component is skipped, record the exact
# remediation command and print a summary at the end
SKIPPED=""
note_skip() { SKIPPED="${SKIPPED}  - $1"$'\n'"    Fix: $2"$'\n'; }

resolve_source() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  if [ -n "$script_dir" ] && [ -f "$script_dir/squad/roles/tech-lead.md" ]; then
    SRC="$script_dir"
    SRC_VERSION="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo local)"
    log "Install source: local template repository ${SRC} (version ${SRC_VERSION})"
  else
    SRC_TMP="$(mktemp -d)"
    log "Install source: cloning $DEFAULT_REPO ..."
    git clone --quiet --depth 1 "$DEFAULT_REPO" "$SRC_TMP/copilot-workflow" \
      || die "Cannot clone template repository ${DEFAULT_REPO} (override with COPILOT_WORKFLOW_REPO)"
    SRC="$SRC_TMP/copilot-workflow"
    SRC_VERSION="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi
  [ -f "$SRC/squad/roles/tech-lead.md" ] || die "Install source is missing template content: $SRC"
}

cleanup() { if [ -n "$SRC_TMP" ]; then rm -rf "$SRC_TMP"; fi; }
trap cleanup EXIT

detect_existing_code() {
  if find "$TARGET" -mindepth 1 -maxdepth 2 \
      -not -path "$TARGET/.git" -not -path "$TARGET/.git/*" \
      -type f -print -quit 2>/dev/null | grep -q .; then
    HAD_EXISTING_CODE=1
  fi
}

# Managed directories are replaced wholesale (rerun = upgrade); when source and
# target paths coincide (template repo self-install), leave them alone
sync_dir() {
  local from="$1" to="$2"
  [ "$from" = "$to" ] && return 0
  mkdir -p "$(dirname "$to")"
  rm -rf "$to"
  cp -R "$from" "$to"
}

merge_agents_md() {
  local block_src="$SRC/AGENTS.md" target_md="$TARGET/AGENTS.md" tmp
  if [ "$SRC" = "$TARGET" ]; then
    log "AGENTS.md merge skipped: target is the template repository itself"
    return
  fi
  tmp="$(mktemp)"
  if [ ! -f "$target_md" ]; then
    { echo "$MARKER_BEGIN"; cat "$block_src"; echo "$MARKER_END"; } > "$target_md"
    log "Created AGENTS.md (managed marker block)"
    return
  fi
  local b e
  b="$(grep -cF "$MARKER_BEGIN" "$target_md" || true)"
  e="$(grep -cF "$MARKER_END" "$target_md" || true)"
  if [ "$b" = "0" ] && [ "$e" = "0" ]; then
    { cat "$target_md"; echo; echo "$MARKER_BEGIN"; cat "$block_src"; echo "$MARKER_END"; } > "$tmp"
    mv "$tmp" "$target_md"
    log "Appended managed marker block to existing AGENTS.md (original content untouched)"
  elif [ "$b" = "1" ] && [ "$e" = "1" ]; then
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" -v src="$block_src" '
      $0 == begin { print; while ((getline line < src) > 0) print line; close(src); skip=1; next }
      $0 == end   { skip=0; print; next }
      !skip { print }
    ' "$target_md" > "$tmp"
    mv "$tmp" "$target_md"
    log "Updated the managed marker block in AGENTS.md (content outside the block untouched)"
  else
    rm -f "$tmp"
    die "Unpaired copilot-workflow markers in AGENTS.md (begin=${b}, end=${e}); repair manually and rerun"
  fi
}

# Ensure the target .gitignore contains the entry (append if missing, never touch existing content)
ensure_gitignore() {
  local entry="$1" gi="$TARGET/.gitignore"
  if [ -f "$gi" ] && grep -qxF "$entry" "$gi"; then return 0; fi
  # If the existing file lacks a trailing newline, add one first so the entry
  # does not get glued onto user content
  if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ]; then printf '\n' >> "$gi"; fi
  printf '%s\n' "$entry" >> "$gi"
}

# Squad enhancement: squad/ source → target .herdr/ runtime instance
# (machine-level environment; the whole directory stays out of version control)
install_squad() {
  sync_dir "$SRC/squad/roles" "$TARGET/.herdr/roles"
  sync_dir "$SRC/squad/scripts" "$TARGET/.herdr/scripts"
  cp "$SRC/squad/AGENTS.md" "$TARGET/.herdr/AGENTS.md"
  # squad.conf is the managed default; user customization goes in
  # .herdr/squad.local.conf (never touched)
  cp "$SRC/squad/squad.conf" "$TARGET/.herdr/squad.conf"
  mkdir -p "$TARGET/.herdr/handoff"
  ensure_gitignore ".herdr/"
  merge_agents_md
  mark_installed squad
  log "Component squad: protocol + roles + config + script installed into .herdr/ (gitignored)"
}

install_openspec() {
  if ! command -v openspec >/dev/null 2>&1; then
    local fix="npm install -g @fission-ai/openspec@latest"
    if ! command -v npm >/dev/null 2>&1; then
      fix="install Node.js first (for example, brew install node), then ${fix}"
    fi
    warn "Component openspec skipped: openspec CLI not found"
    note_skip "openspec (workspace + schemas + workflow skills)" "${fix}; then rerun this script"
    return
  fi
  if [ ! -d "$TARGET/openspec" ]; then
    (cd "$TARGET" && openspec init --tools "$TOOLS" --language "$LANGUAGE" --no-animation >/dev/null) \
      || { warn "openspec init failed; component openspec skipped"
           note_skip "openspec (init failed)" "investigate, then rerun: cd ${TARGET} && openspec init --tools ${TOOLS}"
           return; }
  fi
  sync_dir "$SRC/openspec/schemas/spec-driven-with-adr" "$TARGET/openspec/schemas/spec-driven-with-adr"
  sync_dir "$SRC/openspec/schemas/minimalist" "$TARGET/openspec/schemas/minimalist"
  # Set the default schema to spec-driven-with-adr (preserve the rest of the config)
  local cfg="$TARGET/openspec/config.yaml" tmp
  tmp="$(mktemp)"
  if [ -f "$cfg" ] && grep -q '^schema:' "$cfg"; then
    sed 's/^schema:.*/schema: spec-driven-with-adr/' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
  else
    { echo "schema: spec-driven-with-adr"; [ -f "$cfg" ] && cat "$cfg"; } > "$tmp" && mv "$tmp" "$cfg"
  fi
  mark_installed openspec
  log "Component openspec: workspace + both schemas installed (default spec-driven-with-adr; minimalist for spikes)"
}

install_adr() {
  mkdir -p "$TARGET/adr"
  [ "$SRC" = "$TARGET" ] || cp "$SRC/adr/README.md" "$TARGET/adr/README.md"
  mark_installed adr
  log "Component adr: decision directory ready (rules only; the template's own ADRs are not copied)"
}

SKILL_NAMES=""

# The skill manifest comes from two declarations: each schema's skills.txt
# plus the squad-level squad/skills.txt
install_skills() {
  local f s names=""
  for f in "$SRC"/openspec/schemas/*/skills.txt "$SRC/squad/skills.txt"; do
    [ -f "$f" ] || continue
    while IFS= read -r s || [ -n "$s" ]; do
      s="${s%%#*}"
      s="$(printf '%s' "$s" | tr -d '[:space:]')"
      [ -n "$s" ] || continue
      case " $names " in *" $s "*) continue ;; esac
      [ -d "$SRC/.agents/skills/$s" ] || { warn "Declared skill missing from the template repository: $s"; continue; }
      sync_dir "$SRC/.agents/skills/$s" "$TARGET/.agents/skills/$s"
      names="$names $s"
    done < "$f"
  done
  [ -n "$names" ] || { warn "Component skills skipped: no skills declared in any manifest"; return; }
  SKILL_NAMES="$names"
  mark_installed skills
  log "Component skills: installed per manifest${names}"
}

install_hooks() {
  if [ ! -d "$TARGET/.git" ]; then
    warn "Component hooks skipped: current directory is not a git repository"
    note_skip "hooks (pre-commit discipline hook)" "run git init, then rerun this script"
    return
  fi
  # Hook logic is versioned with the project (works on collaborators' machines
  # without Herdr); the shim is generated by this script
  mkdir -p "$TARGET/scripts"
  [ "$SRC" = "$TARGET" ] || cp "$SRC/scripts/pre-commit.sh" "$TARGET/scripts/pre-commit.sh"
  chmod +x "$TARGET/scripts/pre-commit.sh"

  local hook="$TARGET/.git/hooks/pre-commit"
  if [ -f "$hook" ] && ! grep -q 'copilot-workflow hook shim' "$hook"; then
    local backup="$hook.backup.$(date +%Y%m%d%H%M%S)"
    mv "$hook" "$backup"
    chmod +x "$backup" 2>/dev/null || true
    log "Existing pre-commit hook backed up as $(basename "$backup"); it will be chain-called"
  fi
  cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# copilot-workflow hook shim (managed file, do not edit; logic lives in scripts/pre-commit.sh)
set -uo pipefail
repo_root="$(git rev-parse --show-toplevel)"
for prev in "$repo_root"/.git/hooks/pre-commit.backup.*; do
  if [ -x "$prev" ]; then
    "$prev" "$@" || exit $?
  fi
done
exec "$repo_root/scripts/pre-commit.sh" "$@"
HOOK
  chmod +x "$hook"
  mark_installed hooks
  log "Component hooks: pre-commit discipline hook ready (spec validation + ADR immutability)"
}

write_manifest() {
  {
    echo "# copilot-workflow install manifest (managed file, maintained by init.sh)"
    echo "template: copilot-workflow"
    echo "source: $DEFAULT_REPO"
    echo "version: $SRC_VERSION"
    echo "installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "components:"
    for c in $INSTALLED; do echo "  - $c"; done
    echo "managed_paths:"
    echo "  - AGENTS.md  # marker block only"
    for c in $INSTALLED; do
      case "$c" in
        squad)    echo "  - .herdr/  # except squad.local.conf and handoff/" ;;
        openspec) echo "  - openspec/schemas/" ;;
        adr)      echo "  - adr/README.md" ;;
        skills)   for s in $SKILL_NAMES; do echo "  - .agents/skills/$s/"; done ;;
        hooks)    echo "  - scripts/pre-commit.sh"; echo "  - .git/hooks/pre-commit" ;;
      esac
    done
  } > "$TARGET/$MANIFEST"
  log "Manifest written to ${MANIFEST} (rerun this script to upgrade managed content)"
}

# Runtime dependency health check (informational, never blocks): squad
# collaboration only works inside a Herdr environment
MISSING_RUNTIME=""
check_runtime_deps() {
  has_component squad || return 0
  command -v jq >/dev/null 2>&1 \
    || MISSING_RUNTIME="${MISSING_RUNTIME}  - jq (required by .herdr/scripts/squad.sh): brew install jq"$'\n'
  command -v herdr >/dev/null 2>&1 \
    || MISSING_RUNTIME="${MISSING_RUNTIME}  - herdr (required to launch squad members): install Herdr, then rerun this script"$'\n'
}

print_guidance() {
  if [ -n "$SKIPPED" ]; then
    echo
    log "The following components were skipped this run (the script is idempotent — fix the environment and rerun to fill the gap; installed content is unaffected):"
    printf '%s' "$SKIPPED"
  fi
  if [ -n "$MISSING_RUNTIME" ]; then
    echo
    log "Missing runtime dependencies (this install is fine, but squad collaboration will not work; the workflow itself is unaffected):"
    printf '%s' "$MISSING_RUNTIME"
  fi
  echo
  log "Installation complete. Next steps:"
  echo "  1. Restart your IDE / agent session so AGENTS.md and the openspec workflow skills take effect"
  echo "  2. Tell the agent about large changes directly; it will run proposal → specs → design → adr → tasks"
  echo "  3. With a Herdr environment, the main-pane agent follows .herdr/AGENTS.md and leads the squad as Tech Lead"
  echo "  Note: .herdr/ is not versioned; machines that clone this project should rerun init.sh to restore the squad and hooks"
  if [ "$HAD_EXISTING_CODE" = "1" ]; then
    echo
    log "Existing code detected. Suggested cold start (send this to your agent verbatim):"
    echo "  \"Onboard this codebase: 1) read the code and derive the current system's core"
    echo "   capabilities into initial specs (openspec/specs/<capability>/spec.md); 2) backfill"
    echo "   the 3-5 most important established architecture decisions as ADRs"
    echo "   (adr/NNNN-*.md, status accepted, marked as retroactive).\""
  fi
}

main() {
  parse_args "$@"
  command -v git >/dev/null 2>&1 \
    || die "Missing required dependency: git (on macOS run xcode-select --install or brew install git, then rerun this script)"
  detect_existing_code
  resolve_source
  log "Target project: $TARGET"
  log "Components: $COMPONENTS"

  has_component squad    && install_squad
  has_component openspec && install_openspec
  has_component adr      && install_adr
  has_component skills   && install_skills
  has_component hooks    && install_hooks

  [ -n "$INSTALLED" ] || die "No component was installed successfully"
  write_manifest
  check_runtime_deps
  print_guidance
}

main "$@"
