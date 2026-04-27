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

## Walkthrough

For a known module path:
1. Boot.
2. Assemble with the concrete file path.
3. Read the listed specs.
4. Apply the edit and report drift or missing anchors.

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
