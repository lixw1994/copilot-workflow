# ADR-0006: Split squad source from installed instance (squad/ → .herdr/)

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

Per ADR-0001, the squad must not enter target projects as versioned directories, yet squad assets (role prompts, collaboration protocol, config, scripts) themselves need to be versioned, iterated, and tested inside the template repository. That requires separating source layout from install layout. The template repository also needs a working squad to develop the template itself — if the runtime directory were maintained by hand, the install path would never get real testing.

## Decision

1. The template repository's `squad/` holds versioned source: `AGENTS.md` (squad collaboration protocol), `roles/`, `squad.conf` (config template), `scripts/squad.sh`, `skills.txt`
2. `init.sh` maps `squad/` to the target project's `.herdr/` runtime instance (`AGENTS.md`, `roles/`, `squad.conf`, `scripts/squad.sh`, `handoff/`) and adds `.herdr/` to the target `.gitignore` — the squad is a machine-level environment, restored after clone by rerunning the installer, on the same cadence as git hooks
3. Local user customization lives in `.herdr/squad.local.conf`, never read or written by the installer; member handoff artifacts live in `.herdr/handoff/`
4. The template repository maintains its own `.herdr/` instance by running `./init.sh` on itself (Dogfooding the install path). Squad changes must go through `squad/` source plus reinstall; direct edits to `.herdr/` are overwritten by the next install

## Consequences

- Positive: the squad instance pollutes no project's version control; every template self-iteration exercises the real install path; source and runtime responsibilities stay clear
- Negative: squad configuration does not travel with the project — each machine reruns `init.sh`; the source/instance duality carries a one-time learning cost
- Constraints: squad assets change only via `squad/` source + reinstall; no component may depend on squad files existing in a target project's version control
