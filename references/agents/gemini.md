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
