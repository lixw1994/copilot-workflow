# copilot-workflow

English | [简体中文](./README.zh-CN.md)

Install an engineering-grade AI collaboration workflow into any project with one command: an OpenSpec spec-driven pipeline (proposal → specs → design → adr → tasks) at the core, plus ADR decision records and a pre-commit discipline hook. Optional enhancement: an AI squad built on Herdr (a terminal multiplexer), installed under `.herdr/` without touching your project's version control.

## Design

**The workflow is the product; the squad is an enhancement.**

- **Engineering workflow** (intrusive, versioned with your project): large changes go through the OpenSpec pipeline; specs and ADRs are persistent sources of truth across changes; small changes go straight in. The pre-commit hook enforces spec validation and "accepted ADRs are immutable". Any coding agent that reads `AGENTS.md` can follow it — no Herdr required.
- **Herdr squad** (machine-level environment, entire directory gitignored): a single Tech Lead runs everything and pulls up three helper roles on demand. Active only when `HERDR_ENV=1` and `.herdr/` exists; without Herdr, the agent works solo and the main workflow is unaffected.

```
You (the user)
 └── Tech Lead (main pane, your direct conversation partner)
      ├── researcher   external research and investigation (on demand)
      ├── writer       docs/ documentation (on demand)
      └── worker       simple offloaded chores (rarely used)
```

Squad philosophy: **Dogfooding by default**. The Tech Lead is an engineer of world-class ability and pragmatic style — writing the unit tests that matter without letting testing overshadow the code itself, and holding that quality is built in by engineering rather than bolted on by QA. It eats its own dog food, personally owning architecture, development, and maintenance. Helper roles are invoked only in specific scenarios, and everything they produce is reviewed by the Tech Lead.

## Repository layout

```
init.sh              One-command installer (puts everything below into any project)
AGENTS.md            Workflow discipline + conditional squad entry (auto-loaded by coding agents)
scripts/
  pre-commit.sh      Discipline hook logic (spec validation + ADR immutability, versioned with the project)
openspec/            OpenSpec workspace (specs = current capabilities, changes = work in progress)
  schemas/spec-driven-with-adr/   Default workflow schema (versioned in the repo)
  schemas/minimalist/             Lightweight schema for exploratory spikes (specs → tasks)
adr/                 Architecture decision records; persistent across changes, immutable once accepted
docs/                Project documentation (the writer role's only write scope)
.agents/skills/      Schema skills + squad-level skills + OpenSpec workflow skills
squad/               Squad source (role prompts, collaboration protocol, config template, lifecycle script)
                     — mapped to the target project's .herdr/ at install time; this directory itself
                     is never copied into target projects
.herdr/              Squad runtime instance (gitignored; this repo generates it by running init.sh on
                     itself for self-iteration testing)
  AGENTS.md          Squad collaboration protocol
  roles/             Prompts for the four roles
  squad.conf         Squad config (copy to squad.local.conf for local customization)
  scripts/squad.sh   Squad lifecycle: up / down / restart / status / print
  handoff/           Member handoff artifacts (research reports and other intermediates)
```

Source and instance are separate: to change the squad, edit the `squad/` source and rerun `./init.sh` to refresh the `.herdr/` instance; editing `.herdr/` directly gets overwritten on the next install.

## One-command install into your project

Run in the target project root (works for new and existing projects):

```bash
curl -fsSL https://raw.githubusercontent.com/lixw1994/copilot-workflow/main/init.sh | bash
# Or after cloning this repo:  cd your-project && /path/to/copilot-workflow/init.sh
```

Features:

- **Merge-based**: an existing `AGENTS.md` only gets a managed marker block appended; an existing git hook is backed up and chain-called — zero destruction of user content
- **Idempotent**: rerunning upgrades managed content; the `.copilot-workflow.yaml` manifest records version and managed paths
- **Selectable components**: `--with squad,openspec,adr,skills,hooks` (all by default); if the openspec CLI is missing, that component is skipped with instructions
- **Non-intrusive**: the squad goes into `.herdr/` and is gitignored automatically; your repository only gains the workflow itself
- **Language preference**: OpenSpec artifacts default to English; pass `--language "Simplified Chinese"` (or any language) to change
- **Cold start for existing code**: after installing, prints onboarding guidance (derive initial specs from code, backfill key decisions as ADRs)

Note: neither `.herdr/` nor git hooks are versioned. On a freshly cloned machine, rerun `init.sh` once to restore them.

## Usage

### Workflow (any coding agent, no Herdr required)

Start large changes in natural language — the request triggers the matching `openspec-*` skill, which executes the pipeline (`AGENTS.md` only defines the discipline of when a change must go through it):

```
"Start an OpenSpec change: <your idea>"   Creates the change and produces proposal / specs / design / adr / tasks
"Implement the tasks"                     Maps to the openspec-apply-change skill
"Archive this change"                     Merges specs into openspec/specs/; ADRs stay in adr/
```

The skills live in `.agents/skills/openspec-*` and work across agents.

### Squad (Herdr environment)

1. Open the project in Herdr and start your coding agent in the main pane — it reads the conditional entry in `AGENTS.md`, loads `.herdr/AGENTS.md`, and becomes the Tech Lead.
2. Assign work normally. It completes tasks solo by default; when external research, documentation, or simple chores come up, it pulls up the right member and delegates.
3. Manual operation also works:

```bash
.herdr/scripts/squad.sh up              # Launch the whole squad (per .herdr/squad.conf)
.herdr/scripts/squad.sh up researcher   # Or a single role
herdr agent prompt researcher "Research breaking changes in library X's latest release; report to .herdr/handoff/"
# Work in parallel after delegating (async); collect results later:
herdr agent get researcher
herdr agent read researcher --source recent-unwrapped --lines 120
.herdr/scripts/squad.sh down            # Stop the squad when done; restart to reload; status to check
```

Default model assignment (`.herdr/squad.conf`): researcher uses grok (grok-4.6 xhigh), writer uses pi (gemini-3.7-flash), worker uses codex (gpt-5.6-sol). To change, copy it to `.herdr/squad.local.conf` and edit (the local file takes full precedence and never gets overwritten by upgrades).

## Dependencies

- git (required)
- OpenSpec CLI: `npm install -g @fission-ai/openspec@latest` (≥ 1.3; this project initializes with `openspec init --tools agents`)
- For the squad enhancement: Herdr (`HERDR_ENV=1`), `jq`, and a Herdr-supported coding agent (default kind `codex`, override with `HERDR_AGENT_KIND`)

## Role permission matrix

| Role | Read code | Write code/architecture | Write openspec/ & adr/ | Write docs/ | Write .herdr/handoff/ | Internet research |
|------|:---------:|:-----------------------:|:----------------------:|:-----------:|:---------------------:|:-----------------:|
| tech-lead | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| researcher | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| writer | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ |
| worker | ✓ | task scope only | ✗ | ✗ | ✗ | ✗ |
