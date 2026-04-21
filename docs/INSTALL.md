# Install SpecAnchor

This document covers the supported installation paths for the public SpecAnchor skill.

## Requirements

- Bash 3.2+
- Git
- `rsync` recommended for installation
- Python 3 recommended for JSON validation during development

> Warning
> SpecAnchor writes `anchor.yaml`, may create `.specanchor/`, and may update Markdown frontmatter. Start on a clean branch when testing a new install.

## Cursor

Project-local install:

```bash
SKILL_DIR=/absolute/path/to/spec-anchor
PROJECT_DIR=/absolute/path/to/your-project

rsync -a --exclude-from="$SKILL_DIR/.skillexclude" \
  "$SKILL_DIR/" "$PROJECT_DIR/.cursor/skills/specanchor/"
```

Local development with a symlink:

```bash
ln -s /absolute/path/to/spec-anchor \
  /absolute/path/to/your-project/.cursor/skills/specanchor
```

Global install:

```bash
rsync -a --exclude-from=/absolute/path/to/spec-anchor/.skillexclude \
  /absolute/path/to/spec-anchor/ ~/.cursor/skills/specanchor/
```

## Claude Code

Project-local auto-discovery install:

```bash
SKILL_DIR=/absolute/path/to/spec-anchor
PROJECT_DIR=/absolute/path/to/your-project

rsync -a --exclude-from="$SKILL_DIR/.skillexclude" \
  "$SKILL_DIR/" "$PROJECT_DIR/.claude/skills/specanchor/"
```

Then reference the skill from `CLAUDE.md` or `AGENTS.md` if your prompt flow wants to pin the skill explicitly.

If you are using a generic tool-specific layout instead of Claude Code's default auto-discovery path, you can also install the skill under `.agents/skills/specanchor/` and point your tooling there manually.

## Other AI Tools

SpecAnchor is a plain-text skill. Copy it into the tool-specific skill directory, then point the tool at `SKILL.md`.

```bash
rsync -a --exclude-from=/absolute/path/to/spec-anchor/.skillexclude \
  /absolute/path/to/spec-anchor/ /absolute/path/to/your-tool-skill-dir/specanchor/
```

## Usage Proof Examples

- Overview: [`docs/USAGE_PROOF.md`](USAGE_PROOF.md)
- Full mode example: [`examples/minimal-full-project/`](../examples/minimal-full-project/)
- Parasitic mode example: [`examples/parasitic-openspec-project/`](../examples/parasitic-openspec-project/)
- Agent walkthroughs: [`examples/agent-walkthrough/`](../examples/agent-walkthrough/)
- Agent reliability: [`docs/agent-reliability.md`](agent-reliability.md)

## First-Success Check

Run these commands from the target project root after installation:

```bash
SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-init.sh \
  --project=my-project --mode=full

SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-boot.sh \
  --format=summary

SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-doctor.sh \
  --strict
```

The install is healthy when:

- all commands exit `0`
- the boot summary prints the resolved config and mode
- the boot summary does not show missing-source `✗` lines
- doctor does not report blocking or strict warnings

For multi-file or structural work, the next successful step is:

```bash
SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-assemble.sh \
  --files="path/to/file.ext" \
  --intent="describe the change" \
  --format=markdown
```

## Why `rsync` Instead of `cp -r`

The repository contains development-only files that should not be copied into consumer projects. `.skillexclude` defines the installation boundary. If you use another copy mechanism, keep the same exclusion behavior.
