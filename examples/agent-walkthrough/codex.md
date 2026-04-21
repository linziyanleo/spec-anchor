# Codex Walkthrough

## Install Path

Install the skill at `.cursor/skills/specanchor/` or another project-local skill directory that your Codex setup can read.

## First Prompt

Use the SpecAnchor skill installed at `.cursor/skills/specanchor`.

Before making changes:
1. Run SpecAnchor boot.
2. Resolve anchors for the files you plan to edit.
3. Read the relevant Global / Module / Task specs or external sources.
4. Report the anchors used.
5. Only then propose or apply code changes.

Do not invent business rules if no anchor exists.

## Expected Boot Behavior

- Codex reports `SpecAnchor Boot [...]` with mode and Assembly Trace.
- Codex lists the anchors it will use before editing.
- If anchors are missing, Codex stops and asks for direction.

## Resolve Before Editing

Have Codex run `specanchor-resolve.sh --files="<targets>" --intent="<change>" --format=json` and summarize the returned anchors.

## What Not To Ask

- Do not ask Codex to bypass the governance step.
- Do not ask Codex to treat `resolve` as semantic search.

## Alpha Limitation

The examples are intentionally dependency-free. They prove installation and anchor resolution, not application runtime behavior.
