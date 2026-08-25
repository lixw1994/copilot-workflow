# AGENTS.md — Engineering Workflow

This project uses the copilot-workflow engineering discipline. Any coding agent working in this repository must follow this file.

## Engineering discipline (OpenSpec workflow)

This project manages changes with OpenSpec. The default schema is `spec-driven-with-adr` (proposal → specs → design → adr → tasks); see `openspec/config.yaml`.

- **Large changes go through the OpenSpec pipeline**: new capabilities, public interface / data model changes, new dependencies, cross-module work. Start a change with the `openspec-new-change` skill, complete all five artifacts, apply, then archive. Small changes (typos, small bugs, local refactors) go straight in.
- **Exploratory spikes take the light path**: prototypes may use `--schema minimalist` (specs → tasks) or skip the process entirely. When a validated spike graduates to a real implementation, return to the full pipeline and backfill design and ADR; spike code must not be promoted as-is.
- **Two sources of truth**: `openspec/specs/` records current system capabilities; `adr/` records current architecture decisions. Read both before designing. Accepted ADRs are immutable — supersede them with new ADRs (see `adr/README.md`).
- **Visualize complex content**: when explaining complex structures, flows, or relationships — in docs, artifacts, or replies — prefer visualization (Mermaid diagrams, tables, directory trees) over long prose.
- **Architecture document**: keep an up-to-date architecture overview at `docs/architecture.md` (create it if missing); update it whenever a structural change lands.

## Herdr squad (optional enhancement)

If and only if `HERDR_ENV=1` and `.herdr/AGENTS.md` exists in this project: you are the squad's Tech Lead — read `.herdr/AGENTS.md` immediately and follow its collaboration protocol.

Otherwise there is no squad environment on this machine: complete all tasks solo, do not attempt to launch any members, and the main development workflow is unaffected.
