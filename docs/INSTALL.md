# Install SpecAnchor

This document covers the supported installation paths for the public SpecAnchor skill.

## Requirements

- Bash 3.2+
- Git
- `rsync` recommended for installation
- Python 3 recommended for JSON validation during development

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

Project-local install:

```bash
SKILL_DIR=/absolute/path/to/spec-anchor
PROJECT_DIR=/absolute/path/to/your-project

rsync -a --exclude-from="$SKILL_DIR/.skillexclude" \
  "$SKILL_DIR/" "$PROJECT_DIR/.agents/skills/specanchor/"
```

Then reference the skill from `CLAUDE.md` or `AGENTS.md`.

## Other AI Tools

SpecAnchor is a plain-text skill. Copy it into the tool-specific skill directory, then point the tool at `SKILL.md`.

```bash
rsync -a --exclude-from=/absolute/path/to/spec-anchor/.skillexclude \
  /absolute/path/to/spec-anchor/ /absolute/path/to/your-tool-skill-dir/specanchor/
```

## First-Success Check

Run these commands from the target project root after installation:

```bash
SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-init.sh \
  --project=my-project --mode=full

SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-boot.sh \
  --format=summary
```

The install is healthy when:

- both commands exit `0`
- the boot summary prints the resolved config and mode
- the boot summary does not show missing-source `✗` lines

## Why `rsync` Instead of `cp -r`

The repository contains development-only files that should not be copied into consumer projects. `.skillexclude` defines the installation boundary. If you use another copy mechanism, keep the same exclusion behavior.
