# squad-launch Specification

## Purpose

Squad lifecycle management: launch, stop, restart, and inspect a multi-role AI squad from configuration, one command each, inside a Herdr environment. The script runs from the installed instance at `.herdr/scripts/squad.sh` (source lives in the template repository under `squad/scripts/`).

## Requirements

### Requirement: Launch the whole squad with one command

`.herdr/scripts/squad.sh up` without a role argument SHALL launch every configured role: each role gets one tab named after it in the current workspace, running an agent of the configured kind, with the role definition injected (pointing to `.herdr/roles/<role>.md`); finally the script prints each role's actual agent name.

#### Scenario: Full squad launch

- **WHEN** `squad.sh up` runs inside a Herdr-managed pane with 3 roles configured
- **THEN** the current workspace gains 3 tabs named after the roles, each running an agent of the configured kind with the role definition injected; the script prints 3 lines of "role → actual agent name" and exits 0

#### Scenario: Pane not ready

- **WHEN** `herdr agent start` returns an `agent_pane_busy` error
- **THEN** the script retries at 1-second intervals (up to 10 attempts), continuing once ready; past the limit it reports that role as failed and proceeds with the remaining roles

### Requirement: Config-driven agent kind and parameters per role

Each role's agent kind and native parameters SHALL come from `.herdr/squad.conf` (one line per role: `<role> <kind> [args...]`; `#` comments and blank lines ignored). When `.herdr/squad.local.conf` exists it MUST take whole-file precedence.

#### Scenario: Different models per role

- **WHEN** the config contains `researcher grok --model grok-4.6` and `worker codex`
- **THEN** researcher starts with kind=grok carrying the native `--model grok-4.6` argument, and worker starts with kind=codex

#### Scenario: Local override

- **WHEN** `.herdr/squad.local.conf` exists
- **THEN** the script reads only the local file and `.herdr/squad.conf` is ignored

#### Scenario: Config line references an unknown role

- **WHEN** a configured role has no corresponding `<role>.md` under `.herdr/roles/`
- **THEN** the script errors out citing the line number and role name, with a non-zero exit code

### Requirement: Agent name collision handling

Herdr agent names are globally unique within a session. The script SHALL prefer the bare role name; when taken by another project, it falls back to `<sanitized-project-dir-prefix>-<role>` (matching `^[a-z][a-z0-9_-]{0,31}$`) and lists the actual name in its output. A live agent of the same name belonging to this workspace is reused directly.

#### Scenario: Bare name taken by another project

- **WHEN** the session already has an agent named `researcher` from another project and this project's prefix is `myproj`
- **THEN** this project's researcher starts as `myproj-researcher` and the script output shows the actual name

#### Scenario: Bare and prefixed names both taken

- **WHEN** both `researcher` and `myproj-researcher` are live in other workspaces
- **THEN** launching this project's researcher fails before creating a tab, never calls `herdr agent start` with an empty name, and exits non-zero

#### Scenario: Rerun is idempotent

- **WHEN** the script runs again while the target-named agent is already alive in this workspace
- **THEN** the agent is reused, no duplicate tab is created, and the exit code is 0

### Requirement: Single-role mode

`squad.sh up <role> [kind]` SHALL launch only the specified role; when the kind argument is omitted it reads the config, and when the config omits it too it uses `HERDR_AGENT_KIND` (finally defaulting to `codex`).

#### Scenario: Launch researcher alone

- **WHEN** `squad.sh up researcher` runs
- **THEN** only researcher is launched; other roles are unaffected

### Requirement: Launch plan preview

`squad.sh print` SHALL parse the config and print the launch plan (roles, kinds, arguments, and which config file will be used) in any environment, including non-Herdr, executing no Herdr operations.

#### Scenario: Config self-check outside Herdr

- **WHEN** `squad.sh print` runs in a terminal without `HERDR_ENV` set
- **THEN** it outputs the config file path and each role's launch plan, exiting 0

### Requirement: Stop the squad or a single role

`squad.sh down [role]` SHALL stop the specified role (default: all configured roles): close that role's role-named tab in the current workspace, whereupon the agent exits and its name is released. It SHALL close only tabs named after configured roles and never touch other tabs.

#### Scenario: Stop the whole squad

- **WHEN** `squad.sh down` runs while the whole squad is alive
- **THEN** all role tabs close, the corresponding agents disappear from `herdr agent list`, and the exit code is 0

#### Scenario: Stop a role that is not running

- **WHEN** `squad.sh down <role>` targets a role that is not running
- **THEN** it reports the role as not running, does not error, and exits 0

### Requirement: Restart the squad or a single role

`squad.sh restart [role]` SHALL be equivalent to `down` then `up` over the same role set, used to apply new configuration or recover a stuck agent.

#### Scenario: Restart a single role after a config change

- **WHEN** `squad.sh restart researcher` runs after changing researcher's model in `.herdr/squad.local.conf`
- **THEN** researcher's old agent is stopped and a new agent starts with the new configuration and a fresh role injection

### Requirement: Squad status view

`squad.sh status` SHALL list every configured role's kind, arguments, liveness, and actual agent name.

#### Scenario: Partially alive

- **WHEN** `squad.sh status` runs while only researcher of the 3 configured roles is alive
- **THEN** researcher shows alive with its actual agent name, the other roles show not running, and the exit code is 0
