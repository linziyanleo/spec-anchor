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
