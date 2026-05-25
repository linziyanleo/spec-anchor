# Codex + SpecAnchor

## Install Path

Common project-local path:

```text
.codex/skills/specanchor/
```

Codex can also consume another tool-specific skill directory if the project wires it explicitly.

## Manual Invocation

```bash
SPECANCHOR_SKILL_DIR=.codex/skills/specanchor \
  bash .codex/skills/specanchor/scripts/specanchor-boot.sh --format=summary
```

## Recommended Prompt

Use the SpecAnchor skill installed at `.codex/skills/specanchor`.

Before making changes:
1. Run SpecAnchor boot.
2. Choose `⚡ lightweight` or `standard Task Spec workflow`.
3. Run `specanchor-assemble.sh` for the files you plan to edit.
4. Read the files in `files_to_read`.
5. Report the anchors used.
6. Only then propose or apply code changes.

Do not invent business rules if missing coverage exists.

## Walkthrough

For a multi-file change:
1. Boot.
2. Assemble with file paths and intent.
3. If assemble reports missing coverage, stop and create a Task Spec.
4. Otherwise read the listed specs, edit code, and run verification.

## Boot Activation

To ensure SpecAnchor activates automatically on every new session, choose one:

**Option A: One-shot install** (recommended)

```bash
# Standalone — write the trigger block to AGENTS.md (idempotent)
bash <skill-install-dir>/scripts/specanchor-boot-install.sh --target=codex

# Or during init — combine init + boot install
bash <skill-install-dir>/scripts/specanchor-init.sh --install-boot=codex
```

This writes a `<!-- specanchor:boot:start --> ... <!-- specanchor:boot:end -->` block to project `AGENTS.md` instructing the agent to load the `spec-anchor` skill before any code edit. Re-run to upgrade in place; pass `--remove` to revert.

**Option B: SessionStart hook**

```yaml
# codex hooks configuration
hooks:
  session_start:
    - command: "SPECANCHOR_SKILL_DIR=.codex/skills/specanchor bash .codex/skills/specanchor/scripts/specanchor-boot.sh --format=summary"
```

**Option C: Manual AGENTS.md edit** (if you cannot run scripts)

Append the same block to project `AGENTS.md` by hand:

```markdown
<!-- specanchor:boot:start -->
## SpecAnchor

This project uses SpecAnchor (see `anchor.yaml`).
Before writing or editing code, you MUST:
1. Invoke the `spec-anchor` skill to load it
2. Run the boot script the skill prints
3. Follow the Spec Landscape it returns

Triggers: any mention of spec, 规范, 对齐, alignment, checkpoint, handoff, coverage, or any edit in this repo.
<!-- specanchor:boot:end -->
```

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
