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

To ensure SpecAnchor boots automatically, add a boot instruction to the project's `GEMINI.md`.

Add to project `GEMINI.md`:

```markdown
## SpecAnchor Boot
At session start, run:
SPECANCHOR_SKILL_DIR=<skill-install-dir> bash <skill-install-dir>/scripts/specanchor-boot.sh --format=summary

Then read SKILL.md and follow the SpecAnchor workflow.
Before editing code, run specanchor-assemble.sh for the target files and intent.
```

Replace `<skill-install-dir>` with the actual skill installation path. After editing `GEMINI.md`, run `/memory reload` to pick up the change in the current session.

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
