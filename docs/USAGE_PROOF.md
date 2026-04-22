# Usage Proof

## What This Proves

SpecAnchor `v0.4.0-alpha.2` proves that a new user can install the public skill into realistic clean projects and run the governance flow successfully.

The committed examples and smoke tests prove:

- full mode can initialize a clean project and create a working `.specanchor/` baseline
- parasitic mode can govern external specs without moving them into `.specanchor/`
- `boot`, `doctor --strict`, `validate`, and `resolve --format=json` all run without network access
- agents can be prompted to boot and resolve anchors before editing files

## What This Does Not Prove

This release does not prove:

- application runtime behavior
- code quality
- semantic search or vector retrieval
- automatic spec authoring quality
- any web UI, daemon, MCP server, or package-manager installer

SpecAnchor proves governance and anti-decay. It does not replace engineering judgment.

## Example 1: Minimal Full Mode Project

Path: [`examples/minimal-full-project/`](../examples/minimal-full-project/)

This example starts with a tiny `src/` tree and no SpecAnchor config. The usage-proof smoke installs the skill into a temp copy, runs `specanchor-init.sh --mode=full`, then verifies:

- `anchor.yaml` exists
- `.specanchor/` exists
- starter Global Specs exist
- `specanchor-boot.sh --format=summary` exits `0`
- `specanchor-doctor.sh --strict` exits `0`
- `specanchor-validate.sh --format=summary` exits `0`

Full mode owns `.specanchor/`. The generated starter Global Specs are intentionally generic so a clean project can pass strict health checks before its first project-specific refinement pass.

## Example 2: Parasitic External Specs

Path: [`examples/parasitic-openspec-project/`](../examples/parasitic-openspec-project/)

This example keeps its source-of-truth specs under `specs/` and runs SpecAnchor in `parasitic` mode.

The smoke verifies:

- boot reports `parasitic` mode
- `specs/` is recognized as an external source
- `doctor --strict` exits `0`
- `resolve --format=json` returns valid JSON and points back to `specs/auth.md`
- no files are moved into `.specanchor/`

Parasitic mode reads external specs without migrating them.

## Example 3: Agent Walkthroughs

Path: [`examples/agent-walkthrough/`](../examples/agent-walkthrough/)

The walkthroughs for Cursor, Claude Code, Codex, and Qoder show how to:

- point the agent at the installed skill
- run boot before editing
- resolve anchors for the planned files and intent
- report the Assembly Trace and anchors used
- stop when no anchor exists instead of inventing product behavior

## Validation Commands

From the repository root:

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash scripts/specanchor-validate.sh --format=summary
bash tests/run.sh
bash tests/test_usage_proof.sh
git diff --check
```

For a consumer project, the first-success path is:

```bash
SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-init.sh \
  --project=my-project --mode=full

SPECANCHOR_SKILL_DIR=/absolute/path/to/installed/specanchor \
  bash /absolute/path/to/installed/specanchor/scripts/specanchor-boot.sh \
  --format=summary
```

## Known Alpha Limitations

- Examples are intentionally dependency-free and minimal.
- `specanchor-resolve.sh` is deterministic-first; it matches paths, known spec files, and simple tokens. It is not semantic RAG.
- Agents must report missing anchors instead of inventing product behavior.
- Public interfaces may still change before `v0.4.0`.
