# Claude Code + SpecAnchor

## Install Path

Default Claude Code auto-discovery path:

```text
.claude/skills/specanchor/
```

Generic manual layout, if your tooling points there explicitly:

```text
.agents/skills/specanchor/
```

## Manual Invocation

If Claude Code does not run scripts automatically, call:

```bash
SPECANCHOR_SKILL_DIR=.claude/skills/specanchor \
  bash .claude/skills/specanchor/scripts/specanchor-boot.sh --format=summary
```

Then use `specanchor-assemble.sh` before editing.

## Recommended Prompt

Use the SpecAnchor skill installed at `.claude/skills/specanchor`.

Before writing code:
1. Read `SKILL.md`.
2. Run the boot script.
3. Choose `⚡ lightweight` or `standard Task Spec workflow`.
4. Use `specanchor-assemble.sh` for the target files and intent.
5. Read the selected specs.
6. Report unresolved or missing anchors before implementation.

> **Boot is session-start / preflight — run it once per session.** For later edits in the same session, prefer `specanchor-assemble.sh` over re-running boot, and don't reprint already-loaded specs unless their target set or freshness changed. The Assembly Trace is the in-conversation dedup ledger (scripts hold no persistent state). See `SKILL.md` → Boot Requirement.

## Walkthrough

For a focused shell-script fix:
1. Boot the project.
2. Run assemble with the shell file paths and intent.
3. Read the listed Global / Module docs.
4. Apply the code change.
5. Run tests, then doctor / validate if specs changed.

## Boot Activation

To ensure SpecAnchor activates automatically on every new session, choose one:

**Option A: One-shot install** (recommended)

```bash
# Standalone — write the trigger block to CLAUDE.md (idempotent)
bash <skill-install-dir>/scripts/specanchor-boot-install.sh --target=claude

# Or during init — combine init + boot install in one go
bash <skill-install-dir>/scripts/specanchor-init.sh --install-boot=claude
```

This writes a `<!-- specanchor:boot:start --> ... <!-- specanchor:boot:end -->` block to project `CLAUDE.md` instructing the agent to invoke the `spec-anchor` skill before any code edit. Re-run to upgrade in place; pass `--remove` to revert. Use `--target=auto` to detect the platform from project markers (`.claude/` / `AGENTS.md` / `GEMINI.md` / `.cursor/`).

**Option B: SessionStart hook**

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "SPECANCHOR_SKILL_DIR=.claude/skills/specanchor bash .claude/skills/specanchor/scripts/specanchor-boot.sh --format=summary"
          }
        ]
      }
    ]
  }
}
```

**Option C: Manual CLAUDE.md edit** (if you cannot run scripts)

Append the same block to project `CLAUDE.md` by hand:

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
