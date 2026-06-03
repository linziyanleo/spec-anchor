# Cursor + SpecAnchor

## Install Path

```text
.cursor/skills/specanchor/
```

## Manual Invocation

```bash
SPECANCHOR_SKILL_DIR=.cursor/skills/specanchor \
  bash .cursor/skills/specanchor/scripts/specanchor-boot.sh --format=summary
```

## Recommended Prompt

Use `.cursor/skills/specanchor` as the project-local SpecAnchor skill.

When I request a code change:
1. Run SpecAnchor boot.
2. Choose `⚡ lightweight` or `standard Task Spec workflow`.
3. Run `specanchor-assemble.sh` for the relevant files and intent.
4. Show the Assembly Trace and anchors used before editing files.

> **Boot is session-start / preflight — run it once per session.** For later edits in the same session, prefer `specanchor-assemble.sh` over re-running boot, and don't reprint already-loaded specs unless their target set or freshness changed. The Assembly Trace is the in-conversation dedup ledger (scripts hold no persistent state). See `SKILL.md` → Boot Requirement.

## Walkthrough

For a known module path:
1. Boot.
2. Assemble with the concrete file path.
3. Read the listed specs.
4. Apply the edit and report drift or missing anchors.

## Boot Activation

To ensure SpecAnchor activates automatically on every new session, choose one:

**Option A: One-shot install** (recommended)

```bash
# Standalone — write the trigger block to .cursor/rules/specanchor.mdc (idempotent, auto-creates dir)
bash <skill-install-dir>/scripts/specanchor-boot-install.sh --target=cursor

# Or during init — combine init + boot install
bash <skill-install-dir>/scripts/specanchor-init.sh --install-boot=cursor
```

This writes a `<!-- specanchor:boot:start --> ... <!-- specanchor:boot:end -->` block to project `.cursor/rules/specanchor.mdc` instructing the agent to load the `spec-anchor` skill before any code edit. Re-run to upgrade in place; pass `--remove` to revert.

**Option B: Manual rule file edit** (if you cannot run scripts)

Create `.cursor/rules/specanchor.mdc` and paste:

```markdown
---
description: SpecAnchor boot — load specs before any code change
globs:
alwaysApply: true
---

<!-- specanchor:boot:start -->
## SpecAnchor (mandatory)

This project uses SpecAnchor (see `anchor.yaml`).
Invoke the `spec-anchor` skill before code changes, spec/context management, reviews, or process skills.

Boot is session-start / preflight — run it once per session. For later edits in the same session, prefer targeted assemble over re-running boot.

Triggers: code edits, reviews, spec/context queries, alignment, checkpoint, handoff, finding, sediment.
Not needed for: grep, find, git log, running tests, git commit/push — purely mechanical read-only operations.
<!-- specanchor:boot:end -->
```

**Option C: AGENTS.md fallback** — same content, but in `AGENTS.md` instead, if your Cursor setup reads that file.

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
