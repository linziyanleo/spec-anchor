# Changelog

## v0.4.0-beta.2 — Frontmatter and Spec Index Refactor

### Highlights

- Moves SDD RIPER phase state from task frontmatter into the body marker `> Current RIPER Phase: ...`.
- Adds v3 `.specanchor/spec-index.md` covering Global, Module, and Task Specs.
- Updates boot output with compact `Available Commands` and `Available Modules` routing hints.
- Keeps `.specanchor/module-index.md` as a migration fallback via `--legacy-module-index`.

### Migration

```bash
bash scripts/frontmatter-inject.sh --migrate-sdd-phase --dir .specanchor/tasks
bash scripts/frontmatter-inject.sh --normalize-task-status --dir .specanchor/tasks
bash scripts/specanchor-index.sh --legacy-module-index
```

### Validation

```bash
bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash scripts/specanchor-validate.sh --strict
bash tests/run.sh
SPECANCHOR_RUN_BATS=1 bash tests/run_all.sh
```

## v0.4.0-beta.1 — Walkthrough Corrections

### Highlights

- Corrects the Codex walkthrough so it no longer reads like a Cursor install guide.
- Adds a Qoder walkthrough aligned with Qoder's project-level Skill path.
- Updates usage-proof example indexes so the new walkthrough appears in public documentation.

### Validation

```bash
bash tests/test_usage_proof.sh
bash tests/run.sh
git diff --check
```

### Known Limitations

- This is still a beta prerelease; public interfaces may still change before `v0.4.0`.
- The change is documentation-only; it does not alter resolver or workflow script behavior.

## v0.4.0-beta — Agent Reliability

### Highlights

- Upgrades anchor resolution to `specanchor.resolve.v2` with explicit budget, missing coverage, and trace data.
- Adds `specanchor-assemble.sh` so agents can turn resolver output into a bounded read plan.
- Adds agent-facing contracts, walkthrough docs, and release checks for reliability-focused workflows.
- Adds `specanchor-hygiene.sh` plus stronger doctor / validate checks for drift and dead-link prevention.

### Validation

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict --profile=agent
bash scripts/specanchor-validate.sh --format=json | python3 -m json.tool >/dev/null
bash tests/run.sh
git diff --check
```

### Known Limitations

- This is a beta prerelease; public interfaces may still change before `v0.4.0`.
- Resolve remains deterministic-first; it does not attempt semantic retrieval.
- `--diff-from` depends on local git history and only inspects checked-out repository state.

## v0.4.0-alpha.2 — Usage Proof

### Highlights

- Added dependency-free example projects for full mode and parasitic mode.
- Added usage proof smoke tests for installation, boot, doctor, validate, and resolve.
- Added agent walkthroughs for Codex, Claude Code, and Cursor.
- Added CI coverage for usage proof examples.
- Documented what alpha.2 proves and does not prove.

### Validation

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
bash tests/test_usage_proof.sh
git diff --check
```

### Known Limitations

- Examples are intentionally minimal and dependency-free.
- Resolve is deterministic-first; it is not a semantic search engine.
- This is still an alpha release; public interfaces may change before `v0.4.0`.

## v0.4.0-alpha.1 — Public Prerelease

### Highlights

- Repo is self-bootable in full mode.
- Public shell tests, fresh-clone smoke, and consumer-install smoke are in place.
- Command entry semantics are now natural-language-first, with `SA:` documented as optional shorthand.
- `anchor.local.yaml` overlay support landed for maintainer-local sources and scalar overrides.
- README / WHY entrypoints and public docs links are aligned for the current file layout.

### Install Verification

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
git diff --check
```

### Known Limitations

- This is still an alpha release; public interfaces may change before `v0.4.0`.
- `anchor.local.yaml` is intentionally narrow: public scripts merge `sources` by append and read scalar fields with local precedence; it is not a generic YAML deep-merge layer.
- GitHub Release publication and repository About metadata still depend on syncing this repo state to the public GitHub mirror.
