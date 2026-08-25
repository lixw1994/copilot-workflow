# ADR-0002: Adopt OpenSpec with the spec-driven-with-adr schema for change management

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

LLM agents have no cross-session memory; code only says "what", and the "why" behind architecture decisions evaporates with each session. A home-grown lightweight process (hand-written ADR templates + a proposal directory) was considered, but OpenSpec is a mature framework, and the community `spec-driven-with-adr` schema has stricter rules built in (derive the effective ADR set before design; ADRs immutable once accepted). The schema is versioned inside the repository, so there is no runtime lock-in.

## Decision

Manage changes with the OpenSpec CLI (`@fission-ai/openspec`); the default schema is the community `spec-driven-with-adr` (proposal → specs → design → adr → tasks), copied into `openspec/schemas/` and versioned with the repo. Layered execution: large changes run the full five artifacts; exploratory spikes use the `minimalist` schema (specs → tasks) or skip process entirely, backfilling through the full pipeline once validated; small changes skip process. `openspec/specs/` and `adr/` are the two persistent sources of truth.

## Consequences

- Positive: architectural reasoning persists across sessions; future changes are designed on top of prior decisions instead of re-arguing or silently contradicting them
- Negative: large changes carry five-artifact process cost; depends on the openspec CLI (when missing, the process degrades to a pure documentation convention)
- Constraints: accepted ADRs are immutable and superseded only by new ADRs; spec-code drift is never tolerated
