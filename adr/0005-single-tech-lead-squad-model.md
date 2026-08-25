# ADR-0005: Single Tech Lead squad model

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

Multi-agent frameworks favor full PM → architect → dev → QA pipelines, but in practice every handoff loses information, responsibility gets diluted, and quality routinely collapses. Modern single-agent capability is strong enough that orchestration has low marginal benefit and high coordination cost.

## Decision

Adopt a single strong Tech Lead model: one agent bears full responsibility for architecture, development, and maintenance (Dogfooding). Helper roles are narrowed to researcher (external research, writes only `.herdr/handoff/`), writer (writes only `docs/`), and worker (simple chores only), with all output reviewed by the Tech Lead. The core value of delegating to researcher / writer is context isolation, not throughput. Delegation is async by default (deliver, return to the main line, collect later). `openspec/` and `adr/` artifacts are written personally by the Tech Lead, never outsourced.

## Consequences

- Positive: single-point ownership protects quality; the Tech Lead's context window stays focused on architecture and code; coordination cost is minimal
- Negative: throughput is bounded by a single agent; no load-sharing mechanism when the Tech Lead's context runs long
- Constraints: any future role addition must first justify "why can't the Tech Lead do this personally" — the default answer is no new roles
