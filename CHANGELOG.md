# Changelog

## v0.5.0-beta.1 — Harness Context Control

### Highlights

- **Reframes SpecAnchor as a Harness Context Control plane**: three context categories (Spec / Decision / Evidence) made explicit in README, WHY, and SKILL.md.
- **`sdd-riper-one` schema v2** adds 6 new sections to the Task Spec template: `§1.2 Hard Boundaries`, `§1.3 Allowed Freedom`, `§4.7 Checkpoints — Contract`, `§5.2 Checkpoint Decisions Log`, `§6.2 Evidence Ledger`, `§7.2 Handoff Packet`. The schema declares a `context_control` node listing kind/writer for each.
- **`anchor.yaml` `context_control` block**: `decision_log` / `evidence_log` filter parameters, per-section `enforce` levels (`error / warning / off`), `pre_commit.{enabled, blocking}` switch.
- **Two new pure-function libs** (dual interface — `source` + CLI):
  - `scripts/lib/decision-filter.sh` — hot/cold/superseded/withdrawn classification for §5.2 with 3-tier config precedence (CLI > task frontmatter > anchor.yaml > builtin).
  - `scripts/lib/evidence-filter.sh` — 4-subsection parser (Commands Run / Acceptance Criteria / Risks / Manual / Rollback) with status normalization and auto-pin acceptance.
- **`specanchor-doctor.sh --lint=context-control`**: scans every active task spec, reports section presence per `enforce` level. Default doctor behavior unchanged (lint only triggers when `--lint=` is explicit).
- **`specanchor-assemble.sh --mode=handoff`** + **`specanchor_handoff` command**: exports Task Spec hot decisions, evidence status, read-next files, and next step into a packet (text / markdown / json), with optional `--write-back` to refresh §7.2.
- **`.githooks/pre-commit`** now runs context-control lint after the existing identity guard. Blocking is gated by `anchor.yaml.context_control.pre_commit.blocking` (default `true` for the spec-anchor repo; new projects start with `false`).
- **TSV separator hardened** to `\037` (Unit Separator) inside the lib pipeline so bash `read` does not collapse empty fields — fixed a parser bug where decisions with empty phase markers shifted column positions.
- **Self-dogfood**: this release was implemented while continuously running its own lint, filters, and handoff packet against `.specanchor/tasks/_cross-module/2026-05-18_harness-context-control.spec.md`.

### Out of scope (deferred)

- Steering Trigger emission on verification failure × 2 (third-wave; needs ≥50 real decisions corpus first)
- task-local codemap as a first-class command (second-wave)
- Spec ↔ Spec drift detection (third-wave)
- Automatic migration tool for existing tasks (only upgrade docs are provided in this release)

### Migration

Existing projects will start showing context-control lint warnings/errors on their old task specs. To clear them:

1. Add a `context_control:` block to `anchor.yaml` (see `scripts/specanchor-init.sh:46-87` for the generated template).
2. For tasks created before v0.5.0-beta.1, append placeholder sections (`§1.2 / §1.3 / §4.7 / §5.2 / §6.2 / §7.2`) marked `not applicable — legacy task` to satisfy the lint without backfilling history.
3. New tasks created via `specanchor_task` automatically get the v2 schema.

Set `pre_commit.blocking: false` initially to keep the lint in warning-only mode while you upgrade.

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
