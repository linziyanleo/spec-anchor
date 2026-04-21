---
specanchor:
  level: task
  type: roadmap-implementation
  status: draft
  schema: simple
  id: TASK-SPECANCHOR-BETA-AGENT-RELIABILITY-001
  title: SpecAnchor v0.4.0-beta — Agent Reliability
  target_milestone: v0.4.0-beta
  priority: P0/P1/P2
  created: 2026-04-21
  owner: codex
  reviewers:
    - maintainer
  base_branch: main
  source_repo: https://github.com/linziyanleo/spec-anchor
---

# SpecAnchor v0.4.0-beta — Agent Reliability Task Spec

## 0. Codex operating instructions

You are working inside the `linziyanleo/spec-anchor` repository.

Treat this file as the implementation TODO list for the `v0.4.0-beta` milestone. Work top-down. Prefer small, reviewable commits. Do not add unrelated product features. Do not introduce network-dependent runtime behavior. Keep SpecAnchor as a pure-text Skill with deterministic Shell helpers.

Before changing files, inspect the current repository state:

```bash
git status --short
git rev-parse --abbrev-ref HEAD
git log --oneline -5
find . -maxdepth 3 -type f | sort
bash -n scripts/*.sh scripts/lib/*.sh tests/run.sh tests/helpers/*.sh
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
```

If any command fails before your work starts, record the baseline failure in your final report and fix only the smallest relevant issue if it blocks this milestone.

## 1. Current baseline assumption

`v0.4.0-alpha.1` has established the trustable core:

- `SKILL.md` is compact and delegates details to `references/`.
- `scripts/specanchor-doctor.sh`, `scripts/specanchor-resolve.sh`, and `scripts/specanchor-validate.sh` exist.
- `scripts/lib/common.sh` exists.
- `tests/` and CI smoke tests exist.
- The repository self-dogfoods through `.specanchor/`.
- `anchor.yaml` is public-repo safe and does not reference maintainer-local paths.

`v0.4.0-beta` must not re-litigate alpha. It should make agents more reliable when deciding **which specs to load, how much context to load, when to stop, and how to explain missing or risky context**.

## 2. Product goal

Make SpecAnchor reliable enough for AI coding agents to use as a deterministic context-governance layer.

The beta goal is:

```text
Given a user task + changed files + repository specs,
SpecAnchor should produce a stable, explainable, budget-aware context plan
that tells an AI agent exactly which Global / Module / Task / external specs to load,
which specs were skipped, which anchors are missing, and what verification gates apply.
```

This is not a memory system. It is a spec-governance system. However, it should borrow proven context-management ideas:

- Keep a lightweight index always available.
- Load detailed files only when relevant.
- Make retrieval decisions explainable.
- Keep context budgets explicit.
- Provide hygiene checks to prevent stale, bloated, or contradictory specs.
- Record enough trace data to reproduce agent decisions.

## 3. Non-goals

Do not implement these in this milestone:

- No vector database.
- No embeddings.
- No network RAG service.
- No MCP server.
- No background daemon.
- No LLM calls from Shell scripts.
- No web UI.
- No automatic mutation of accepted specs without an explicit `--fix` or explicit user/task instruction.
- No attempt to recreate Claude Code Auto Memory. SpecAnchor governs team/project specs, not private user memory.

## 4. Design principles

### 4.1 Deterministic first

All core scripts must work offline and deterministically from repository files.

Intent text can help with scoring, but file paths, module indexes, frontmatter, configured sources, and task specs must dominate anchor selection.

### 4.2 Explainable anchor resolution

Every resolved anchor must include:

- level: `global | module | task | source | codemap`
- path
- load mode: `full | summary | deferred | skipped`
- reason
- match type
- confidence
- freshness or drift status when known

### 4.3 Budget-aware loading

Agents should not blindly load all specs. SpecAnchor must support context plans with budget modes:

```text
compact: minimal startup, summaries preferred
normal: balanced default
full: full matching anchors when safe
```

### 4.4 No silent missing context

If no Module Spec matches changed files, or an external source is unavailable, the agent must see a structured `missing` or `warnings` entry.

### 4.5 Replayable decisions

A user or maintainer should be able to reproduce why an agent loaded a spec by replaying a local command with the same inputs.

## 5. Work package BETA-00 — Milestone setup and version surface

### Required changes

Update project version surfaces from `v0.4.0-alpha.1` to a beta development version where appropriate:

```text
v0.4.0-beta.dev
```

Do not tag `v0.4.0-beta` until all final acceptance checks pass.

Update or create:

```text
.specanchor/tasks/v0.4.0-beta-agent-reliability.spec.md
CHANGELOG.md
README.md
README_ZH.md
docs/release/v0.4.0-beta.md
```

The public README may continue to advertise latest published alpha until beta is released. Internal docs and changelog should clearly mark beta as unreleased.

### Acceptance criteria

```bash
grep -R "v0.4.0-beta" -n CHANGELOG.md docs .specanchor README.md README_ZH.md || true
bash tests/run.sh
```

Expected:

- Beta is represented as unreleased work.
- Published alpha surface is not accidentally overwritten unless intentionally releasing beta.

## 6. Work package BETA-01 — Anchor Resolution v2

### Goal

Upgrade `scripts/specanchor-resolve.sh` from a basic resolver into a stable, explainable, budget-aware anchor resolver.

### Required CLI

Support these forms:

```bash
bash scripts/specanchor-resolve.sh \
  --files "scripts/specanchor-boot.sh,references/commands/check.md" \
  --intent "make boot JSON stable" \
  --budget=normal \
  --format=json

bash scripts/specanchor-resolve.sh \
  --files-from .specanchor/tmp/changed-files.txt \
  --intent-file .specanchor/tmp/task-intent.txt \
  --budget=compact \
  --format=markdown

bash scripts/specanchor-resolve.sh \
  --diff-from=main \
  --budget=normal \
  --format=json
```

If a flag cannot be implemented portably in this milestone, implement the stable subset and document the limitation in `docs/release/v0.4.0-beta.md`.

### Resolution inputs

The resolver should consider these sources, in this order:

1. `anchor.yaml`
2. `.specanchor/module-index.md`
3. `.specanchor/project-codemap.md`
4. `.specanchor/global/*.spec.md`
5. `.specanchor/modules/*.spec.md`
6. `.specanchor/tasks/**/*.spec.md`, if present
7. `anchor.yaml` `sources`, if present
8. file paths from `--files`, `--files-from`, or `--diff-from`
9. task intent text from `--intent` or `--intent-file`

### Matching precedence

Implement deterministic scoring with these match types:

```text
always_global          confidence 1.00
path_prefix            confidence 0.95
frontmatter_applies_to confidence 0.90
frontmatter_key_file   confidence 0.90
module_index_entry     confidence 0.85
source_path_mapping    confidence 0.80
task_spec_recent       confidence 0.75
codemap_area           confidence 0.70
intent_keyword         confidence 0.50
fallback_global_only   confidence 0.30
```

Rules:

- Global Specs are always included in full mode, but load mode depends on budget.
- Module matches from file paths outrank intent matches.
- Intent-only matches must never be the sole reason for a high-confidence module anchor.
- Missing module coverage must be reported, not hidden.
- Duplicate anchors must be collapsed, retaining the strongest reason and all secondary reasons.

### JSON output schema v2

`--format=json` must emit valid JSON with this shape:

```json
{
  "schema_version": "specanchor.resolve.v2",
  "status": "ok|warning|error",
  "mode": "full|parasitic|unknown",
  "budget": {
    "profile": "compact|normal|full",
    "max_files": 12,
    "max_lines": 1200,
    "estimated_files": 5,
    "estimated_lines": 320,
    "truncated": false
  },
  "inputs": {
    "files": ["scripts/specanchor-boot.sh"],
    "intent": "make boot JSON stable",
    "diff_from": null
  },
  "anchors": [
    {
      "level": "global",
      "path": ".specanchor/global/coding-standards.spec.md",
      "load": "summary",
      "match_type": "always_global",
      "confidence": 1.0,
      "reasons": ["Global specs are always considered in full mode"],
      "freshness": "fresh|stale|outdated|unknown"
    }
  ],
  "missing": [
    {
      "type": "module_spec",
      "path": "unknown/path.ts",
      "reason": "No Module Spec matched this file path",
      "suggested_action": "specanchor_infer or specanchor_module"
    }
  ],
  "warnings": [],
  "trace": {
    "config": "anchor.yaml",
    "module_index": ".specanchor/module-index.md",
    "codemap": ".specanchor/project-codemap.md",
    "sources_checked": 0,
    "resolver": "specanchor-resolve.sh"
  }
}
```

### Markdown output

`--format=markdown` must produce a human-readable context plan:

```markdown
# SpecAnchor Resolve Plan

Status: ok
Budget: normal, estimated 5 files / 320 lines

## Anchors to Load
- [global:summary] .specanchor/global/coding-standards.spec.md
  - confidence: 1.00
  - reason: always_global

## Missing Coverage
- unknown/path.ts → no Module Spec matched

## Trace
- config: anchor.yaml
- module_index: .specanchor/module-index.md
```

### Tests

Add fixtures under:

```text
tests/fixtures/agent-reliability/resolve-v2/
```

Cover at least:

1. Global Specs included under all budget profiles.
2. File path resolves to `scripts` Module Spec.
3. File path resolves to `references` Module Spec.
4. Unknown path produces structured missing coverage.
5. Intent-only match is low confidence.
6. Duplicate anchors collapse.
7. Parasitic mode resolves external sources without requiring `.specanchor/modules/`.
8. JSON output parses through Python.
9. Markdown output includes anchors, missing, and trace sections.
10. `--diff-from=main` works in a fixture git repo, or is explicitly documented as deferred.

### Acceptance criteria

```bash
bash scripts/specanchor-resolve.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-resolve.sh --files "unknown/path.ts" --intent "new feature" --budget=compact --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-resolve.sh --files "references/commands/check.md" --intent "fix command docs" --budget=normal --format=markdown >/tmp/specanchor-resolve.md
grep -q "SpecAnchor Resolve Plan" /tmp/specanchor-resolve.md
bash tests/run.sh
```

## 7. Work package BETA-02 — Context Assembly Plan

### Goal

Add a deterministic script that converts resolver output into an agent-ready context assembly plan.

This is the SpecAnchor equivalent of an index-plus-detail loading strategy: the resolver decides what is relevant; the assembler decides how much to load and how to instruct the agent.

### Required script

Create:

```text
scripts/specanchor-assemble.sh
```

### Required CLI

```bash
bash scripts/specanchor-assemble.sh \
  --files "scripts/specanchor-boot.sh" \
  --intent "make boot JSON stable" \
  --budget=normal \
  --format=json

bash scripts/specanchor-assemble.sh \
  --resolve-json /tmp/specanchor-resolve.json \
  --format=markdown
```

### Behavior

The assembler must:

1. Call or consume `specanchor-resolve.sh`.
2. Convert anchors into a context plan.
3. Decide load mode per file based on budget:
   - compact: Global summaries + matched module summaries only.
   - normal: Global summaries + matched Module full content when small.
   - full: Global full + matched Module full, bounded by max line limits.
4. Include missing context warnings.
5. Emit exact file list the agent should read.
6. Emit an Assembly Trace v2 block.

### JSON output schema

```json
{
  "schema_version": "specanchor.assembly.v1",
  "status": "ok|warning|error",
  "budget": {
    "profile": "normal",
    "max_files": 12,
    "max_lines": 1200,
    "estimated_files": 4,
    "estimated_lines": 260,
    "truncated": false
  },
  "files_to_read": [
    {
      "path": ".specanchor/global/coding-standards.spec.md",
      "load": "summary",
      "reason": "global spec under normal budget"
    }
  ],
  "agent_instructions": [
    "Read files_to_read before editing code.",
    "If missing coverage exists, do not invent business rules."
  ],
  "assembly_trace": {
    "global": "summary",
    "module": "full",
    "task": "none",
    "sources": "none",
    "missing": 0
  },
  "warnings": []
}
```

### Markdown output

```markdown
Assembly Trace:
- Global: summary -> .specanchor/global/coding-standards.spec.md
- Module: full -> .specanchor/modules/scripts.spec.md
- Task: none
- Sources: none
- Missing: 0
- Budget: normal, 2 files / 180 estimated lines

Agent Instructions:
1. Read the listed specs before editing code.
2. Do not invent behavior for missing coverage.

Files to Read:
- .specanchor/global/coding-standards.spec.md
- .specanchor/modules/scripts.spec.md
```

### Reference updates

Update:

```text
references/assembly-trace.md
references/script-contract.md
SKILL.md
```

`SKILL.md` must remain compact. Add only a short note that complex coding tasks should use `specanchor-assemble.sh` after boot when file paths or intent are known.

### Tests

Add tests for:

- JSON validity.
- Markdown Assembly Trace presence.
- Budget mode changes load modes.
- Missing coverage warnings flow from resolve to assemble.
- `--resolve-json` input works.

### Acceptance criteria

```bash
bash scripts/specanchor-assemble.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-assemble.sh --files "unknown/path.ts" --intent "new feature" --budget=compact --format=markdown >/tmp/specanchor-assembly.md
grep -q "Assembly Trace" /tmp/specanchor-assembly.md
grep -q "Missing" /tmp/specanchor-assembly.md
bash tests/run.sh
```

## 8. Work package BETA-03 — Agent Profiles and Integration Contracts

### Goal

Make SpecAnchor easy for different coding agents to consume without changing core behavior.

### Required files

Create:

```text
references/agents/
├── agent-contract.md
├── claude-code.md
├── codex.md
├── cursor.md
└── gemini.md
```

### Agent contract content

`references/agents/agent-contract.md` must define:

- Required startup sequence.
- Required pre-edit sequence.
- Required post-edit sequence.
- How to consume `specanchor-boot`, `specanchor-resolve`, `specanchor-assemble`, `specanchor-doctor`, and `specanchor-validate`.
- What an agent must never do.

Minimum contract:

```text
Startup:
1. Run boot.
2. Report Assembly Trace.
3. Do not edit code if boot has blocking errors.

Before editing code:
1. Run assemble with changed files and task intent.
2. Read files_to_read.
3. If missing coverage exists for behavior changes, stop or create a Task Spec.

After editing code:
1. Run relevant tests.
2. Run doctor or validate when specs changed.
3. Report anchors used, files changed, verification, and drift.
```

### Agent-specific files

Each agent file must include:

- Install path examples.
- How to invoke the skill.
- Which commands to run manually if the agent does not run scripts automatically.
- One complete task walkthrough.

Do not include unverified claims about agent-specific proprietary behavior. Mark assumptions clearly.

### README updates

Add a short `Agent Reliability` section that links to these files.

### Tests

Add doc-surface tests that assert links exist from README / README_ZH / SKILL.md to `references/agents/agent-contract.md` and at least Claude Code / Codex / Cursor pages.

### Acceptance criteria

```bash
test -f references/agents/agent-contract.md
test -f references/agents/claude-code.md
test -f references/agents/codex.md
test -f references/agents/cursor.md
grep -R "references/agents/agent-contract.md" -n README.md README_ZH.md SKILL.md
bash tests/run.sh
```

## 9. Work package BETA-04 — Doctor and Validate reliability gates v2

### Goal

Make `doctor` and `validate` act as reliable pre-release and pre-agent gates.

### Doctor enhancements

Update `scripts/specanchor-doctor.sh` to support:

```bash
bash scripts/specanchor-doctor.sh --format=json --profile=agent
bash scripts/specanchor-doctor.sh --format=markdown --profile=release
bash scripts/specanchor-doctor.sh --strict --profile=agent
```

Profiles:

```text
agent: checks runtime safety before an AI coding session
release: checks public release surface
maintainer: checks everything release checks plus local repo hygiene
```

Agent profile checks:

- `anchor.yaml` exists and parses.
- mode is valid.
- required scripts exist.
- resolver and assembler emit valid JSON.
- module-index is readable.
- no non-optional missing sources.
- `SKILL.md` references only existing reference files.
- Assembly Trace reference exists.

Release profile checks:

- README / README_ZH links exist.
- CHANGELOG has unreleased beta section.
- release note exists.
- `.skillexclude` consumer install smoke assumptions hold.
- CI workflow file exists.
- About metadata file exists if project uses `.github/settings.yml`.

Maintainer profile checks:

- current worktree is clean, unless `--allow-dirty`.
- module-index is fresh.
- project-codemap references existing files.
- test fixtures exist.

### Validate enhancements

Update `scripts/specanchor-validate.sh` to validate:

- `anchor.yaml` version and mode.
- Global / Module / Task spec frontmatter.
- Module Spec `module_path` existence or explicit allow-missing field.
- `references/agents/*.md` existence when linked.
- Resolve v2 JSON schema shape.
- Assembly v1 JSON schema shape.

Do not require external JSON schema tools. Use portable Shell plus optional Python JSON parsing where available.

### Tests

Add fixtures for:

- missing referenced file in `SKILL.md`.
- stale module-index.
- invalid resolve JSON.
- invalid assembly JSON.
- release profile missing release note.

### Acceptance criteria

```bash
bash scripts/specanchor-doctor.sh --format=json --profile=agent | python3 -m json.tool >/dev/null
bash scripts/specanchor-doctor.sh --format=markdown --profile=release >/tmp/specanchor-doctor-release.md
bash scripts/specanchor-doctor.sh --strict --profile=agent
bash scripts/specanchor-validate.sh --format=json | python3 -m json.tool >/dev/null
bash tests/run.sh
```

## 10. Work package BETA-05 — Spec Hygiene command

### Goal

Add a hygiene command that prevents spec context decay over time.

This is inspired by periodic cleanup patterns: SpecAnchor should regularly detect bloated indexes, stale specs, dead links, duplicated anchors, and missing summaries. It should not silently rewrite accepted specs by default.

### Required script

Create:

```text
scripts/specanchor-hygiene.sh
```

### CLI

```bash
bash scripts/specanchor-hygiene.sh --format=markdown
bash scripts/specanchor-hygiene.sh --format=json
bash scripts/specanchor-hygiene.sh --fix-generated
```

### Behavior

Default mode is read-only.

Check:

1. `.specanchor/module-index.md` line count and referenced paths.
2. duplicate Module Specs for the same `module_path`.
3. Global Spec size budget.
4. missing or weak Module Spec summaries.
5. dead links in README / README_ZH / WHY / WHY_ZH / SKILL.md / references.
6. old Task Specs that should be archived.
7. specs with conflicting status or supersedes fields.
8. specs that reference files removed from the repo.
9. external sources marked optional but present/missing inconsistently.

`--fix-generated` may update only generated or explicitly safe files:

- `.specanchor/module-index.md`
- generated sections clearly marked as generated
- never accepted specs unless a file is generated-only

### JSON output shape

```json
{
  "schema_version": "specanchor.hygiene.v1",
  "status": "ok|warning|error",
  "summary": {
    "dead_links": 0,
    "duplicate_modules": 0,
    "stale_tasks": 0,
    "oversized_globals": 0
  },
  "findings": [
    {
      "severity": "warning",
      "code": "GLOBAL_TOO_LONG",
      "path": ".specanchor/global/coding-standards.spec.md",
      "message": "Global Spec exceeds recommended line budget",
      "suggested_action": "Move details into a Module Spec or reference file"
    }
  ]
}
```

### Tests

Add fixtures for:

- duplicate module paths.
- dead links.
- oversized global spec.
- stale task spec.
- generated index repair.

### Acceptance criteria

```bash
bash scripts/specanchor-hygiene.sh --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-hygiene.sh --format=markdown >/tmp/specanchor-hygiene.md
grep -q "SpecAnchor Hygiene" /tmp/specanchor-hygiene.md
bash tests/run.sh
```

## 11. Work package BETA-06 — Trace replay and golden outputs

### Goal

Make agent decisions reproducible.

### Required files

Create:

```text
tests/fixtures/agent-reliability/replay/
├── scripts-change.inputs.json
├── scripts-change.resolve.golden.json
├── scripts-change.assembly.golden.json
├── references-change.inputs.json
├── references-change.resolve.golden.json
└── references-change.assembly.golden.json
```

Add a test helper:

```text
tests/helpers/golden.sh
```

### Behavior

Golden tests should:

- Run resolve/assemble with fixture inputs.
- Normalize volatile fields, such as timestamps or absolute paths.
- Compare output to golden files.
- Fail with a helpful diff.

### Trace write option

Add optional trace writing to `specanchor-assemble.sh`:

```bash
bash scripts/specanchor-assemble.sh \
  --files "scripts/specanchor-boot.sh" \
  --intent "debug startup" \
  --write-trace .specanchor/tmp/agent-traces/trace.json \
  --format=json
```

Rules:

- Do not write traces unless `--write-trace` is explicitly passed.
- Default trace directory should be ignored by git.
- Trace output must be valid JSON.

### Acceptance criteria

```bash
bash tests/run.sh
test ! -e .specanchor/tmp/agent-traces/trace.json
bash scripts/specanchor-assemble.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --write-trace .specanchor/tmp/agent-traces/trace.json --format=json >/dev/null
python3 -m json.tool .specanchor/tmp/agent-traces/trace.json >/dev/null
git status --short | grep -v '^?? .specanchor/tmp/' || true
```

## 12. Work package BETA-07 — Agent-facing walkthroughs

### Goal

Document a complete AI coding loop using SpecAnchor.

### Required docs

Create or update:

```text
docs/agent-reliability.md
docs/examples/minimal-agent-loop.md
docs/examples/missing-module-coverage.md
docs/examples/parasitic-source-resolution.md
README.md
README_ZH.md
```

### Required walkthroughs

1. Full-mode project, known file path:
   - boot
   - assemble
   - read files_to_read
   - edit code
   - validate/doctor
   - report anchors used

2. Missing module coverage:
   - assemble reports missing coverage
   - agent should not invent business behavior
   - agent creates Task Spec or suggests Module Spec inference

3. Parasitic source resolution:
   - anchor.yaml points to external specs
   - resolver maps paths to sources
   - assembly trace reports sources-only or source anchors

4. Post-edit verification:
   - run tests
   - run doctor/validate when specs changed
   - include drift report in final answer

### Acceptance criteria

```bash
grep -R "specanchor-assemble.sh" -n README.md README_ZH.md docs references
grep -R "Agent Reliability" -n README.md README_ZH.md docs
bash tests/run.sh
```

## 13. Work package BETA-08 — CI and release gates

### Goal

Make CI prove agent reliability, not only alpha smoke tests.

### Required CI additions

Update `.github/workflows/ci.yml` to include:

```text
agent reliability tests
resolve v2 golden tests
assemble v1 golden tests
doctor agent/release profiles
hygiene read-only check
consumer install assemble smoke
```

Do not make CI depend on network after checkout.

### Suggested CI steps

```yaml
- name: Resolve v2 JSON smoke
  run: bash scripts/specanchor-resolve.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json | python3 -m json.tool >/dev/null

- name: Assembly v1 JSON smoke
  run: bash scripts/specanchor-assemble.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json | python3 -m json.tool >/dev/null

- name: Doctor agent profile
  run: bash scripts/specanchor-doctor.sh --strict --profile=agent

- name: Hygiene read-only
  run: bash scripts/specanchor-hygiene.sh --format=json | python3 -m json.tool >/dev/null
```

### Acceptance criteria

```bash
grep -R "specanchor-assemble.sh" -n .github/workflows/ci.yml
grep -R "specanchor-hygiene.sh" -n .github/workflows/ci.yml
bash tests/run.sh
```

## 14. Work package BETA-09 — Backward compatibility and migration notes

### Goal

Avoid breaking alpha users without guidance.

### Required docs

Update:

```text
docs/release/v0.4.0-beta.md
CHANGELOG.md
docs/INSTALL.md
```

Document:

- New scripts: `specanchor-assemble.sh`, `specanchor-hygiene.sh`.
- Resolve JSON schema changed to v2.
- Existing alpha commands still work.
- Agent profiles are docs/contracts, not separate runtime modes.
- `--budget` defaults.
- Any deferred flags or limitations.

### Acceptance criteria

```bash
grep -R "specanchor.resolve.v2" -n docs CHANGELOG.md references scripts tests
grep -R "specanchor.assembly.v1" -n docs CHANGELOG.md references scripts tests
bash tests/run.sh
```

## 15. Final acceptance checklist

Do not mark this milestone complete until all commands pass locally:

```bash
# Syntax
bash -n scripts/*.sh scripts/lib/*.sh tests/run.sh tests/helpers/*.sh

# Current trustable core
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash scripts/specanchor-doctor.sh --strict --profile=agent
bash scripts/specanchor-validate.sh --format=json | python3 -m json.tool >/dev/null

# Resolve v2
bash scripts/specanchor-resolve.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-resolve.sh --files "unknown/path.ts" --intent "new behavior" --budget=compact --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-resolve.sh --files "references/commands/check.md" --intent "fix command docs" --budget=normal --format=markdown >/tmp/specanchor-resolve.md
grep -q "SpecAnchor Resolve Plan" /tmp/specanchor-resolve.md

# Assembly v1
bash scripts/specanchor-assemble.sh --files "scripts/specanchor-boot.sh" --intent "debug startup" --budget=normal --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-assemble.sh --files "unknown/path.ts" --intent "new behavior" --budget=compact --format=markdown >/tmp/specanchor-assembly.md
grep -q "Assembly Trace" /tmp/specanchor-assembly.md

# Hygiene
bash scripts/specanchor-hygiene.sh --format=json | python3 -m json.tool >/dev/null
bash scripts/specanchor-hygiene.sh --format=markdown >/tmp/specanchor-hygiene.md
grep -q "SpecAnchor Hygiene" /tmp/specanchor-hygiene.md

# Tests and repository cleanliness
bash tests/run.sh
git diff --check
git status --short
```

CI must pass on:

```text
ubuntu-latest
macos-latest
```

## 16. Expected changed-file shape

The final diff will likely include:

```text
.github/workflows/ci.yml
.gitignore
.specanchor/tasks/v0.4.0-beta-agent-reliability.spec.md
CHANGELOG.md
README.md
README_ZH.md
SKILL.md
anchor.yaml
docs/agent-reliability.md
docs/examples/minimal-agent-loop.md
docs/examples/missing-module-coverage.md
docs/examples/parasitic-source-resolution.md
docs/release/v0.4.0-beta.md
references/agents/agent-contract.md
references/agents/claude-code.md
references/agents/codex.md
references/agents/cursor.md
references/agents/gemini.md
references/assembly-trace.md
references/script-contract.md
scripts/specanchor-assemble.sh
scripts/specanchor-hygiene.sh
scripts/specanchor-resolve.sh
scripts/specanchor-doctor.sh
scripts/specanchor-validate.sh
tests/helpers/golden.sh
tests/fixtures/agent-reliability/**
tests/run.sh
```

Exact filenames may differ, but the capabilities and acceptance commands must remain covered.

## 17. Implementation order

Use this order to reduce risk:

1. Add beta task spec and docs placeholders.
2. Upgrade resolve v2 with tests.
3. Add assemble v1 with tests.
4. Add doctor/validate profiles and checks.
5. Add hygiene script.
6. Add golden replay tests.
7. Add agent profile docs.
8. Update README / README_ZH / release notes.
9. Update CI.
10. Run final acceptance checklist.

Commit suggestions:

```text
feat(resolve): add budget-aware anchor resolution v2
feat(assemble): add agent context assembly plan
feat(doctor): add agent and release reliability profiles
feat(hygiene): add read-only spec hygiene checks
feat(docs): add agent reliability profiles and walkthroughs
ci(agent): add beta reliability gates
```

## 18. Codex final response requirements

When finished, respond with:

1. Summary of changes.
2. Files changed.
3. Commands run and results.
4. Exact final acceptance checklist results.
5. Known limitations or deferred flags.
6. Whether CI needs to be triggered manually.

Do not claim beta is ready if any final acceptance command fails.
