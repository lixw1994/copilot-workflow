# Squad Guide

This document is the operational guide for optional Herdr squad collaboration in copilot-workflow. It guides you through managing auxiliary roles with lifecycle scripts, delegating asynchronous tasks via Herdr, and customizing squad configurations.

## Team Structure and Role Responsibilities

copilot-workflow uses a Tech Lead-centric collaboration model. The squad is installed as an optional enhancement in the `.herdr/` directory (which is fully ignored by `.gitignore` and does not pollute the project repository):

```
You (User)
 └── Tech Lead (Main pane, direct conversation partner)
      ├── researcher   External documentation retrieval and research (on-demand)
      ├── writer       Documentation authoring and maintenance in docs/ (on-demand)
      └── worker       Mechanical bounded task offloading (rarely launched)
```

### 1. Role Division and Write Scope

| Role | Agent Identifier | Core Responsibility | Write Scope |
|------|------------------|---------------------|-------------|
| **Tech Lead** | Agent in main pane | Architecture design, core coding, maintenance, quality gate | Entire repository |
| **Researcher** | `researcher` | External documentation, technical comparisons, issue research | Strictly `.herdr/handoff/` |
| **Writer** | `writer` | User guides, architecture overviews, FAQ documentation | Strictly `docs/` |
| **Worker** | `worker` | Mechanical refactoring, typo fixes, simple unit tests | Strictly task-specified files |

### 2. Permission Matrix

| Role | Read Code | Write Code / Architecture | Write openspec/ and adr/ | Write docs/ | Write .herdr/handoff/ | Web Research |
|:-----|:---------:|:-------------------------:|:-----------------------:|:----------:|:--------------------:|:------------:|
| **Tech Lead** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Researcher** | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| **Writer** | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ |
| **Worker** | ✓ | Specified scope only | ✗ | ✗ | ✗ | ✗ |

> **Note**: `openspec/` and `adr/` contain the system specification and architectural truth. They must be authored exclusively by the Tech Lead. Auxiliary roles (including Writer) must not write to these directories.

### 3. Value of Context Isolation

The primary value of delegating to auxiliary roles is **context isolation**: processing voluminous documentation or iterating through text formatting happens entirely inside the auxiliary agent's context window. The Tech Lead receives only condensed summaries, preserving its context window for core architecture and implementation.

## Managing Squad Lifecycle (`.herdr/scripts/squad.sh`)

Squad member lifecycles are managed through the `.herdr/scripts/squad.sh` script.

> **Source vs. Instance**: In the template repository, squad templates live under `squad/`. Once installed in a target project, the runtime instance lives in `.herdr/`. In your target project, execute `.herdr/scripts/squad.sh`.

### 1. Five Lifecycle Subcommands

#### Inspect the Launch Plan (`print`)

Review the parsed launch configuration without requiring a running Herdr environment:

```bash
.herdr/scripts/squad.sh print
```

Example output:

```text
Config file: /path/to/project/.herdr/squad.conf
Launch plan (role / kind / args):
  researcher   grok     --model grok-4.6 --reasoning-effort xhigh
  writer       pi       --provider google-vertex --model gemini-3.7-flash
  worker       codex    --model gpt-5.6-sol -c model_reasoning_effort=high
```

#### Launch Squad Members (`up`)

Launch all configured roles or a specific member:

```bash
# Launch all squad members
.herdr/scripts/squad.sh up

# Launch a single role
.herdr/scripts/squad.sh up researcher

# Launch a single role with a temporary agent kind override
.herdr/scripts/squad.sh up worker codex
```

Example output:

```text
[squad] === Launching squad from /path/to/project/.herdr/squad.conf ===
[squad] Ready: researcher → researcher (kind=grok, args: --model grok-4.6 --reasoning-effort xhigh)
[squad] Ready: writer → writer (kind=pi, args: --provider google-vertex --model gemini-3.7-flash)
[squad] Ready: worker → worker (kind=codex, args: --model gpt-5.6-sol -c model_reasoning_effort=high)

Live agent names (use these names when delegating tasks):
- researcher → researcher
- writer → writer
- worker → worker
```

#### View Member Status (`status`)

```bash
.herdr/scripts/squad.sh status
```

Example output:

```text
Config file: /path/to/project/.herdr/squad.conf
Squad status:
  researcher   running → researcher (kind=grok, args: --model grok-4.6 --reasoning-effort xhigh)
  writer       running → writer (kind=pi, args: --provider google-vertex --model gemini-3.7-flash)
  worker       stopped (kind=codex, args: --model gpt-5.6-sol -c model_reasoning_effort=high)
```

#### Stop Squad Members (`down`)

Close the Herdr tabs associated with squad members, stopping the agents safely:

```bash
# Stop all squad members
.herdr/scripts/squad.sh down

# Stop a specific role
.herdr/scripts/squad.sh down writer
```

#### Restart Squad Members (`restart`)

```bash
# Restart all squad members
.herdr/scripts/squad.sh restart

# Restart a specific role
.herdr/scripts/squad.sh restart researcher
```

### 2. Agent Naming and Conflict Fallback

- **Tab Isolation**: Each role occupies a dedicated tab named after the role in the current Herdr workspace.
- **Session Name Collision Handling**: Herdr agent names must be globally unique across a session. If a bare role name (such as `researcher`) is already occupied by another project, the script automatically falls back to `<project-prefix>-<role>` (for example, `myproj-researcher`).
- **Use Actual Agent Names**: When prompting an agent, always use the live agent name reported by `squad.sh up` or `squad.sh status`.

## Herdr Task Delegation Protocol

Prerequisite: The current pane must be managed by Herdr (`HERDR_ENV=1`), and `.herdr/AGENTS.md` must exist.

### 1. Delegating Tasks (Default Asynchronous)

The Tech Lead delegates tasks using the following command:

```bash
herdr agent prompt <actual-agent-name> "<self-contained-task-description>"
```

Every delegated prompt must include four essential elements:
1. **Background**: Context and motivation for the task.
2. **Specific Requirements**: Concrete instructions and constraints.
3. **Output Format**: Brief response, file in `.herdr/handoff/`, or file in `docs/`.
4. **Acceptance Criteria**: Verifiable conditions indicating successful completion.

Task prompt example:

```bash
herdr agent prompt researcher "Background: Evaluating Redis client upgrade. Requirements: Investigate breaking changes from ioredis 4.x to 5.x, noting major API differences and migration gotchas. Output: Write a structured research report to .herdr/handoff/2025-08-25-ioredis-v5-upgrade.md. Acceptance Criteria: Report includes changes list, risk assessment, and source links."
```

> **Asynchronous Rule**: Return immediately to your primary work after prompting. Add `--wait --timeout 600000` only when the next step is strictly blocked and no parallel work is available.

### 2. Collecting Results

```bash
# Check agent lifecycle status (idle / done / working / blocked)
herdr agent get researcher

# Read the latest output from the agent
herdr agent read researcher --source recent-unwrapped --lines 120
```

- When responses are long or truncated by alternate screen buffers, instruct the agent to write the full result to `.herdr/handoff/` (which is gitignored and does not pollute version history).

### 3. Handling Abnormal States

- **State is `blocked`**: Run `herdr agent read <actual-agent-name>` to see what the agent is asking, then reply using `herdr agent prompt` or `herdr agent send-keys`.
- **Prolonged `working`**: Inspect output with `herdr agent read <actual-agent-name>` before deciding whether to interrupt.

### 4. Review and Sign-Off

All auxiliary outputs must be reviewed by the Tech Lead:
- Verify researcher reports for source links and concrete findings.
- Verify writer documentation for clarity and accurate links.
- Review worker code modifications line-by-line and run tests.

## Customizing Squad Configuration (`.herdr/squad.conf`)

Squad configuration maps each role to an agent kind and runtime parameters.

### 1. Configuration Syntax

Each non-comment line follows: `<role> <kind> [args...]`

```conf
# Default configuration
researcher   grok    --model grok-4.6 --reasoning-effort xhigh
writer       pi      --provider google-vertex --model gemini-3.7-flash
worker       codex   --model gpt-5.6-sol -c model_reasoning_effort=high
```

- Comment out or delete a line to disable that role.
- `kind` specifies an agent kind supported by the installed Herdr version.
- `args` contains CLI arguments passed directly to the agent binary.

### 2. Local Private Overrides (`.herdr/squad.local.conf`)

- `.herdr/squad.conf` is managed by the installer and will be updated during upgrades.
- **To customize**: Copy `.herdr/squad.conf` to `.herdr/squad.local.conf` and adjust settings.
- `.herdr/squad.local.conf` takes full precedence and is never overwritten during updates.

## Related Documentation

- [Getting Started (getting-started.md)](./getting-started.md): Installation prerequisites and setup steps.
- [Engineering Workflow (workflow.md)](./workflow.md): OpenSpec change pipeline and ADR discipline.
- [Documentation Suite Index (README.md)](./README.md): Document catalog and quick navigation.
