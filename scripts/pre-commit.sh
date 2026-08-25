#!/usr/bin/env bash
# copilot-workflow discipline hook: validate OpenSpec artifacts and block
# modification of accepted ADRs before every commit.
# Called by the .git/hooks/pre-commit shim; logic is version-controlled with the
# repository, so upgrades need no hook reinstall.
set -uo pipefail

if [ "${COPILOT_WORKFLOW_SKIP_HOOKS:-}" = "1" ]; then
  echo "[copilot-workflow] COPILOT_WORKFLOW_SKIP_HOOKS=1, skipping discipline checks."
  exit 0
fi

fail=0

# --- Check 1: accepted ADRs are immutable (adr/NNNN-*.md is append-only) ---
adr_violations=""
while IFS=$'\t' read -r status p1 p2; do
  [ -z "${status:-}" ] && continue
  case "$status" in
    A*) ;;
    R*)
      if printf '%s' "$p1" | grep -Eq '^adr/[0-9]{4}-[^/]+\.md$'; then
        adr_violations="${adr_violations}  ${status}  ${p1} -> ${p2}"$'\n'
      fi
      ;;
    M*|D*)
      if printf '%s' "$p1" | grep -Eq '^adr/[0-9]{4}-[^/]+\.md$'; then
        adr_violations="${adr_violations}  ${status}  ${p1}"$'\n'
      fi
      ;;
  esac
done < <(git diff --cached --name-status -- adr/ 2>/dev/null)

if [ -n "$adr_violations" ]; then
  echo "[copilot-workflow] Commit rejected: accepted ADRs must not be modified, deleted, or renamed."
  printf '%s' "$adr_violations"
  echo "[copilot-workflow] Instead: create a new adr/NNNN-*.md with status 'accepted, supersedes ADR-XXXX' and set its Supersedes field."
  fail=1
fi

# --- Check 2: OpenSpec artifact validation ---
if [ -d openspec ]; then
  if command -v openspec >/dev/null 2>&1; then
    if ! openspec validate --all --strict; then
      echo "[copilot-workflow] Commit rejected: openspec validate --all --strict failed."
      fail=1
    fi
  else
    echo "[copilot-workflow] Note: openspec CLI not found, skipping spec validation (npm install -g @fission-ai/openspec@latest)."
  fi
fi

exit "$fail"
