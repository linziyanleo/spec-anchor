# Cursor Walkthrough

## Install Path

Install the skill at `.cursor/skills/specanchor/`.

## First Prompt

Use `.cursor/skills/specanchor` as the project-local SpecAnchor skill.

When I request a code change, first run SpecAnchor boot and resolve the relevant anchors. Show the Assembly Trace and Spec Anchors Used before editing files.

## Expected Boot Behavior

- Run `SPECANCHOR_SKILL_DIR="$PWD/.cursor/skills/specanchor" bash "$PWD/.cursor/skills/specanchor/scripts/specanchor-boot.sh" --format=summary`
- Report the mode and Assembly Trace
- Stop and report missing anchors instead of guessing

## Resolve Before Editing

Ask Cursor to run `specanchor-resolve.sh` for the files it plans to touch and summarize the selected Global / Module / Source anchors before writing code.

## What Not To Ask

- Do not ask Cursor to invent business rules when no anchor exists.
- Do not ask Cursor to skip boot / resolve and edit files directly.

## Alpha Limitation

Resolve is deterministic-first. It matches paths and known spec locations; it is not semantic RAG.
