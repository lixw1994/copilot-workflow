# Spec-Driven With ADR OpenSpec Schema

`spec-driven-with-adr` is for changes that need the standard proposal-to-tasks
OpenSpec flow plus durable Architecture Decision Records.

- Good fit: architectural changes, platform decisions, cross-module work, new
  service boundaries, technology choices, or changes where future contributors
  need a persistent decision trail.
- Not a good fit: small tactical fixes, content-only edits, simple UI changes,
  or work where `specs -> tasks` is enough.

This is the default schema of this project (see `openspec/config.yaml`).

## Stage Gates

Artifact order:
`proposal -> specs -> design -> adr -> tasks`

Gate expectations:
- `specs` must be based on the capabilities identified in `proposal.md`.
- `design` must account for the proposal, specs, and currently in-force ADRs.
- `adr` completes by writing `openspec/changes/<change>/adr.md`, a concise
  ADR review manifest created after design and before task planning.
- `tasks` are planned only after proposal, specs, design, and ADR artifacts are
  complete.

## ADR Persistence

`openspec/changes/<change>/adr.md` is the per-change ADR review artifact used
for OpenSpec artifact completion. It records that ADR review happened, lists
the in-force ADR context that was reviewed, and references any durable ADR files
created for the change.

Durable ADR files are generated under the target repository's top-level `adr/`
folder, not inside the OpenSpec change folder. Create
`adr/NNNN-kebab-title.md` only when the change introduces a major durable
architectural decision. Accepted ADRs are immutable. If a future decision
changes a prior ADR, create a new ADR that supersedes the old one and leave the
original file unchanged.

## Associated Skills

This schema declares its companion skills in `skills.txt`; `init.sh` reads that
list and installs them into the target project's `.agents/skills/`.

- `architectural-decision-records` — drafting/reviewing ADRs; includes MADR,
  Nygard, and Y-statement templates, and takes care of choosing the ADR
  style/template used by this schema.
- `openspec-git-discipline` — git hygiene for OpenSpec propose/apply/archive
  workflows.
