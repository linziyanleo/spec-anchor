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
