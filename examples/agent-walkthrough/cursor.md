# Cursor Walkthrough

## Install Path

Install the skill at `.cursor/skills/specanchor/`.

## First Prompt

Use `.cursor/skills/specanchor` as the project-local SpecAnchor skill.

When I request a code change, first run SpecAnchor boot and resolve the relevant anchors. Show the Assembly Trace and Spec Anchors Used, then decide whether the work stays in `⚡ lightweight` or needs the `standard Task Spec workflow`.

If the change is multi-file, structural, or otherwise non-trivial, switch to the `standard Task Spec workflow`, create or update the Task Spec first, and do not enter Execute before the required gates are satisfied.

## Expected Boot Behavior

- Run `SPECANCHOR_SKILL_DIR="$PWD/.cursor/skills/specanchor" bash "$PWD/.cursor/skills/specanchor/scripts/specanchor-boot.sh" --format=summary`
- Report the mode and Assembly Trace
- Report whether the work stays in `⚡ lightweight` or needs the `standard Task Spec workflow`
- Stop and report missing anchors instead of guessing

## Resolve Before Editing

Ask Cursor to run `specanchor-resolve.sh` for the files it plans to touch and summarize the selected Global / Module / Source anchors before writing code.

## What Not To Ask

- Do not ask Cursor to invent business rules when no anchor exists.
- Do not ask Cursor to skip boot / resolve and edit files directly.
- Do not ask Cursor to skip Task Spec creation or required gates for the `standard Task Spec workflow`.

## Alpha Limitation

Resolve is deterministic-first. It matches paths and known spec locations; it is not semantic RAG.
