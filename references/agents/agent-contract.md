# Agent Contract

SpecAnchor expects agents to follow one deterministic loop — seven steps that turn a vague intent into spec-anchored code with alignment evidence and experience recovery.

## 1. Enter Spec Landscape

Assemble the spec context that every agent reads before acting.

1. Run `specanchor-boot.sh`.
2. Output the Assembly Trace (Global / Module / Task / Sources levels).
3. Do not edit code if boot has blocking errors.

## 2. Resolve Anchors

Identify which modules the task touches and load their specs.

1. Run `specanchor-assemble.sh --files=<paths> --intent=<description>`.
2. Read every file listed in `files_to_read`.
3. If `missing` count > 0 for behavior changes, stop and create a Module Spec or Task Spec first.

## 3. Workflow Selection

Decide the control intensity based on task scope.

- `⚡ lightweight`: single-file or small-scope fix; execute directly.
- `📋 standard Task Spec workflow`: multi-file, multi-module, data-flow, or structural change; create a Task Spec before implementation.

Rules: `references/workflow-gates.md`.

## 4. Schema Gate

If standard workflow was chosen, gate execution until the schema's checkpoints pass.

1. Create a Task Spec via `specanchor_task`.
2. Follow the schema's artifact sequence (e.g., Research → Plan → Execute → Review).
3. If the schema declares a `gate` (e.g., `Plan Approved`), stop and request user confirmation.
4. Do not enter Execute until the gate passes.

## 5. Execute

Implement under spec constraints.

1. Code changes must respect Global Spec + loaded Module Spec(s).
2. Run targeted tests after each implementation step.
3. Track progress in the Task Spec's Execute Log (if standard workflow).

## 6. Alignment Check

Verify that specs and code stayed in sync.

Choose checks by what changed:

- **Spec files were modified** → run `specanchor-doctor.sh` + `specanchor-validate.sh` (format / frontmatter compliance).
- **Code files were modified** → run `specanchor-check.sh task <spec-file>` (task-scoped module alignment).
- **Always** → report anchors used, files changed, verification results, and remaining drift.

## 7. Spec Sediment

Channel lessons back into the spec system.

1. Evaluate whether Module Spec needs updating (interface / dependency / boundary changes).
2. Evaluate whether Global Spec needs updating (new project-wide rules discovered).
3. Record findings in the Review Verdict's Spec Sediment bullets.
4. If updates are needed, create follow-up tasks or apply immediately with user approval.

## Must Never Do

- Do not skip boot.
- Do not jump from vague intent straight to code edits on multi-file work.
- Do not invent business rules when spec coverage is missing.
- Do not treat shell script names as the user-facing command language.
- Do not claim work is complete without alignment evidence.
