# Architecture

This document explains how copilot-workflow is structured and why. It is for anyone who wants to modify the template itself or understand what installation does to a target project. For usage instructions, see [Getting Started](./getting-started.md).

## System overview

copilot-workflow is a **template repository** plus an **installer**. The installer projects the template into any target project, splitting the payload into two layers with different lifecycles:

```mermaid
flowchart LR
    subgraph Template["Template repository (this repo)"]
        initsh["init.sh"]
        agents_src["AGENTS.md<br/>(managed block source)"]
        scripts_src["scripts/pre-commit.sh"]
        regression["scripts/regression-test.sh<br/>(template-only checks)"]
        schemas["openspec/schemas/*"]
        skills_src[".agents/skills/*"]
        adr_rules["adr/README.md"]
        squad_src["squad/<br/>(protocol, roles, conf, squad.sh)"]
    end

    subgraph Target["Target project"]
        subgraph Versioned["Versioned (workflow layer)"]
            agents_tgt["AGENTS.md marker block"]
            scripts_tgt["scripts/pre-commit.sh"]
            openspec_tgt["openspec/"]
            adr_tgt["adr/"]
            skills_tgt[".agents/skills/"]
        end
        subgraph Ignored["Gitignored (machine layer)"]
            herdr_tgt[".herdr/<br/>(protocol, roles, conf, squad.sh, handoff/)"]
            hook_tgt[".git/hooks/pre-commit shim"]
        end
    end

    initsh -->|installs| Versioned
    initsh -->|installs| Ignored
    agents_src --> agents_tgt
    squad_src --> herdr_tgt
    scripts_src --> scripts_tgt
```

Design intent (see [ADR-0001](../adr/0001-workflow-first-positioning.md)):

- **Workflow layer** — versioned with the target project, applies to every collaborator, works with any coding agent, no Herdr required.
- **Machine layer** — the Herdr squad instance and the git hook shim. Restored per machine by rerunning `init.sh`; never enters version control.

## Source / instance split

Squad assets exist in two places with a strict one-way flow (see [ADR-0006](../adr/0006-squad-source-instance-split.md)):

```mermaid
flowchart LR
    src["squad/ (versioned source)<br/>AGENTS.md, roles/, squad.conf,<br/>scripts/squad.sh, skills.txt"]
    inst[".herdr/ (runtime instance, gitignored)<br/>AGENTS.md, roles/, squad.conf,<br/>scripts/squad.sh, handoff/"]
    local[".herdr/squad.local.conf<br/>(user-owned, never touched)"]

    src -->|"./init.sh (wholesale replace)"| inst
    local -.->|whole-file precedence over squad.conf| inst
```

Rules that keep this coherent:

- To change the squad, edit `squad/` source and rerun `./init.sh`; direct edits to `.herdr/` are overwritten by the next install.
- This template repository runs `./init.sh` on itself, so its own `.herdr/` instance exercises the real install path on every iteration (Dogfooding).
- `squad.local.conf` and `handoff/` are user/runtime data inside `.herdr/` that the installer never reads or writes.

## Conditional runtime

The root `AGENTS.md` managed block carries workflow discipline plus a single dispatch decision:

```mermaid
flowchart TD
    start["Coding agent reads AGENTS.md"]
    check{"HERDR_ENV=1 and<br/>.herdr/AGENTS.md exists?"}
    solo["Work solo.<br/>Full workflow applies:<br/>OpenSpec pipeline + ADR + hooks"]
    squad["Become Tech Lead.<br/>Follow .herdr/AGENTS.md:<br/>delegate to researcher / writer / worker"]

    start --> check
    check -->|no| solo
    check -->|yes| squad
```

Squad concepts (Tech Lead, roles, delegation protocol) exist only inside `.herdr/AGENTS.md`, so projects without Herdr never see them (see [Squad Guide](./squad-guide.md) for the protocol itself).

## Change pipeline and sources of truth

Large changes flow through the OpenSpec `spec-driven-with-adr` schema; two directories persist across changes (see [ADR-0002](../adr/0002-adopt-openspec-spec-driven-with-adr.md)):

```mermaid
flowchart LR
    proposal --> specs --> design --> adr --> tasks --> impl["implementation"]
    impl -->|archive| truth1["openspec/specs/<br/>(current capabilities)"]
    adr -->|accepted, immutable| truth2["adr/<br/>(current decisions)"]
    truth1 -.->|read before designing| design
    truth2 -.->|read before designing| design
```

The pre-commit hook mechanizes the two invariants (see [ADR-0004](../adr/0004-git-hooks-enforce-spec-and-adr-discipline.md)):

```mermaid
flowchart LR
    commit["git commit"] --> shim[".git/hooks/pre-commit<br/>(generated shim)"]
    shim -->|chain-calls backups first| logic["scripts/pre-commit.sh<br/>(versioned logic)"]
    logic --> c1{"tracked adr/NNNN-*.md<br/>modified or deleted?"}
    logic --> c2{"openspec validate<br/>--all --strict passes?"}
    c1 -->|yes| reject["reject commit"]
    c2 -->|no| reject
```

## Installer behavior

`init.sh` is merge-based, idempotent, and progressive (see [ADR-0003](../adr/0003-merge-based-idempotent-installer.md)):

| Property | Mechanism |
|----------|-----------|
| Merge-based | `AGENTS.md` managed only inside `<!-- copilot-workflow:begin/end -->` markers; pre-existing hooks backed up and chain-called |
| Idempotent | Managed directories are replaced wholesale; `openspec init` reruns to repair generated workflow skills; the manifest records version and managed paths |
| Progressive | Missing git fails fast; missing openspec CLI skips that component with a remediation command; missing jq/herdr only produces a notice |
| Self-install safe | When source and target paths coincide (template repo installing onto itself), managed assets are left alone and only derived artifacts (`.herdr/`) are generated |

The template-only `scripts/regression-test.sh` exercises recovery from a partial OpenSpec initialization and verifies that squad name collisions fail before creating runtime topology. The installer never copies this test harness into target projects.

## Squad topology

At runtime the squad lives inside one Herdr workspace (see [ADR-0005](../adr/0005-single-tech-lead-squad-model.md) and [ADR-0007](../adr/0007-conf-driven-squad-launcher.md)):

```mermaid
flowchart TD
    subgraph ws["Herdr workspace"]
        tl["Main pane: Tech Lead<br/>(your conversation partner)"]
        r["Tab 'researcher'"]
        w["Tab 'writer'"]
        k["Tab 'worker'"]
    end
    user["You"] --> tl
    tl -->|"herdr agent prompt (async)"| r
    tl -->|"herdr agent prompt (async)"| w
    tl -->|"herdr agent prompt (async)"| k
    r -->|"condensed report → .herdr/handoff/"| tl
    w -->|"docs/ edits + summary"| tl
    k -->|"diff + verification, line-by-line review"| tl
```

One tab per role, named after the role, created by `squad.sh` in the current workspace — no extra workspaces, no split panes. Agent names prefer the bare role name and fall back to `<project-prefix>-<role>` on cross-project collisions.

## Related documentation

- [Getting Started](./getting-started.md) — installation and recovery
- [Engineering Workflow](./workflow.md) — the OpenSpec pipeline in daily use
- [Squad Guide](./squad-guide.md) — squad operation and delegation
