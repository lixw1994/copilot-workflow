# Engineering Workflow

This document explains the core engineering workflow specifications and architectural discipline of copilot-workflow. It helps you assess change scope, execute the OpenSpec 5-artifact pipeline, and follow ADR immutability and pre-commit quality gates.

## Workflow-First Positioning

In copilot-workflow, **the engineering workflow is the core capability**, versioned alongside project code. Any coding agent reading `AGENTS.md` at the repository root can execute and comply with this workflow, without requiring a Herdr environment.

## Change Classification Criteria

Before writing code, the Tech Lead evaluates the scope and impact of the change:

### 1. Major Changes (OpenSpec Workflow Required)

Changes matching any of the following criteria must follow the standardized OpenSpec workflow:
- Adding or significantly modifying a system capability.
- Changing public APIs, interface signatures, or core data models.
- Introducing new external dependencies or technology stack components.
- Cross-module coordination, service boundary adjustments, or architectural refactoring.

### 2. Minor Changes (Direct Implementation)

Lightweight changes that do not alter capability specifications or architecture may be implemented directly without the full workflow:
- Fixing typos in documentation or comments.
- Localized bug fixes that adhere to existing behavior specifications.
- Internal refactoring that does not change external behavior or interfaces.

## OpenSpec Standardized Pipeline (`spec-driven-with-adr`)

The project defaults to the `spec-driven-with-adr` schema (configured in `openspec/config.yaml`).

### 1. Five-Stage Gates

A major change produces five artifacts in sequence:

```
proposal ──> specs ──> design ──> adr ──> tasks
```

| Step | Artifact File | Core Content and Gate Expectations |
|------|---------------|-----------------------------------|
| **1. proposal** | `openspec/changes/<change>/proposal.md` | Explains context, motivation, capabilities to add/modify, scope, and explicit non-goals. |
| **2. specs** | `openspec/changes/<change>/specs/<cap>/spec.md` | Defines detailed requirement specifications for identified capabilities (using Requirements, Gherkin scenarios, or SHALL / MUST statements). |
| **3. design** | `openspec/changes/<change>/design.md` | Technical design taking into account the proposal, specs, and currently in-force ADRs. |
| **4. adr** | `openspec/changes/<change>/adr.md` | Change-level ADR review manifest. If the change introduces durable architectural decisions, creates a new ADR under `adr/`. |
| **5. tasks** | `openspec/changes/<change>/tasks.md` | Actionable, verifiable implementation plan. Authored only after all preceding four artifacts are complete. |

### 2. Change Lifecycle and Implementation Skills

Drive the change lifecycle using workflow skills in `.agents/skills/`:

1. **Create Change**: Use `openspec-new-change` to create the change directory and initial files.
2. **Advance Artifacts**: Use `openspec-continue-change` to advance through proposal → specs → design → adr → tasks.
3. **Apply Implementation**: Use `openspec-apply-change` to execute tasks defined in `tasks.md` and verify with tests.
4. **Verify Compliance**: Use `openspec-verify-change` to confirm that the implementation matches specifications.
5. **Archive Change**: Use `openspec-archive-change` to merge capability specifications into `openspec/specs/` and move the change to archive.

Archive command example:

```bash
openspec archive <change-name>
```

Example output:

```text
Archiving change '<change-name>'...
  Merged specs into openspec/specs/
  Archived change artifacts to openspec/archive/<change-name>/
Change successfully archived.
```

## Exploratory Spike Mode (`minimalist`)

When rapidly prototyping, testing feasibility, or experimenting, use the lightweight schema:

```bash
openspec new <spike-name> --schema minimalist
```

- **Streamlined Artifacts**: The `minimalist` schema consists only of `specs -> tasks`, accelerating the transition to coding.
- **Spike Discipline**:
  1. Spike code **must not be merged directly into production as finished code**.
  2. Once the prototype validates the concept and is chosen for production implementation, return to the default `spec-driven-with-adr` schema to author design and ADR artifacts before implementing production code.

## Architecture Decision Records (ADR) Immutability Discipline

The project maintains two persistent sources of truth:
- `openspec/specs/`: Current system capability specifications.
- `adr/`: Durable history of architectural decisions.

### 1. ADR Formatting and Naming

- **Path**: Target repository `adr/` directory.
- **Naming Convention**: `NNNN-kebab-case-title.md` (for example, `adr/0001-single-tech-lead-team-model.md`).
  - Four-digit sequential index, monotonically incrementing across the repository, never reused.
- **Structure**: MADR-short format containing Title, Status and Date, Context, Decision, Consequences, and optional `Supersedes:` metadata.

### 2. Immutability Principle

- **Accepted ADRs Are Immutable**: Once an ADR status is marked as `accepted`, its content, status, and date must never be edited, deleted, or renamed.
- **Supersede Mechanism**:
  - To revise or overturn an existing decision, create a new ADR with an incremented number (for example, `adr/0006-new-architecture.md`).
  - Mark the new ADR status as: `accepted, supersedes ADR-NNNN`, and explicitly populate the `Supersedes: ADR-NNNN` metadata field.
  - **Leave the old ADR file completely unchanged**. The active decision set is derived by traversing the `Supersedes:` chain and excluding superseded decisions.

### 3. Artifact Ownership

The `openspec/` and `adr/` directories are the domain of the Tech Lead. **They must be authored exclusively by the Tech Lead**. Auxiliary roles (including Writer) must not edit these directories.

## Pre-Commit Discipline Hook and Escape Hatches

A pre-commit git hook ensures automated enforcement of specification integrity and ADR immutability.

### 1. Hook Execution Logic

- `.git/hooks/pre-commit` is a managed shim script installed by `init.sh`. It chains any existing pre-commit hooks before executing `scripts/pre-commit.sh` (which is versioned with the codebase).
- The hook performs two checks:
  1. **ADR Immutability Check**: Inspects staged changes via `git diff --cached`. Any modifications (M), deletions (D), or renames (R) to existing `adr/NNNN-*.md` files cause the commit to be rejected.
  2. **OpenSpec Validation**: Runs `openspec validate --all --strict` to verify syntax and gate compliance across all specs and changes.

### 2. Emergency Escape Hatches

In emergency situations or hotfix rebases, you can bypass hook checks using either method:

```bash
# Method 1: Use the copilot-workflow environment variable to skip discipline checks
COPILOT_WORKFLOW_SKIP_HOOKS=1 git commit -m "Emergency fix"

# Method 2: Use native git flag to skip pre-commit hooks entirely
git commit --no-verify -m "Emergency fix"
```

## Related Documentation

- [Documentation Suite Index (README.md)](./README.md): Documentation catalog and quick reference.
- [Getting Started (getting-started.md)](./getting-started.md): Installation and setup guide.
- [Squad Guide (squad-guide.md)](./squad-guide.md): Optional Herdr squad collaboration and lifecycle management.
