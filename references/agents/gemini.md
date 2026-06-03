# Gemini + SpecAnchor

## Install Path

Gemini integrations vary by host tool. Install SpecAnchor into the tool-specific local skill directory, then point the tool at `SKILL.md`.

## Manual Invocation

If the host tool supports shell execution, run boot and assemble explicitly:

```bash
SPECANCHOR_SKILL_DIR=/absolute/path/to/specanchor \
  bash /absolute/path/to/specanchor/scripts/specanchor-boot.sh --format=summary
```

Then call `specanchor-assemble.sh`.

## Guidance

- Treat natural language as the user interface.
- Treat shell scripts as implementation helpers.
- Use assemble before editing code so the read plan is explicit and replayable.
- Surface missing anchors instead of guessing.

> **Boot is session-start / preflight — run it once per session.** For later edits in the same session, prefer `specanchor-assemble.sh` over re-running boot, and don't reprint already-loaded specs unless their target set or freshness changed. The Assembly Trace is the in-conversation dedup ledger (scripts hold no persistent state). See `SKILL.md` → Boot Requirement.

## Boot Activation

To ensure SpecAnchor activates automatically on every new session, choose one:

**Option A: One-shot install** (recommended)

```bash
# Standalone — write the trigger block to GEMINI.md (idempotent)
bash <skill-install-dir>/scripts/specanchor-boot-install.sh --target=gemini

# Or during init — combine init + boot install
bash <skill-install-dir>/scripts/specanchor-init.sh --install-boot=gemini
```

This writes a `<!-- specanchor:boot:start --> ... <!-- specanchor:boot:end -->` block to project `GEMINI.md` instructing the agent to load the `spec-anchor` skill before any code edit. Re-run to upgrade in place; pass `--remove` to revert. After editing `GEMINI.md`, run `/memory reload` to pick up the change in the current session.

**Option B: Manual GEMINI.md edit** (if you cannot run scripts)

Append the same block to project `GEMINI.md` by hand:

```markdown
<!-- specanchor:boot:start -->
## SpecAnchor (mandatory)

This project uses SpecAnchor (see `anchor.yaml`).
Invoke the `spec-anchor` skill before code changes, spec/context management, reviews, or process skills.

Boot is session-start / preflight — run it once per session. For later edits in the same session, prefer targeted assemble over re-running boot.

Triggers: code edits, reviews, spec/context queries, alignment, checkpoint, handoff, finding, sediment.
Not needed for: grep, find, git log, running tests, git commit/push — purely mechanical read-only operations.
<!-- specanchor:boot:end -->
```

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
