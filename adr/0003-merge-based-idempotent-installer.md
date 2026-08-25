# ADR-0003: Merge-based installer with marker blocks and a manifest, fully idempotent

- Status: accepted
- Date: 2026-08-25
- Supersedes: —

## Context

The template must install into existing projects, which very likely already have their own `AGENTS.md`, git hooks, and so on. Overwrite-style installation would destroy user content; a separate file (e.g. `AGENTS.copilot-workflow.md`) would not be auto-loaded by agents. Installed projects also need to receive future template updates.

## Decision

The installer is merge-based and idempotent:

1. `AGENTS.md` gets a managed section appended inside `<!-- copilot-workflow:begin/end -->` markers; reruns replace only the content inside the block — everything outside belongs to the user
2. Whole-directory assets (`openspec/schemas/*`, `.agents/skills/*`, the managed parts of `.herdr/`) are managed as units and replaced wholesale on rerun
3. The `.copilot-workflow.yaml` manifest records template version (source commit), install time, installed components, and managed paths; rerunning upgrades in place
4. Dual-mode install source: if the script's own directory is the template repo, use local files; otherwise shallow-clone the remote repo into a temp directory (`COPILOT_WORKFLOW_REPO` overrides the address)
5. Progressive: a missing git fails fast with install guidance (hard requirement); missing optional dependencies such as the openspec CLI skip the affected component, record a precise remediation command, and are summarized at the end — rerun after fixing the environment to fill the gap

## Consequences

- Positive: zero-destruction onboarding for existing projects; upgrading = rerunning one command; `curl | bash`, clone-and-run, and in-repo self-testing share a single script
- Negative: user edits inside managed paths are lost on rerun (customize outside managed paths); a manually broken marker block requires manual repair (the script detects unpaired markers and aborts)
- Constraints: every future installer behavior change must preserve the promise that content outside the block and user files are never touched
