# ADR-0004: Mechanize spec and ADR discipline with a git pre-commit hook

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

If "specs never drift" and "accepted ADRs are immutable" rely on prompt discipline alone, agents' adherence to early instructions decays over long sessions — discipline needs a mechanical backstop. Alternatives considered: `core.hooksPath` (hijacks the whole hooks directory; too invasive for existing projects), read-only file bits (easily bypassed, unreliable across platforms), CI-only validation (feedback far too late).

## Decision

The pre-commit hook uses a two-layer "shim + managed script" design: `.git/hooks/pre-commit` is a small shim that calls the version-controlled `scripts/pre-commit.sh`, so hook logic upgrades with the repository and works on collaborators' machines without Herdr. Checks:

1. When `openspec/` exists and the CLI is available, run `openspec validate --all --strict`; failure rejects the commit (a missing CLI prints a notice and passes)
2. Based on `git diff --cached --name-status`, reject modification or deletion of tracked `adr/NNNN-*.md` files; additions pass
3. When the target has a pre-existing non-template hook, back it up; the shim chain-calls the backup first, preserving original behavior
4. `COPILOT_WORKFLOW_SKIP_HOOKS=1` is the escape hatch for maintenance operations

## Consequences

- Positive: discipline shifts from "the agent remembers" to "the mechanism forbids"; hook logic upgrades without reinstalling
- Negative: the escape hatch can be abused (relies on review); local hooks can be bypassed with `--no-verify` — remote CI validation is future work
- Constraints: the hook must stay fast (seconds) and side-effect free, or users will disable it
