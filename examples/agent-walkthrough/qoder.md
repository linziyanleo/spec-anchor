# Qoder Walkthrough

## Install Path

Install the skill at `.qoder/skills/specanchor/`.

Qoder's official project-level Skill path is `.qoder/skills/{skill-name}/SKILL.md`.

## First Prompt

Use the SpecAnchor skill installed at `.qoder/skills/specanchor`.

Before making changes:
1. Run SpecAnchor boot.
2. Resolve or assemble anchors for the files you plan to edit.
3. Read the relevant Global / Module / Task specs or external sources.
4. Report the anchors used and choose the workflow: `⚡ lightweight` for a small single-file change, `standard Task Spec workflow` for multi-file or structural work.
5. If the work needs the `standard Task Spec workflow`, create or update the Task Spec before implementation and honor any gates such as `Plan Approved`.
6. Only propose or apply code changes after the workflow step is clear.

Do not invent business rules if no anchor exists.

## Expected Boot Behavior

- Qoder reports `SpecAnchor Boot [...]` with mode and Assembly Trace.
- Qoder lists the anchors it will use before editing.
- Qoder states whether the work stays in `⚡ lightweight` or needs the `standard Task Spec workflow`.
- If anchors are missing, Qoder stops and asks for direction.

## Resolve Before Editing

Have Qoder run `specanchor-assemble.sh --files="<targets>" --intent="<change>" --format=markdown` for multi-file work, or `specanchor-resolve.sh --files="<targets>" --intent="<change>" --format=json` for a narrow targeted change.

## What Not To Ask

- Do not ask Qoder to bypass the governance step.
- Do not ask Qoder to skip workflow selection or execute before required gates.
- Do not ask Qoder to invent missing product behavior from vague intent.

## Alpha Limitation

The examples are intentionally dependency-free. They prove installation and anchor resolution, not application runtime behavior.
