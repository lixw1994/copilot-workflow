# Architecture Decision Records (ADR)

This directory holds all of the project's significant architecture decisions, one file per decision, consulted whenever a new change is designed. It is written for developers and agents who need to know "why it was decided this way".

Maintained by the OpenSpec `spec-driven-with-adr` workflow at the adr step of each change (see `openspec/schemas/spec-driven-with-adr/`).

Rules:

- File names are `NNNN-kebab-title.md`: four-digit sequence, repository-wide, monotonically increasing, never reused (e.g. `0003-merge-based-idempotent-installer.md`).
- Each record has five parts: title, status/date, context, decision, consequences (a trimmed MADR template).
- **Accepted ADRs are immutable** — body, status, and date alike. To overturn an old decision, write a new ADR with status "accepted, supersedes ADR-NNNN" and set its `Supersedes:` field to the superseded record.
- To determine which decisions are currently in effect: any ADR not pointed to by a later ADR's `Supersedes:` field is still effective; superseded ones remain as history only.
