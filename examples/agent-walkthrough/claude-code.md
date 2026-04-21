# Claude Code Walkthrough

## Install Path

Install the skill at `.agents/skills/specanchor/`.

## First Prompt

Use the SpecAnchor skill installed at `.agents/skills/specanchor`.

Before writing code:
1. Read `SKILL.md`.
2. Run the boot script.
3. Use `specanchor-resolve` for the target files and intent.
4. Load the selected specs.
5. Decide whether the work stays in `⚡` or needs `📋`.
6. If the work is `📋`, create or update the Task Spec and honor required gates before Execute.
7. Report unresolved or missing anchors before implementation.

## Expected Boot Behavior

- Boot prints the resolved config and Assembly Trace.
- Claude Code reports which Global / Module / Source anchors it loaded.
- Claude Code reports whether the task stays in `⚡` or needs `📋`.
- Missing anchors are surfaced before code edits begin.

## Resolve Before Editing

Pair the target files with a short intent, for example: `--files="src/auth/login.md" --intent="change login behavior"`.

## What Not To Ask

- Do not ask Claude Code to treat SpecAnchor as a code generator.
- Do not ask it to skip Task Spec creation or required gates for `📋` work.
- Do not ask it to mutate accepted specs automatically.

## Alpha Limitation

SpecAnchor proves governance and anti-decay. It does not prove code quality by itself.
