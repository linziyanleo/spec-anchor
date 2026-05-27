---
name: spec-anchor
description: "MUST invoke in projects with anchor.yaml or .specanchor/ — before code changes, spec/context management, alignment checks, handoff, findings, or sediment work. Loads coding standards, module contracts, and active tasks."
---

<!-- Plugin skill entry point — delegates to the root SKILL.md -->

<HARD-GATE>
If this project has `anchor.yaml` or `.specanchor/`, load SpecAnchor context before code changes.
Specs contain constraints not visible in code alone — even for small edits, assemble context first.
</HARD-GATE>

<!-- Load the full skill definition -->
The full spec-anchor skill definition is in the plugin root `SKILL.md`. Read and follow `../../SKILL.md` for all commands, protocols, and references.
