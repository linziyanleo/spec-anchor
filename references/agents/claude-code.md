# Claude Code + SpecAnchor

## Install Path

Default Claude Code auto-discovery path:

```text
.claude/skills/specanchor/
```

Generic manual layout, if your tooling points there explicitly:

```text
.agents/skills/specanchor/
```

## Manual Invocation

If Claude Code does not run scripts automatically, call:

```bash
SPECANCHOR_SKILL_DIR=.claude/skills/specanchor \
  bash .claude/skills/specanchor/scripts/specanchor-boot.sh --format=summary
```

Then use `specanchor-assemble.sh` before editing.

## Recommended Prompt

Use the SpecAnchor skill installed at `.claude/skills/specanchor`.

Before writing code:
1. Read `SKILL.md`.
2. Run the boot script.
3. Choose `⚡ lightweight` or `standard Task Spec workflow`.
4. Use `specanchor-assemble.sh` for the target files and intent.
5. Read the selected specs.
6. Report unresolved or missing anchors before implementation.

## Walkthrough

For a focused shell-script fix:
1. Boot the project.
2. Run assemble with the shell file paths and intent.
3. Read the listed Global / Module docs.
4. Apply the code change.
5. Run tests, then doctor / validate if specs changed.
