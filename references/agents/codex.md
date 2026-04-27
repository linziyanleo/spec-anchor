# Codex + SpecAnchor

## Install Path

Common project-local path:

```text
.cursor/skills/specanchor/
```

Codex can also consume another tool-specific skill directory if the project wires it explicitly.

## Manual Invocation

```bash
SPECANCHOR_SKILL_DIR=.cursor/skills/specanchor \
  bash .cursor/skills/specanchor/scripts/specanchor-boot.sh --format=summary
```

## Recommended Prompt

Use the SpecAnchor skill installed at `.cursor/skills/specanchor`.

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

## Full Agent Loop

For the complete seven-step loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
