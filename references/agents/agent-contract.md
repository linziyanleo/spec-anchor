# Agent Contract

SpecAnchor expects agents to follow one deterministic loop.

## Startup

1. Run `specanchor-boot.sh`.
2. Report the Assembly Trace from boot.
3. Do not edit code if boot has blocking errors.

## Before Editing

1. Decide `⚡ lightweight` or `standard Task Spec workflow`.
2. Run `specanchor-assemble.sh` with concrete file paths and task intent.
3. Read every file in `files_to_read`.
4. If missing coverage exists for behavior changes, stop, create a Task Spec, or ask for a new Module Spec.

## After Editing

1. Run targeted tests.
2. Run `specanchor-doctor.sh` or `specanchor-validate.sh` when specs changed.
3. Report anchors used, files changed, verification, and remaining drift.

## Must Never Do

- Do not skip boot.
- Do not jump from vague intent straight to code edits on multi-file work.
- Do not invent business rules when coverage is missing.
- Do not treat shell script names as the user-facing command language.
