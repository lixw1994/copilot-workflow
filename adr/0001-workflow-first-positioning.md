# ADR-0001: Workflow-first positioning — the workflow is versioned, the squad is optional

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

This project is an AI collaboration template installable into any codebase, containing two kinds of capability: an engineering workflow (OpenSpec change management + ADRs + discipline hooks) and a Herdr-based multi-agent squad. Their lifecycles differ: the workflow constrains every change and must be versioned with the project and apply to all collaborators; the squad depends on the Herdr terminal environment and is only meaningful on machines that have it. If squad assets were installed as top-level directories in target projects, users without Herdr would carry useless baggage, and the project would be misread as a "multi-agent orchestration framework".

## Decision

1. Position the project **workflow-first**, named **copilot-workflow**: only the engineering workflow (OpenSpec workspace, ADR directory, discipline hooks, AGENTS.md discipline block, companion skills) enters the target project's version control; the Herdr squad is an optional enhancement, and any coding agent can use the workflow fully without it
2. The managed block in the root AGENTS.md contains only workflow discipline plus a conditional dispatch: when `HERDR_ENV=1` and `.herdr/AGENTS.md` exists, read the squad protocol; otherwise work solo. Squad concepts (Tech Lead, roles, delegation protocol) exist only in the squad protocol file
3. All public identifiers use the copilot-workflow root: `COPILOT_WORKFLOW_*` environment variables, the `.copilot-workflow.yaml` manifest, `<!-- copilot-workflow:begin/end -->` markers, the hook shim identifier string

## Consequences

- Positive: name matches substance; users without Herdr get a complete, zero-overhead workflow template; users with Herdr get the squad enhancement with no extra configuration
- Negative: "copilot-workflow" invites association with GitHub Copilot (accepted knowingly by the author)
- Constraints: all future public identifiers use the copilot-workflow root; squad capability must never become a precondition for the workflow to function
