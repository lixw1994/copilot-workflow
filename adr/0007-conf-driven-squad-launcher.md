# ADR-0007: Shell-native conf for the squad launcher; role prompts keep a single source of truth

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

The squad launcher needs per-role agent kind and model parameters plus one-command full-squad launch. A community approach we studied uses YAML configuration (adding python3 + PyYAML dependencies), inlines role system prompts into the config (duplicating the role files), unconditionally prefixes agent names with the project name (hurting the single-project case), and creates a dedicated workspace for the squad (violating the Herdr convention of not creating unrequested topology).

## Decision

1. Config format is shell-native conf (one line per role: `<role> <kind> [args...]`; commenting a line disables the role), parsed with bash built-ins, zero new dependencies. `.herdr/squad.conf` is the installer-managed default; `.herdr/squad.local.conf` is the user's local override (whole-file precedence, never read or written by the installer)
2. Role system prompts live solely in `.herdr/roles/<role>.md`; the config has no system field — the launcher injects only a "read your role file" instruction
3. Agent naming prefers the bare role name; when taken by another project in the session, fall back to `<sanitized-project-dir-prefix>-<role>` (32-char cap). The actual name is whatever the launcher prints
4. Topology: one tab per role, named after the role, inside the current workspace — no new workspaces, no split panes. Lifecycle subcommands up / down / restart / status / print, idempotent and re-entrant

## Consequences

- Positive: dependencies stay at bash + git + jq + herdr; role definitions have a single source; simple naming in the single-project case; multiple projects coexist without collisions
- Negative: conf format cannot express argument values containing spaces (by convention model names and parameters have none); whole-file local override means template default updates do not auto-merge into user config
- Constraints: future launcher evolution must not move role prompts into the config; `squad.local.conf` is never touched by the installer (extending the ADR-0003 promise)
