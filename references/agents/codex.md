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

> **Boot is session-start / preflight — run it once per session.** For later edits in the same session, prefer `specanchor-assemble.sh` over re-running boot, and don't reprint already-loaded specs unless their target set or freshness changed. The Assembly Trace is the in-conversation dedup ledger (scripts hold no persistent state). See `SKILL.md` → Boot Requirement.

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
## SpecAnchor (mandatory)

This project uses SpecAnchor (see `anchor.yaml`).
Invoke the `spec-anchor` skill before code changes, spec/context management, reviews, or process skills.

Boot is session-start / preflight — run it once per session. For later edits in the same session, prefer targeted assemble over re-running boot, and don't reprint already-loaded specs unless their target set or freshness changed.

Do NOT skip because "it's a small change" — specs contain constraints not visible in code alone.

Triggers: code edits, reviews, spec/context queries, 规范, 对齐, alignment, checkpoint, handoff, coverage, finding, sediment.
<!-- specanchor:boot:end -->
```

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
