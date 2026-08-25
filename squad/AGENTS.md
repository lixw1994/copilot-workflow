# Squad Collaboration Protocol (.herdr/AGENTS.md)

This file is installed into `.herdr/` by copilot-workflow and defines how the Herdr squad collaborates. Precondition: the current pane is managed by Herdr (`HERDR_ENV=1`).

The agent running in this repository's main pane is the **Tech Lead**. Its role definition is `.herdr/roles/tech-lead.md` — read it first and follow it.

## Squad members

| Role | Agent name | Responsibility | Write access |
|------|-----------|----------------|--------------|
| Tech Lead | (you, in the main pane) | Architecture, development, maintenance, quality gate | Entire repository |
| Researcher | `researcher` | External research and investigation | `.herdr/handoff/` only |
| Writer | `writer` | Documentation writing and editing | `docs/` only |
| Worker | `worker` | Simple, well-defined, verifiable chores | Task-specified scope; output must be reviewed |

## Collaboration protocol

### 1. Squad lifecycle (idempotent)

```bash
.herdr/scripts/squad.sh up                 # Launch all roles per config
.herdr/scripts/squad.sh up researcher      # Single role (or writer / worker)
.herdr/scripts/squad.sh down [role]        # Stop the squad / one role (closes its tab)
.herdr/scripts/squad.sh restart [role]     # Restart (apply config changes / recover a stuck agent)
.herdr/scripts/squad.sh status             # Liveness and actual agent name per role
.herdr/scripts/squad.sh print              # Print the launch plan, self-check config (no Herdr needed)
```

Each member occupies one tab named after its role in the current workspace; a live agent with the same name is reused. Each role's agent kind and model parameters are configured in `.herdr/squad.conf` (copy to `.herdr/squad.local.conf` for local customization; the local file takes full precedence).

**The actual agent name is whatever the script prints**: when a bare role name is taken by another project, it falls back to `<project-prefix>-<role>` (e.g. `myproj-researcher`). Both `up` and `status` list each role's current actual name — use that name in subsequent `herdr agent prompt` commands.

### 2. Delegating tasks (async by default)

```bash
herdr agent prompt <agent-name> "<task description>"
```

After delegating, **return to your own work immediately** — do not idle. Task descriptions must be self-contained with four elements: **context, concrete requirements, expected output format, acceptance criteria**. The recipient should be able to start without asking follow-up questions.

Only add `--wait --timeout 600000` when your next step is genuinely blocked on the result and you have nothing else to advance.

### 3. Collecting results

```bash
herdr agent get <agent-name>      # Check status first: idle / done means finished
herdr agent read <agent-name> --source recent-unwrapped --lines 120
```

If a reply is truncated (the agent runs on an alternate screen), ask the member to write the full result into `.herdr/handoff/` and read it from there (the whole `.herdr/` is gitignored, so intermediates never enter version control). Require members to deliver condensed conclusions only — never raw dumps. A core value of delegation is isolating bulky intermediate content in the other agent's context window.

### 4. Handling abnormal states

```bash
herdr agent get <agent-name>     # Inspect lifecycle state
```

- `blocked`: `agent read` first to see what it is asking, then respond via `agent prompt` or `agent send-keys`
- Long `working`: do not interrupt blindly; read the output to judge progress

### 5. Wrap-up

Member output counts as done only after the Tech Lead personally reviews it; review worker code changes line by line. After all tasks finish, panes may be kept for reuse — never close panes you did not create.

## Delegation discipline

- Do it yourself by default. researcher is only for external information; writer only for `docs/`; worker only for simple chores and usually disabled.
- Complex problems, architecture problems, and anything needing multi-round clarification are never outsourced.
- **Artifact ownership**: `openspec/` and `adr/` are written by the Tech Lead personally; the writer must not touch them.
