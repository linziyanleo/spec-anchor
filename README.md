<div align="center">
  <img src="assets/SpecAnchor_logo.png" alt="SpecAnchor Logo" width="140" />
</div>

<h1 align="center">SpecAnchor</h1>

<p align="center">
  <em>Spec is the anchor, code is the ship.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" />
  <a href="https://github.com/linziyanleo/spec-anchor/actions/workflows/ci.yml">
    <img src="https://github.com/linziyanleo/spec-anchor/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
  <img src="https://img.shields.io/badge/version-0.4.0--alpha.2-brightgreen.svg" alt="Version 0.4.0-alpha.2" />
  <img src="https://img.shields.io/badge/Claude%20Code-%E2%9C%93-orange" alt="Claude Code" />
  <img src="https://img.shields.io/badge/Cursor-%E2%9C%93-1e90ff" alt="Cursor" />
  <img src="https://img.shields.io/badge/Codex-%E2%9C%93-lightgrey" alt="Codex" />
  <img src="https://img.shields.io/badge/Gemini-%E2%9C%93-blueviolet" alt="Gemini" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ZH.md">中文</a> ·
  <a href="WHY.md">WHY</a> ·
  <a href="docs/INSTALL.md">Install</a> ·
  <a href="CONTRIBUTING.md">Contributing</a> ·
  <a href="SKILL.md">Skill</a>
</p>

---

SpecAnchor is a spec governance / anti-decay layer for AI coding. It loads persistent Global / Module / Task specs before an agent writes code; it does not prescribe the authoring workflow itself.

> Warning
> SpecAnchor writes `.specanchor/`, may create or update `anchor.yaml`, and may inject or update Markdown frontmatter. Test it on a clean branch first.

## 60-Second Quick Start

1. Install the skill into a project.

```bash
SKILL_DIR=/absolute/path/to/spec-anchor
PROJECT_DIR=/absolute/path/to/your-project

rsync -a --exclude-from="$SKILL_DIR/.skillexclude" \
  "$SKILL_DIR/" "$PROJECT_DIR/.cursor/skills/specanchor/"
```

1. Initialize SpecAnchor from the target project root.

```bash
cd "$PROJECT_DIR"

SPECANCHOR_SKILL_DIR="$PWD/.cursor/skills/specanchor" \
  bash "$PWD/.cursor/skills/specanchor/scripts/specanchor-init.sh" \
  --project="$(basename "$PWD")" --mode=full
```

1. Verify the install.

```bash
SPECANCHOR_SKILL_DIR="$PWD/.cursor/skills/specanchor" \
  bash "$PWD/.cursor/skills/specanchor/scripts/specanchor-boot.sh" \
  --format=summary
```

Success means the command exits `0` and the boot summary does not print missing-source `✗` lines.

For Claude Code, symlink-based development installs, and other tool layouts, see [docs/INSTALL.md](docs/INSTALL.md).

## Usage Proof

- Overview: [docs/USAGE_PROOF.md](docs/USAGE_PROOF.md)
- Full mode example: [examples/minimal-full-project/](examples/minimal-full-project/)
- Parasitic mode example: [examples/parasitic-openspec-project/](examples/parasitic-openspec-project/)
- Agent prompts: [examples/agent-walkthrough/](examples/agent-walkthrough/)

## Agent Reliability

- Overview: [docs/agent-reliability.md](docs/agent-reliability.md)
- Contract: [references/agents/agent-contract.md](references/agents/agent-contract.md)
- Agent guides: [Claude Code](references/agents/claude-code.md), [Codex](references/agents/codex.md), [Cursor](references/agents/cursor.md), [Gemini](references/agents/gemini.md)
- Walkthroughs: [docs/examples/minimal-agent-loop.md](docs/examples/minimal-agent-loop.md), [docs/examples/missing-module-coverage.md](docs/examples/missing-module-coverage.md), [docs/examples/parasitic-source-resolution.md](docs/examples/parasitic-source-resolution.md)

## What SpecAnchor Does

- Loads Global, Module, and Task specs before code generation.
- Governs external spec directories through `sources` instead of forcing migrations.
- Tracks coverage, staleness, and module indexing so specs do not silently decay.
- Keeps the writing protocol pluggable: SDD-RIPER-ONE, OpenSpec, or your own schema.

## Positioning

- SpecAnchor focuses on governance and anti-decay.
- SDD-RIPER-ONE and OpenSpec focus on authoring flow and spec format.
- SpecAnchor works in `full` mode for its own three-level spec system and `parasitic` mode for existing spec directories.

## Public Surface

Treat these files and interfaces as contributor-facing:

- `anchor.yaml`
- `.specanchor/` layout in `full` mode
- `scripts/specanchor-init.sh`
- `scripts/specanchor-boot.sh`
- `scripts/specanchor-status.sh`
- `scripts/specanchor-index.sh`
- `scripts/specanchor-check.sh`
- `scripts/specanchor-doctor.sh`
- `scripts/specanchor-resolve.sh`
- `scripts/specanchor-validate.sh`
- `SKILL.md`
- `references/`

The high-level product overview lives here in `README.md`; the runtime activation contract lives in `SKILL.md`.

## Validation

From the repository root, the minimum maintainer checks are:

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
git diff --check
```

## Release Status

Current published prerelease: `v0.4.0-alpha.2`.

- Release notes: [`docs/release/v0.4.0-alpha.2.md`](docs/release/v0.4.0-alpha.2.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Install verification stays the same as the Validation block above.

Current unreleased milestone: `v0.4.0-beta.dev`.

- Beta draft note: [`docs/release/v0.4.0-beta.md`](docs/release/v0.4.0-beta.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for environment requirements, validation commands, and PR scope.

## License

Code is licensed under [MIT](LICENSE). Repository images are documented separately in [assets/README.md](assets/README.md).
