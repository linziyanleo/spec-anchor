---
specanchor:
  level: task
  task_name: "SpecAnchor v0.4.0-alpha Trustable Core"
  task_type: "maintenance"
  schema: "simple"
  status: "review"
  owner: "repo-maintainer"
  created: "2026-04-20"
  updated: "2026-04-20"
  last_synced: "2026-04-20"
  target_repo: "linziyanleo/spec-anchor"
  target_branch: "main"
  priority: "P0/P1"
---

# SpecAnchor v0.4.0-alpha — Trustable Core

## 0. 给 Codex 的执行提示

You are Codex running locally at the root of the `spec-anchor` repository.

Treat this file as the source of truth for the current maintenance task. Implement the required tasks in priority order. Prefer small, reviewable changes. Do not rewrite the project architecture. Do not introduce heavyweight dependencies. Validate every milestone locally before continuing.

When this spec conflicts with existing behavior, preserve the existing public behavior unless this spec explicitly changes it. If you find a blocker, write it down in `CODEX-BLOCKERS.md` with exact file paths, commands run, and observed output, then continue with the remaining non-blocked tasks.

This task uses the `simple` workflow: no RIPER gate, no user confirmation gate. Implement, test, and report.

---

## 1. Problem Statement

SpecAnchor has a strong protocol design, but the repo needs to become trustworthy as a local toolchain.

The current optimization goal is not to add more workflow schemas. The goal is to make the repository:

1. self-bootable after clone;
2. testable on Linux and macOS;
3. diagnosable when configuration/spec state is broken;
4. internally consistent in command semantics;
5. easier for AI coding agents to load the right Spec context without reading the entire repo.

---

## 2. Non-goals

Do not do these in this milestone:

- Do not add a vector database, RAG service, daemon, MCP server, or UI.
- Do not convert the shell toolchain to Node/Python/Go.
- Do not add new writing schemas beyond existing ones.
- Do not implement release publishing automation unless all required tasks are complete.
- Do not auto-update accepted user Specs silently.
- Do not require internet access for local tests.
- Do not rely on proprietary tools.

---

## 3. Required Definition of Done

The milestone is complete only when all required commands below pass from a fresh local checkout:

```bash
# from repo root
bash scripts/specanchor-boot.sh --format=json > /tmp/specanchor-boot.json
python3 -m json.tool /tmp/specanchor-boot.json >/dev/null

bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-status.sh --format=json > /tmp/specanchor-status.json || true
python3 -m json.tool /tmp/specanchor-status.json >/dev/null || true

bash tests/run.sh
```

And CI must run the same test suite on:

- `ubuntu-latest`
- `macos-latest`

If `python3` is not present locally, tests may skip JSON parsing with a clear message, but GitHub Actions must validate JSON.

---

## 4. Current Known Issues to Fix

Verify these locally before changing code.

### KI-001 — Full mode is not self-bootable

`anchor.yaml` declares `mode: "full"` and points to `.specanchor/global/`, `.specanchor/modules/`, `.specanchor/tasks/`, `.specanchor/module-index.md`, and `.specanchor/project-codemap.md`.

However, the repo currently ignores `.specanchor/`. A fresh clone may have `anchor.yaml` but no committed `.specanchor/` data. This makes the project unable to dogfood itself in full mode.

### KI-002 — Public tests are not committed

The repo currently ignores `/tests/`, but scripts are now core runtime assets. Public tests are required.

### KI-003 — Command semantics conflict

`SKILL.md` allows natural language and SA-prefixed precise commands. `references/commands-quickref.md` says SpecAnchor does not use CLI-style command prefixes. This must be normalized.

### KI-004 — Entry file is overloaded

`SKILL.md` contains protocol details, script contracts, command routing, workflow gates, and integration text. It should remain the entrypoint and router, while detailed protocols should live under `references/`.

This is not a blocking P0 issue, but it should be started carefully.

### KI-005 — No health-check command

Users and agents need one script that explains whether the repo/project is healthy and what to fix. This should not mutate files by default.

### KI-006 — Markdown skill files can be excluded from coverage

`anchor.yaml` includes `*.md` in `coverage.ignore_paths`. For SpecAnchor, Markdown files are product/runtime files, not just documentation. Coverage logic should not globally ignore the skill’s own `SKILL.md` and `references/**/*.md`.

---

## 5. Required Work Plan

## P0-A. Make the repo self-bootable

### Goal

A fresh clone of `spec-anchor` must be able to run:

```bash
bash scripts/specanchor-boot.sh --format=json
```

and return valid JSON with exit code 0.

### Required changes

#### A1. Update `.gitignore`

Replace the current one-line ignore style with a readable multi-line file.

Required behavior:

- keep ignoring `.DS_Store`;
- keep ignoring local/generated `mydocs` content;
- stop ignoring all of `/tests/`;
- stop ignoring all of `.specanchor/`;
- ignore volatile `.specanchor` subdirectories only;
- allow committed baseline self-dogfood specs.

Recommended `.gitignore` shape:

```gitignore
.DS_Store

# Local SDD output / historical working docs
/mydocs/*

# SpecAnchor self-dogfood data is partially committed.
# Keep stable governance specs committed; keep volatile task/archive/local data out.
.specanchor/tasks/*
!.specanchor/tasks/.gitkeep
.specanchor/archive/*
!.specanchor/archive/.gitkeep
.specanchor/local/
.specanchor/tmp/
```

If the repo needs empty directories for scripts, commit `.gitkeep` files.

#### A2. Keep `.skillexclude` installation-safe

`.skillexclude` should continue excluding development-only assets from installation into user projects.

Recommended behavior:

```text
.specanchor/
mydocs/
tests/
.github/
.git/
.gitignore
.skillexclude
CODEX-BLOCKERS.md
```

Important: committing `.specanchor/` for repo self-dogfooding does not mean installing it into users’ projects.

#### A3. Add minimal committed `.specanchor/`

Add a minimal self-dogfood structure:

```text
.specanchor/
├── global/
│   ├── project-setup.spec.md
│   └── specanchor-governance.spec.md
├── modules/
│   ├── scripts.spec.md
│   └── references.spec.md
├── tasks/
│   └── .gitkeep
├── archive/
│   └── .gitkeep
├── module-index.md
└── project-codemap.md
```

Keep Global Specs short. All Global Specs together should stay under 200 lines.

Suggested scope:

- `project-setup.spec.md`: repo purpose, shell-only constraint, local validation commands.
- `specanchor-governance.spec.md`: Global/Module/Task rules, accepted Spec mutation rules, no silent accepted-spec updates.
- `scripts.spec.md`: responsibilities of scripts under `scripts/`, expected CLI behavior, output stability.
- `references.spec.md`: responsibilities of `SKILL.md`, `references/commands`, `references/schemas`, protocol docs.
- `module-index.md`: v2-style index if supported by current script; otherwise the simplest format current boot/status scripts can parse.
- `project-codemap.md`: concise map of runtime files and governance files.

#### A4. Preserve boot compatibility

If `specanchor-boot.sh` cannot currently parse the new `.specanchor` files, fix the script minimally.

Required boot behaviors:

- `--format=summary` must be human-readable.
- `--format=json` must be machine-readable valid JSON.
- full mode with committed `.specanchor/` must exit 0.
- full mode with missing `.specanchor/` in a fixture must exit non-zero and explain the exact problem.
- parasitic mode without `.specanchor/` must not fail solely because `.specanchor/` is absent.

---

## P0-B. Add public tests and fixtures

### Goal

Every core script has a local test path. The tests must not require network access or external dependencies beyond Bash, Git, standard Unix tools, and Python 3 for JSON validation in CI.

### Required files

```text
tests/
├── run.sh
├── helpers/
│   └── assert.sh
└── fixtures/
    ├── full-minimal/
    │   ├── anchor.yaml
    │   └── .specanchor/
    ├── full-missing-specanchor/
    │   └── anchor.yaml
    ├── parasitic-with-sources/
    │   ├── anchor.yaml
    │   └── specs/
    ├── legacy-config/
    │   └── .specanchor/config.yaml
    └── frontmatter-idempotent/
        ├── anchor.yaml
        └── specs/
```

### Test harness requirements

`tests/run.sh` must:

1. locate repo root reliably;
2. create temporary workdirs with `mktemp -d`;
3. copy fixtures into workdirs;
4. run scripts from repo root via absolute paths;
5. set `SPECANCHOR_SKILL_DIR="$REPO_ROOT"`;
6. clean up temp dirs;
7. print a compact summary.

### Required test cases

#### B1. Boot JSON is valid for repo root

```bash
SPECANCHOR_SKILL_DIR="$REPO_ROOT" bash "$REPO_ROOT/scripts/specanchor-boot.sh" --format=json
```

Assert:

- exit code 0;
- output is valid JSON;
- output includes project name or mode;
- output indicates `mode=full` or equivalent.

#### B2. Boot summary works for full-minimal fixture

Assert:

- exit code 0;
- output mentions full mode;
- output mentions Global Specs.

#### B3. Full mode fails clearly when `.specanchor/` is missing

Use `tests/fixtures/full-missing-specanchor`.

Assert:

- exit code non-zero;
- output mentions `.specanchor`;
- output mentions full mode or missing directory.

#### B4. Parasitic mode accepts missing `.specanchor/`

Use `tests/fixtures/parasitic-with-sources`.

Assert:

- exit code 0;
- output mentions parasitic mode;
- output mentions sources.

#### B5. Legacy config fallback is preserved

Use `tests/fixtures/legacy-config`.

Assert:

- script finds `.specanchor/config.yaml`;
- output includes migration warning or compatibility notice;
- exit code follows current intended behavior.

#### B6. Frontmatter injection is idempotent

Use `frontmatter-inject.sh` or `frontmatter-inject-and-check.sh`.

Assert:

- first run modifies expected files or reports would modify in dry-run;
- second run makes no additional changes;
- `git diff --exit-code` or checksum comparison proves idempotency.

#### B7. Status script returns stable output

Run:

```bash
bash "$REPO_ROOT/scripts/specanchor-status.sh" --format=json
```

Assert:

- exit code 0 or documented non-zero warning code;
- valid JSON if `--format=json` is supported;
- if warnings exist, JSON still parses.

### Helper functions

`tests/helpers/assert.sh` should include at least:

```bash
assert_eq()
assert_ne()
assert_contains()
assert_file_exists()
assert_valid_json()
```

`assert_valid_json` may use `python3 -m json.tool` when available. In CI it must be available.

---

## P0-C. Add GitHub Actions CI

### Goal

Every pull request runs the local test suite.

### Required file

```text
.github/workflows/ci.yml
```

### Required workflow

```yaml
name: ci

on:
  push:
  pull_request:

jobs:
  shell-tests:
    name: shell tests (${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]

    steps:
      - uses: actions/checkout@v4

      - name: Show environment
        run: |
          bash --version
          git --version
          python3 --version

      - name: Ensure scripts are executable enough
        run: |
          find scripts -name "*.sh" -maxdepth 1 -print
          chmod +x scripts/*.sh tests/run.sh || true

      - name: Run tests
        run: bash tests/run.sh
```

Do not add shellcheck as a hard requirement unless the repo already supports it. It can be added later as advisory.

---

## P0-D. Normalize command semantics

### Goal

Make command routing unambiguous for users and agents.

### Required semantics

Use this language everywhere:

```text
Natural language is the primary user interface.
`specanchor_*` names are internal command IDs used by the Skill to route intent.
`SA:` aliases are optional advanced shorthand, not a separate CLI contract.
Shell scripts under `scripts/` are implementation helpers, not the user-facing command language.
```

### Required changes

Update at least:

- `SKILL.md`
- `references/commands-quickref.md`
- README command examples if needed
- README_EN if needed

### Required checks

After the change:

```bash
grep -R "不使用 CLI 风格的命令前缀" -n SKILL.md references README.md README_EN.md || true
grep -R "SA 前缀" -n SKILL.md references README.md README_EN.md || true
```

The old contradiction must be gone. Any remaining mention of `SA:` must clearly say it is optional shorthand.

---

## P1-E. Add `specanchor-doctor.sh`

### Goal

Provide a read-only health check command for agents and humans.

### Required file

```text
scripts/specanchor-doctor.sh
```

### CLI

```bash
bash scripts/specanchor-doctor.sh
bash scripts/specanchor-doctor.sh --format=text
bash scripts/specanchor-doctor.sh --format=json
bash scripts/specanchor-doctor.sh --strict
```

### Output behavior

Default output: human-readable text.

JSON output must be valid JSON and include:

```json
{
  "status": "ok | warning | error",
  "mode": "full | parasitic | unknown",
  "blocking": [],
  "warnings": [],
  "suggested_fixes": [],
  "checked": {
    "anchor_yaml": true,
    "specanchor_dir": true,
    "global_specs": true,
    "module_index": true,
    "sources": true,
    "frontmatter": true,
    "coverage": true,
    "scripts": true
  }
}
```

### Exit codes

Use stable exit codes:

- `0`: ok or warnings in non-strict mode
- `1`: warning in strict mode
- `2`: blocking error
- `64`: invalid arguments

### Required checks

Implement at least:

1. `anchor.yaml` exists or legacy `.specanchor/config.yaml` exists.
2. YAML-like config contains `specanchor:` root.
3. `mode` is one of `full`, `parasitic`, or missing/default.
4. full mode has `.specanchor/`.
5. full mode has `.specanchor/global/`.
6. Global Spec total lines <= 200, warning if exceeded.
7. `module-index.md` exists if configured.
8. each configured `sources[].path` exists or warns.
9. `coverage.ignore_paths` does not globally ignore `*.md` without an explicit reason.
10. scripts under `scripts/*.sh` are readable.
11. `references/commands-quickref.md` does not contradict `SKILL.md` command semantics.
12. required schemas under `references/schemas/*/schema.yaml` are discoverable.

### Required tests

Add tests in `tests/run.sh` for:

- doctor ok on repo root;
- doctor JSON parses;
- doctor returns error on `full-missing-specanchor`;
- doctor warns on global `*.md` coverage ignore.

---

## P1-F. Fix coverage config for Markdown skill files

### Goal

SpecAnchor should govern its own Markdown runtime files.

### Required change

Update root `anchor.yaml` coverage settings.

Current risk: `ignore_paths` has `*.md`, which can exclude product-critical files.

Recommended behavior:

```yaml
coverage:
  scan_paths:
    - "SKILL.md"
    - "README.md"
    - "README_EN.md"
    - "WHY.md"
    - "WHY_EN.md"
    - "FLOWCHART.md"
    - "scripts/**"
    - "references/**"
  ignore_paths:
    - "references/schemas/**/template.md"
    - "mydocs/**"
```

If `references/schemas/**/template.md` should be governed, do not ignore it. The key requirement is: do not globally ignore `*.md`.

### Required checks

`specanchor-doctor.sh` should warn if `ignore_paths` contains a global `*.md`.

---

## P1-G. Compact `SKILL.md` without changing behavior

### Goal

`SKILL.md` should remain an entrypoint and router. Detailed protocols should be delegated to `references/`.

### Target

Aim for `SKILL.md` under 140 lines. Do not break trigger metadata.

### Required extraction

Move details into dedicated files where appropriate:

```text
references/script-contract.md
references/assembly-trace.md
references/workflow-gates.md
references/integrations/sdd-riper-one.md
references/integrations/superpowers.md
```

### Keep in `SKILL.md`

- YAML frontmatter
- core purpose
- script invocation rule
- boot requirement
- high-level loading strategy
- command routing summary
- workflow selection checkpoint
- reference file index

### Do not break

- boot script invocation;
- command routing;
- full/parasitic distinction;
- Assembly Trace requirement;
- Task Spec gate behavior;
- Superpowers degradation behavior.

### Required tests/checks

Add simple text checks in `tests/run.sh`:

```bash
wc -l SKILL.md
grep -q "specanchor-boot.sh" SKILL.md
grep -q "references/commands-quickref.md" SKILL.md
grep -q "Assembly Trace" SKILL.md
```

If line count is above 140 after a minimal safe refactor, do not force unsafe compression. Prefer correctness over line-count purity.

---

## P1-H. Add `specanchor-resolve.sh` as a minimal Anchor Resolution engine

### Goal

Provide a deterministic way to decide which Specs should be loaded for a task or file list.

This is the first step toward reliable "index常驻 + 详情按需加载" behavior.

### Required file

```text
scripts/specanchor-resolve.sh
```

### CLI

```bash
bash scripts/specanchor-resolve.sh \
  --files "scripts/specanchor-boot.sh,references/commands/check.md" \
  --intent "make boot JSON stable and add tests" \
  --format=json
```

### Required behavior

Resolution should be deterministic and explainable.

Inputs:

- `--files`: comma-separated changed or target files;
- `--intent`: natural-language task summary;
- `--format`: `text` or `json`.

Matching order:

1. Always include Global Specs in full mode.
2. Match Module Specs using `module_path` from Module Spec frontmatter.
3. Match `module-index.md` entries if available.
4. Match `sources` paths in parasitic mode.
5. If nothing matches, return a warning and suggest creating/infering a Module Spec.

Do not use embeddings or network calls.

### JSON output

```json
{
  "status": "ok | warning | error",
  "mode": "full",
  "anchors": [
    {
      "level": "global",
      "path": ".specanchor/global/project-setup.spec.md",
      "load": "full",
      "reason": "always_load",
      "confidence": 1.0
    },
    {
      "level": "module",
      "path": ".specanchor/modules/scripts.spec.md",
      "load": "full",
      "reason": "file_path_matches_module_path:scripts",
      "confidence": 0.9
    }
  ],
  "missing": [],
  "trace": {
    "global": "full",
    "module": "full"
  }
}
```

### Required tests

Add tests for:

- resolving `scripts/specanchor-boot.sh` returns `scripts.spec.md`;
- resolving `references/commands/check.md` returns `references.spec.md`;
- resolving unknown file returns warning and missing suggestion;
- JSON parses.

---

## P2-I. Add minimal schema/frontmatter validation

### Goal

Move basic governance from documentation-only to machine-checkable validation.

### Required file

```text
scripts/specanchor-validate.sh
```

### Required checks

Validate at least:

- Global Spec frontmatter has `specanchor.level: global`.
- Module Spec frontmatter has `specanchor.level: module`.
- Module Spec has `module_path`.
- `status` is one of `draft`, `review`, `active`, `deprecated`, `archived`.
- date fields are either empty or `YYYY-MM-DD`.
- `anchor.yaml` contains `specanchor.version`.

### CLI

```bash
bash scripts/specanchor-validate.sh
bash scripts/specanchor-validate.sh --format=json
bash scripts/specanchor-validate.sh --path .specanchor/modules/scripts.spec.md
```

### Relationship to doctor

`specanchor-doctor.sh` may call this validator if present, but doctor must not fail if validation is missing during partial implementation.

---

## P2-J. Add release preparation files

### Goal

Prepare for `v0.4.0-alpha` without actually publishing a release.

### Required files

```text
CHANGELOG.md
docs/release/v0.4.0-alpha.md
```

### Required content

`CHANGELOG.md` should include:

```markdown
## v0.4.0-alpha — Trustable Core

- Repo is self-bootable in full mode.
- Added public shell tests and fixtures.
- Added GitHub Actions CI on Ubuntu/macOS.
- Normalized command semantics.
- Added specanchor-doctor health check.
- Added minimal anchor resolution script.
- Improved coverage governance for Markdown runtime files.
```

Do not create tags or GitHub releases from Codex.

---

## 6. Implementation Notes

### 6.1 Shell portability

Scripts must work on both Linux and macOS.

Avoid GNU-only assumptions unless already present in the repo. Be careful with:

- `sed -i`
- `readlink -f`
- GNU `date`
- associative arrays in old Bash if macOS default Bash compatibility is required

Prefer portable Bash patterns already used by the project.

### 6.2 JSON generation

If scripts generate JSON with shell, avoid invalid trailing commas and unescaped quotes.

Add helper functions if useful:

```bash
json_escape() {
  # Escape backslash, quote, newline, tab for JSON strings.
}
```

Use tests to validate every JSON-producing command.

### 6.3 No mutation by default

These scripts must not mutate files unless explicitly designed to do so:

- `specanchor-boot.sh`
- `specanchor-status.sh`
- `specanchor-doctor.sh`
- `specanchor-resolve.sh`
- `specanchor-validate.sh`

Mutation scripts such as `frontmatter-inject.sh` must support dry-run/idempotency tests.

### 6.4 Error handling

Use stable error classes in text and JSON:

```text
CONFIG_MISSING
CONFIG_INVALID
FULL_MODE_SPECANCHOR_MISSING
SOURCE_MISSING
GLOBAL_SPEC_OVER_BUDGET
COMMAND_SEMANTICS_CONFLICT
COVERAGE_MARKDOWN_IGNORED
JSON_INVALID
```

Do not rely only on natural-language error strings.

---

## 7. Acceptance Checklist

Codex must complete this checklist before final response:

### Self-boot

- [x] `.gitignore` no longer ignores all `.specanchor/`.
- [x] `.gitignore` no longer ignores all `/tests/`.
- [x] `.specanchor/global/` has committed minimal Global Specs.
- [x] `.specanchor/modules/` has committed minimal Module Specs.
- [x] `.specanchor/module-index.md` is committed.
- [x] `bash scripts/specanchor-boot.sh --format=json` succeeds in repo root.
- [x] boot JSON parses.

### Tests

- [x] `tests/run.sh` exists.
- [x] `tests/helpers/assert.sh` exists.
- [x] required fixtures exist.
- [x] boot full success test passes.
- [x] boot full missing `.specanchor/` test passes.
- [x] parasitic fixture test passes.
- [x] frontmatter idempotency test passes.
- [x] status JSON test passes.
- [x] doctor tests pass if doctor is implemented.
- [x] resolver tests pass if resolver is implemented.

### CI

- [x] `.github/workflows/ci.yml` exists.
- [x] CI runs on Ubuntu.
- [x] CI runs on macOS.
- [x] CI runs `bash tests/run.sh`.

### Docs/protocol

- [x] command semantics are normalized.
- [x] contradiction around command prefixes is removed.
- [x] README and README_EN are consistent if both mention commands.
- [x] `SKILL.md` remains a valid skill entrypoint.
- [x] detailed extracted files under `references/` are linked from `SKILL.md`.

### Diagnostics

- [x] `scripts/specanchor-doctor.sh --format=json` returns valid JSON.
- [x] doctor detects missing `.specanchor/` in full mode.
- [x] doctor warns on global `*.md` ignore.
- [x] doctor is read-only by default.

### Anchor resolution

- [x] `scripts/specanchor-resolve.sh --format=json` returns valid JSON.
- [x] resolver matches `scripts/**` to `scripts.spec.md`.
- [x] resolver matches `references/**` to `references.spec.md`.
- [x] resolver reports missing module coverage for unknown paths.

### Validation

- [x] `scripts/specanchor-validate.sh` exists or task is explicitly deferred.
- [x] validator checks Global/Module frontmatter basics.
- [x] validator JSON parses if implemented.

---

## 8. Suggested Commit Order

Use this order if making multiple commits:

1. `chore: make repo self-bootable with minimal specanchor specs`
2. `test: add shell fixtures and local test runner`
3. `ci: run shell tests on ubuntu and macos`
4. `docs: normalize command routing semantics`
5. `feat: add specanchor doctor health check`
6. `fix: govern markdown runtime files in coverage config`
7. `refactor: split skill protocol details into references`
8. `feat: add specanchor resolve command`
9. `feat: add minimal specanchor validation`
10. `docs: prepare v0.4.0-alpha changelog`

If one commit is required, keep the same order inside the PR description.

---

## 9. Final Report Format for Codex

When finished, respond with:

```markdown
## Summary

- ...

## Files changed

- ...

## Validation

Commands run:
- `bash scripts/specanchor-boot.sh --format=json`
- `python3 -m json.tool /tmp/specanchor-boot.json`
- `bash tests/run.sh`

Result:
- ...

## Deferred / Blocked

- None
```

If not everything is completed, list the exact remaining checklist items and why.
