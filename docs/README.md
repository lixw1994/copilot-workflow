# copilot-workflow Documentation Suite

This document is the navigation index for the `docs/` directory. It helps you quickly locate workflow specifications, installation guides, and optional Herdr squad collaboration documentation.

## Documentation Catalog

| Document | Type | Key Topics | Primary Use Case |
|----------|------|------------|------------------|
| [Architecture (architecture.md)](./architecture.md) | Explanation | System overview, workflow/machine layer split, source/instance mapping, conditional runtime, installer behavior, squad topology (with diagrams) | Understanding or modifying the template itself |
| [Getting Started (getting-started.md)](./getting-started.md) | How-to guide | Prerequisites, one-command installation, component selection, degraded recovery, and legacy codebase onboarding | Initial setup, environment configuration, and project initialization |
| [Engineering Workflow (workflow.md)](./workflow.md) | Explanation / Reference | Core workflow specifications, change classification, OpenSpec 5-artifact pipeline, Spike mode, ADR immutability, and pre-commit hooks | Architecture design, feature implementation, and quality enforcement |
| [Squad Guide (squad-guide.md)](./squad-guide.md) | How-to / Reference | Optional Herdr squad enhancement, role permission matrix, `.herdr/scripts/squad.sh` lifecycle commands, asynchronous delegation, and squad configuration | Multi-role collaboration, squad management, and task delegation |

## Core Design Concepts

- **Workflow-First & Squad as an Enhancement**: The engineering workflow (OpenSpec + ADR + pre-commit hooks) is versioned with the repository. Any coding agent following `AGENTS.md` at the repository root can execute the workflow without requiring Herdr. The Herdr squad is an optional enhancement installed in `.herdr/` (which is fully ignored by `.gitignore`), leaving the project repository unpolluted.
- **Single Tech Lead & Context Isolation**: The Tech Lead agent in the main pane practices Dogfooding and owns all architecture, development, and maintenance. Auxiliary agents (`researcher`, `writer`, `worker`) are launched on demand, isolating voluminous reference material and multi-turn drafting iterations inside their own context windows.
- **Two Persistent Sources of Truth**: `openspec/specs/` maintains the current functional capability specifications, while `adr/` maintains durable architectural decision records.
- **Automated Quality Gates**: The `spec-driven-with-adr` pipeline and pre-commit hooks enforce specification validation and the immutability of accepted ADRs.

## Command Quick Reference

### Engineering Workflow (No Herdr Required)

```bash
# Validate OpenSpec changes and specification compliance
openspec validate --all --strict

# Initialize or upgrade managed components in the project
./init.sh --with squad,openspec,adr,skills,hooks
```

### Squad Lifecycle Management (Herdr Environment)

```bash
.herdr/scripts/squad.sh up                 # Launch all squad members according to configuration
.herdr/scripts/squad.sh up researcher      # Launch a single role
.herdr/scripts/squad.sh status             # View member status and actual agent names
.herdr/scripts/squad.sh down [role]        # Stop all squad members or a specific role
.herdr/scripts/squad.sh restart [role]     # Restart all squad members or a specific role
.herdr/scripts/squad.sh print              # Print launch plan (no Herdr environment required)
```

### Task Delegation and Result Retrieval

```bash
# Delegate a self-contained task asynchronously
herdr agent prompt <actual-agent-name> "<task-description>"

# Check agent status
herdr agent get <actual-agent-name>

# Read the latest response from an agent
herdr agent read <actual-agent-name> --source recent-unwrapped --lines 120
```
