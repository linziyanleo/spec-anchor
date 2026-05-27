# Changelog

## v0.7.0-alpha.2 — Findings Lazy-Load + Summary Field (UNRELEASED)

> 在 v0.7.0-alpha.1 基础上加 finding 装载分级与 summary 必填字段，使 Context Bundle v1 在 finding 数量增长时仍保持 token 边界可控。

### Highlights

- **`summary` 字段成为 finding 必填字段**：≤120 字符单行；主语 + 事实 + 锚点（路径/数字/对比）。`<...>` 占位串会被 `specanchor-finding.sh new` 与 `specanchor-validate.sh` 拒绝。
- **`specanchor-finding.sh new --summary=<text>` 必选参数**：脚本侧硬约束写入时 summary 字段格式正确。
- **`specanchor-validate.sh` 对称二分宽容期**：`status==candidate` 缺字段/超长/占位 fail；`status!=candidate`（accepted / rejected / superseded / archived 与未来新 status）仅 warn——给老仓库迁移窗口而不阻断 CI。
- **`specanchor-assemble.sh` visibility-driven lazy-load**：当 `--format=json --bundle-schema=context_bundle.v1` 且 `--files=` 非空时，扫描 `.specanchor/findings/*.md` 按 `affects.path` / `affects.module` 命中目标文件分级载荷——`immediate→full / sediment_queue→summary / handoff→title`，`hidden` 不进 bundle。
- **`--max-findings=N` 共享桶 cap**（默认 50；`anchor.yaml.findings.max_per_bundle` 项目级覆写；immediate 桶不受 cap）。截断时以 `finding_cap_truncated:` 前缀追加到 `warnings[]` string array（保持 schema 向后兼容）。
- **`specanchor-doctor.sh` summary backfill warn**：非 candidate 状态缺 summary → warn `FINDINGS_SUMMARY_BACKFILL`（建议回填，不阻断）。
- **`scripts/lib/finding-parser.sh`**（新共享库）：`parse_finding_frontmatter()` 被 validate.sh / assemble.sh / doctor.sh 复用，避免三处重复实现。

### Compatibility

- 零破坏：默认 `--bundle-schema=assembly.v1` 不受影响；warnings[] 仍是 string array。
- 老 finding 文件无 summary：候选状态 fail（鼓励 agent 立即补全）；非候选仅 warn（给迁移窗口）。
- `--max-findings` 默认 50 与之前隐含无 cap 行为不同——immediate 桶仍不受 cap，所以 high-priority finding 不会被静默丢弃。

### Not in v0.7.0-alpha.2

- 自动 backfill summary 工具（人手补或后续 PR）
- finding affects 跨模块解析（仍基于 module_path 单值匹配）
- bundle schema v3（warnings[] 升级到 object array）

---

## v0.7.0-alpha.1 — Agent Mode + Stop Triggers + Tool Bootloader (UNRELEASED)

> 在 v0.6 基础上加 agent-facing 入口与 advisory 风险检测，并提供第一份 cross-tool bootloader（Claude Code）。同时把 README / WHY 主叙事切换为 Context Construction System。

### Highlights

- **`specanchor-boot.sh --agent --intent="..."`**：v0.6 plan 里规划但未实现的 agent 入口。等价于直接调用 `specanchor-assemble.sh --intent=... --format=json --bundle-schema=context_bundle.v1`，让 agent 在 session 起步一步拿到 preflight context bundle。可选透传 `--files=` 与 `--bundle-schema=` 参数。
- **`scripts/specanchor-stop-triggers.sh`**（新脚本）：检测 staged 或 diff-against 文件是否命中 advisory stop trigger 路径模式（public_api_change / schema_change / dependency_change / security_path_change）。输出 text 或 JSON（JSON 可被 Context Bundle v1 集成）。**严格 advisory**——不阻断执行；硬阻断由外部 hook / CI 承担。
- **`references/adapters/claude-code-bootloader.md`**（新文档）：第一份 cross-tool bootloader——展示如何在项目 `CLAUDE.md` 中添加最小 SpecAnchor 引导。短小（< 50 行复制片段），把详细协议留给 skill 自身的 references/。Codex AGENTS.md bootloader 留 v0.7+ 候选。
- **README / README_ZH / WHY / WHY_ZH 主叙事切换**：从 "Harness Context Control plane" 改为 "Context Construction System"——明确 SpecAnchor 不拥有 agent execution loop，`sdd-riper-one` 是 opt-in integration。Context 分类从三类扩展为四类（新增 Finding Context）。
- **`mydocs/idea.md` 附录 F**（v0.6 已写）作为本次叙事改写的思想锚点继续保留（gitignored 私有笔记）。

### Compatibility

- 零破坏：所有 v0.6 行为保留（assembly.v1 默认输出 / sdd-riper-one schema / agent-contract.md deprecated alias）
- 新参数（`--agent` / `--intent` / `--files` / `--bundle-schema`）全部 optional
- 老 `specanchor-boot.sh --format=summary|full|json` 行为不变
- README 版本 badge 仍标 0.5.0-beta.1（发布版本号留独立 PR 升）

### Not in v0.7

- Codex `AGENTS.md` bootloader（与 Claude Code bootloader 同结构，留下一批做）
- Cursor / Kiro / Gemini adapter（v1.0+）
- `specanchor-finding.sh list / promote / archive`
- `specanchor-sediment.sh apply`（spec patch 应用逻辑）
- 跨 repo 共享 spec 协议（v1.0+）
- Code freshness / evidence freshness 的完整实现（Bundle v1 只用 time + git mtime）

---

## v0.6.0-alpha.1 — Context Construction System (UNRELEASED)

> 定位回归：从"Harness Context Control plane"改为"Context Construction System"。SpecAnchor 不拥有 agent execution loop。详见 `mydocs/idea.md` 附录 F 与 `.specanchor/tasks/_cross-module/2026-05-24_context-system-construction.spec.md`。

### Highlights

- **SKILL.md 主叙事重写**：从 "Harness Context Control plane" 改为 "Context Construction System for AI coding agents"——明确 SpecAnchor 编译 bounded / auditable / sedimentable context bundle，不拥有 agent loop。
- **`agent-contract.md` 拆分**：原 7 步 deterministic loop 拆成：
  - `references/agents/context-utilities.md`（context 装配 / 记录 / 沉淀工具集）
  - `references/integrations/sdd-riper-one-flow.md`（opt-in 7 步 workflow）
  - 老文件保留为 deprecated alias，避免引用断裂。
- **Findings 独立 artifact**（v0.6 关键能力）：
  - 新目录 `.specanchor/findings/`，每个 finding 是独立 markdown 文件，frontmatter 含 `visibility`（hidden / handoff / sediment_queue / immediate）
  - 跨任务、跨会话引用，不嵌入 task spec
  - 低 confidence / 低 impact finding **不自动归档**（避免过早丢失弱信号）
  - 文档：`references/concepts/findings-ledger.md` + `references/templates/finding-template.md`
- **Sediment Proposal**（hot→cold 安全回流）：
  - 新目录 `.specanchor/sediment/proposals/`，由 `visibility=sediment_queue` 的 finding 触发生成
  - frontmatter 含 `operation`（append / replace / supersede / deprecate / delete / merge）——避免 spec 变成 append-only 垃圾场
  - **不自动 apply 到 spec**——必须人 batch review 后手动应用
  - 文档：`references/concepts/sediment-proposal.md` + `references/templates/sediment-proposal-template.md`
- **Context Bundle JSON v1**（产品核心交付物）：
  - `specanchor-assemble.sh --format=json --bundle-schema=context_bundle.v1` 输出 `specanchor.context_bundle.v1`
  - 新字段：`layers` (spec/decision/evidence/finding/codemap) + `freshness` (fresh/stale/outdated/unknown) + `freshness_reasons` + `source_type` + `confidence`
  - 默认仍 `assembly.v1`，向后兼容
- **两个新 sh 工具**：
  - `scripts/specanchor-finding.sh new` — 生成 finding 骨架，自动派生 visibility
  - `scripts/specanchor-sediment.sh propose` — 从一个或多个 finding 生成 sediment proposal 骨架
- **Lint 扩展**：
  - `specanchor-validate.sh` 校验 findings + sediment proposals frontmatter（含枚举值）
  - `specanchor-doctor.sh` 检查 long-pending `sediment_queue` findings 与 `proposed` proposals
- **`anchor.yaml` 加 `paths.findings` / `paths.sediment_proposals`**，老字段全部保留兼容。

### Workflow Selection（v0.6 新默认）

| Workflow | 何时使用 |
|---|---|
| `⚡ lightweight` | 单文件、小修 |
| `📋 context-only`（**新默认**） | 多文件但不强制阶段门禁；记录 finding / 产生 sediment proposal |
| `🔒 schema-driven`（opt-in） | 高风险 / 审计 / handoff 场景，启用 sdd-riper-one 等 schema |

### Compatibility

- **零破坏**：现有 `anchor.yaml.writing_protocol.schema: sdd-riper-one` 继续工作
- 现有 `specanchor-assemble.sh --format=json` 默认 schema 不变
- 现有 `agent-contract.md` 引用通过 deprecated alias 仍可工作
- v0.6 不引入跨 repo distribution，cross-tool adapter 留待 v0.7

### Not in v0.6

- Schema Router / Autonomy Router（被显式拒绝）
- `boot --agent --intent` 包装 assemble 的实现（计划，未实现）
- Stop trigger 检测脚本（计划，未实现）
- 跨 repo 共享 spec 协议（见 `.specanchor/tasks/_cross-module/2026-05-24_cross-repo-context-management.spec.md`，v1.0+ 候选）
- Cross-tool adapters（Kiro / Cursor / Gemini / Copilot 等；v0.7 仅做 Claude Code + Codex 最小 bootloader）
- `specanchor-finding.sh list` / `specanchor-sediment.sh apply` 等子命令（v0.7+）

---

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
