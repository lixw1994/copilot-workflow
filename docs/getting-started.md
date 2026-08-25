# Getting Started

This document is the installation and setup guide for copilot-workflow. It guides you through preparing machine dependencies, integrating the engineering workflow (and optional Herdr squad) into new or existing projects, and onboarding legacy codebases.

## Prerequisites

Before running the installation script, verify the dependencies required for your environment.

### 1. Required Dependencies

- `git`: Version control tool. On macOS, install via `xcode-select --install` or `brew install git`.

### 2. Engineering Workflow Dependencies

- `openspec` CLI: OpenSpec change workflow command-line tool (version ≥ 1.3 required). Install via:
  ```bash
  npm install -g @fission-ai/openspec@latest
  ```

### 3. Optional Herdr Squad Dependencies

If you plan to use the multi-role AI squad enhancement, prepare the following tools:
- `jq`: Required by `.herdr/scripts/squad.sh` to parse Herdr JSON output. On macOS, install via `brew install jq`.
- `herdr`: Terminal multiplexer and agent manager. Install it before enabling the squad.
- **Coding Agent**: Any AI coding agent kind supported by the installed Herdr version.
  - Default agent kind: `codex`.
  - Override the default by setting the `HERDR_AGENT_KIND` environment variable.

## Running Installation

The `init.sh` script installs the engineering workflow and squad enhancement into any new or existing project.

### Option 1: Remote Installation

Run the following command in your target project root directory:

```bash
curl -fsSL https://raw.githubusercontent.com/lixw1994/copilot-workflow/main/init.sh | bash
```

### Option 2: Local Installation

If you have already cloned this repository locally, execute:

```bash
cd /path/to/target-project
/path/to/copilot-workflow/init.sh
```

## Customizing Installation Options and Components

You can customize the installed components, target tool integrations, and artifact language using CLI flags:

```bash
./init.sh [--with squad,openspec,adr,skills,hooks] [--tools agents] [--language English]
```

### 1. Component Selection (`--with`)

By default, all components are installed: `squad openspec adr skills hooks`. You can select specific components using a comma-separated list:

| Component | Description | Target Path |
|-----------|-------------|-------------|
| `squad` | Optional Herdr squad enhancement (prompts, configuration template, lifecycle script, `.herdr/AGENTS.md`) | `.herdr/` (automatically added to `.gitignore`) |
| `openspec` | OpenSpec workspace with dual schemas (`spec-driven-with-adr`, `minimalist`) and configuration | `openspec/schemas/`, `openspec/config.yaml` |
| `adr` | Architecture Decision Records directory and formatting rules | `adr/README.md` |
| `skills` | Companion skills declared by schemas and the squad | `.agents/skills/<skill-name>/` |
| `hooks` | Pre-commit discipline hooks (enforcing spec validity and ADR immutability) | `.git/hooks/pre-commit`, `scripts/pre-commit.sh` |

### 2. Skill Source Declarations

The `skills` component aggregates skill declarations from two locations and installs them into `.agents/skills/`:
- Workflow schema declarations: `openspec/schemas/*/skills.txt` (such as `architectural-decision-records`, `openspec-git-discipline`).
- Squad-level declarations: `squad/skills.txt` (such as `tech-doc` and `eli5`).

### 3. Artifact Language (`--language`)

OpenSpec generates artifacts in English by default. To use another language, pass it explicitly, e.g. `--language "Simplified Chinese"`.

### 4. Tool Targets (`--tools`)

- Default: `agents`. OpenSpec generates workflow skills into `.agents/skills/`, which is universally discoverable by modern coding agents.
- Additional tool-specific targets supported by `openspec init` can be passed as a comma-separated list.

## Progressive Installation and Multi-Machine Recovery

`init.sh` is designed with fault tolerance and self-healing mechanisms:

1. **Non-Destructive Merging**:
   - If the project already has an `AGENTS.md`, the installer appends a managed block (`<!-- copilot-workflow:begin -->` ... `<!-- copilot-workflow:end -->`), preserving existing content.
   - If the project already has a `.git/hooks/pre-commit` file, the installer backs it up as `pre-commit.backup.<timestamp>` and chains it before the workflow checks.
2. **Graceful Degraded Skipping and Remediation**:
   - If a dependency like `openspec` CLI is missing or the project is not a git repository, the installer skips the affected components and prints a clear remediation checklist at the end.
3. **Idempotent Upgrades**:
   - Installation state is tracked in `.copilot-workflow.yaml`.
   - Re-running `init.sh` after resolving missing dependencies installs the skipped components and upgrades managed files without overwriting local custom configurations.
4. **Recovery on Cloned Machines**:
   - The `.herdr/` squad directory and `.git/hooks/` are not committed to version control. When cloning the repository onto a new machine, re-run `init.sh` once to restore the `.herdr/` instance and git hooks.

Installation output example:

```text
[copilot-workflow] Target project: /path/to/target-project
[copilot-workflow] Components: squad openspec adr skills hooks
[copilot-workflow] Component squad: Herdr squad ready (.herdr/, gitignored)
[copilot-workflow] Component openspec: workspace + dual schemas ready
[copilot-workflow] Component adr: decision directory ready
[copilot-workflow] Component skills: installed per manifest openspec-git-discipline architectural-decision-records tech-doc eli5
[copilot-workflow] Component hooks: pre-commit discipline hook ready
[copilot-workflow] Manifest written to .copilot-workflow.yaml
```

## Legacy Codebase Cold-Start (Onboarding)

When `init.sh` detects existing source code in the target project, it outputs onboarding suggestions.

Start a coding agent in the main pane (which reads `AGENTS.md` and adopts the engineering workflow), then send it the following onboarding prompt:

```text
Please onboard this codebase:
1. Read the existing code and reverse-engineer the core system capabilities into initial specs (openspec/specs/<capability>/spec.md).
2. Backfill 3-5 major architectural decisions already in effect into ADRs (adr/NNNN-*.md, status: accepted, noted as ratified).
```

Expected output:
- `openspec/specs/<capability>/spec.md`: Baseline specifications describing current capabilities.
- `adr/0001-*.md` ~ `adr/0005-*.md`: Baseline architectural decisions reflecting established patterns.

## Next Steps

1. Restart your IDE or agent session to load `AGENTS.md` and skills in `.agents/skills/`.
2. Learn how to execute the OpenSpec 5-artifact pipeline and ADR rules in the [Engineering Workflow Guide (workflow.md)](./workflow.md).
3. Learn how to manage auxiliary roles and delegate asynchronous tasks in the [Squad Guide (squad-guide.md)](./squad-guide.md).
4. Browse the complete document catalog in the [Documentation Suite Index (README.md)](./README.md).
