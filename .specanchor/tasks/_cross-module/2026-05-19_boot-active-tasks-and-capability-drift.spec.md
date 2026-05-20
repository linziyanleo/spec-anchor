---
specanchor:
  level: task
  task_name: "Boot/Status Active Tasks 段 + Capability Drift 概念草稿"
  author: "@maintainer"
  created: "2026-05-19"
  status: "done"
  last_change: "2026-05-20 收尾：实现已 commit (53c67e1, 3643c9b)，Evidence 回填完成"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "sdd-riper-one"
  branch: "feat/boot-active-tasks"
---

# SDD Spec: Boot/Status Active Tasks 段 + Capability Drift 概念草稿

> Current RIPER Phase: PLAN

## 0. Open Questions
- [x] 是否同时改 status.sh？→ 是。F1 同时困扰两个命令；同一份信息只在 boot 露出会导致 status 体验断层。
- [x] JSON 输出是否同步？→ 是。下游工具（doctor / external integrations）已经在用 JSON。
- [x] Capability Drift 是写代码还是只写概念？→ 本会话只写概念到 `references/concepts/capability-drift.md` + 起独立 follow-up task spec；实现交给下一会话。

## 1. Requirements (Context)
- **Goal**:
  1. boot/status 输出新增 `Active Tasks:` 段，列每个 active task 的 task_name / status / RIPER phase / writing_protocol / path（schema-aware：fluid schema 不显示 phase）
  2. JSON 输出同步加 `active_tasks` 数组
  3. `references/concepts/capability-drift.md` 记录 Capability Drift 概念定义 + 与 Spec/Code Drift 关系
- **In-Scope**:
  - `scripts/specanchor-boot.sh` 增 `boot_active_tasks` 收集 + `emit_active_tasks` 输出 + JSON 段
  - `scripts/specanchor-status.sh` 调用同函数（或抽到 lib/）
  - `references/concepts/capability-drift.md` 加 Capability Drift 概念说明
- **Out-of-Scope**:
  - 真正实现 Capability Drift 检测脚本
  - boot 输出的 Available Schemas 精简（F8）
  - assemble 路径前缀一致化（F4）
  - boot 末尾 Next Suggested Action（F7）—— 这些归入后续 dogfood-driven follow-ups

## 1.1 Context Sources
- Requirement Source: `mydocs/reports/dogfood-notes-2026-05-19.md` §F1 §F2
- Chat/Business Refs: 本 session goal
- Extra Context: `references/integrations/superpowers.md` 配合 superpowers 使用时 active tasks 可见性更重要（多 session 切换风险高）

## 1.2 Hard Boundaries
- 不改 spec-index.md 格式（v3 已稳定）
- 不引入新依赖（纯 bash + sed/awk）
- 不破坏现有 JSON 字段（只追加 `active_tasks`）
- Active Tasks 段在 `task_active=0` 时**不输出**（避免 ATTENTION-grade noise）

## 1.3 Allowed Freedom
- 信息提取实现细节（grep/awk 解析 frontmatter 与 RIPER phase 标记）
- emit 函数所在文件（boot.sh 内 / 抽到 lib/common.sh）
- 列表显示顺序（按 status 优先级 / 按 mtime 倒序）

## 2. Research Findings
- `boot_specanchor_dir()` 第 387-389 行：`B_TASK_ACTIVE` 已经 find 一次 `.specanchor/tasks/**/*.spec.md`，可以在同一循环里读 frontmatter
- frontmatter 字段：`task_name` / `status` / `writing_protocol`；RIPER phase 在 body marker `> Current RIPER Phase: ...`（仅 sdd-riper-one schema 有）
- `scripts/lib/` 已有 `common.sh`，可放共享解析函数
- status.sh 复用 boot.sh 的 collect 函数（已 source common.sh），改造点小

## 2.1 Next Actions
- 在 boot.sh 加 collect_active_tasks 内联到 boot_specanchor_dir
- 加 emit_active_tasks 输出 + JSON 段
- 在 status.sh 调用 emit_active_tasks（或复制相同逻辑——status 已经 source boot.sh 的吗？查看）

## 4. Plan (Contract)

### 4.1 File Changes

| File | Change |
|---|---|
| `scripts/specanchor-boot.sh` | 加 5 个全局数组（titles/statuses/phases/protocols/paths）+ 在 boot_specanchor_dir 内填充 + 加 emit_active_tasks 函数 + JSON 段 active_tasks |
| `scripts/specanchor-status.sh` | 检查能否复用 boot 全局；如不能则复制 emit_active_tasks 调用 |
| `references/concepts/capability-drift.md` | 加 Capability Drift 概念 |
| `mydocs/reports/dogfood-notes-2026-05-19.md` | 已写 |
| `.specanchor/modules/scripts.spec.md` | bump `last_synced_sha` |

### 4.3 Implementation Checklist

- [ ] Step 1: 加全局数组 + boot_specanchor_dir 内读取 task frontmatter 与 RIPER phase
- [ ] Step 2: 加 emit_active_tasks 函数（text 输出）
- [ ] Step 3: 在 output_summary 第 586 行后调用 emit_active_tasks
- [ ] Step 4: JSON 输出加 active_tasks 数组
- [ ] Step 5: 改 status.sh 让其 active_tasks 段同步可见
- [ ] Step 6: 跑 boot/status 验证人眼可读；跑 JSON 验证机器可读
- [ ] Step 7: `references/concepts/capability-drift.md` 加 Capability Drift 概念
- [ ] Step 8: bump module last_synced_sha
- [ ] Step 9: commit 按 scope 拆（feat: boot/status active-tasks / docs: capability-drift / chore: module sha）

### 4.7 Checkpoints — Contract

#### CP-1 boot.sh 改造完成 ✅ pass (2026-05-20)
- Output: boot summary 输出 Active Tasks 段；boot --format=json `active_tasks` 数组含 task_name / status / phase / writing_protocol / path 五字段
- Snapshot evidence: `2026-05-20 11:05 CST` 运行 `boot --format=json` 返回 `task_active=9`
- 实测：第 1 条 `Boot/Status Active Tasks 段...` schema=sdd-riper-one phase=PLAN；`Handoff Schema Rollout Follow-ups` schema=simple 在 text 模式不显示 phase，JSON 模式 `phase` 字段存在且值为空字符串

#### CP-2 status.sh 同步 ✅ pass (2026-05-20)
- Output: status 输出含相同 Active Tasks 段

#### CP-3 全部完成 ✅ pass (2026-05-20)
- Output: doctor --strict ok（无 issue）；validate --strict 在 handoff schema 允许 archive lifecycle 字段后恢复 ok

## 5. Execute Log

- [x] Step 1 — collect_active_tasks 在 boot_specanchor_dir 内填充全局数组（commit 53c67e1）
- [x] Step 2 — emit_active_tasks 文本输出（commit 53c67e1）
- [x] Step 3 — output_summary 调用 emit_active_tasks（commit 53c67e1）
- [x] Step 4 — JSON 输出加 active_tasks 数组（commit 53c67e1）
- [x] Step 5 — status.sh 同步 Active Tasks 段（commit 53c67e1）
- [x] Step 6 — boot/status/json 三种输出人眼+机器实测通过（2026-05-20 dogfood）
- [x] Step 7 — Capability Drift 概念草稿迁入 `references/concepts/capability-drift.md`（commit 1e70cd4 后续收口）
- [x] Step 8 — scripts.spec.md last_synced_sha 已 bump（commit 3643c9b）

## 5.2 Checkpoint Decisions Log

### Recent (active, hot)

- **cp-01** (2026-05-19, PLAN) [decision, active] @§1.2
  - rule: "本 session 不实现 Capability Drift 检测脚本，只写概念到 references/concepts/capability-drift.md"
  - by: agent

### Earlier (audit only)

- (none)

## 6. Review Verdict

- Spec coverage: ✅ 所有 In-Scope 项均落地（boot/status text + JSON + tracked Capability Drift concept + scripts.spec.md sha bump）
- Behavior check: ✅ 三个输出渠道实测，schema-aware 行为正确（fluid schema 在 text 模式不显示 RIPER phase；JSON 模式 `phase` 字段保留为空字符串）
- Regression risk: Low（doctor / validate 恢复 ok）
- Module Spec 需更新: Done — scripts.spec.md `last_synced_sha` bumped at commit 3643c9b
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: No
  - 新发现的项目规则: Active Tasks 可见性是 Spec Landscape 完整性的一部分，应纳入 Landscape Readiness 评估
  - 值得记录的反模式: spec 中的「Phase X Audit Findings」当作真理被后续 task 引用 → 实际工具能力已超越 → 形成 sediment 反向漂移 → 引出 Capability Drift 概念（`references/concepts/capability-drift.md`）


- Follow-ups:
  - (1) ✅ Capability Drift Check 已纳入 sdd-riper-one schema Review Verdict 模板（task #2）
  - (2) 🔲 F3-F10 dogfood findings 批量 task spec（task #3 in_progress）
  - (3) 🔲 spec-anchor-prelude skill 落地（task #1）

## 6.2 Evidence Ledger

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-boot.sh --format=summary` | ✅ ok | Contract: Active Tasks 段输出 schema-aware；Snapshot `2026-05-20 11:05 CST`: `task_active=9` |
| `bash scripts/specanchor-boot.sh --format=json` | ✅ ok | Contract: `active_tasks` 数组五字段齐全；fluid schema `phase` 为空字符串 |
| `bash scripts/specanchor-status.sh` | ✅ ok | Contract: Active Tasks 段同步输出 |
| `bash scripts/specanchor-doctor.sh --strict` | ✅ ok | status=ok 无 issue |
| `bash scripts/specanchor-validate.sh --strict` | ✅ ok | handoff schema 已允许 archived / archive_reason |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| boot summary 输出 Active Tasks 段 | boot summary 输出 | ✅ pass |
| boot --format=json 含 active_tasks 数组 | JSON keys 含 active_tasks；Snapshot `2026-05-20 11:05 CST`: `task_active=9` | ✅ pass |
| status 同步输出 Active Tasks 段 | status 输出 | ✅ pass |
| doctor/validate 不引入新 issue | doctor=ok；validate=ok | ✅ pass |
| schema-aware：fluid schema text 模式不显示 RIPER phase | JSON 中 `phase` 字段保留为空字符串；text 模式不渲染 phase | ✅ pass |

### Unverified Risks

- 大量 task 时（>20）Active Tasks 段会过长；后续可按 status 过滤（draft/review/in_progress only）

### Manual / External Checks Needed

- 在第三方仓库（consumer project）实测 active-tasks 段渲染情况（不在本会话）

### Rollback / Follow-up Handle

- 回滚：单 commit revert `scripts/specanchor-boot.sh` `scripts/specanchor-status.sh` 即可，无 data migration

## 6.3 Capability Drift Check

- [x] 本 spec 中描述的「现状/缺口/已知约束」是否仍然准确？— Yes：dogfood §F1+F2 描述的 boot/status 无 Active Tasks 段已被本 task 修复；§F2 关于 validate.sh 不感知 schema 的 audit finding 已在 [[2026-05-19_handoff-schema-followups]] 中验证为 **stale**（schema-aware 已实现）
- [x] 是否有 audit finding 已被后续代码超越？— Yes：见上一条，引出 `references/concepts/capability-drift.md` 概念草稿
- stale claim 处理：`2026-05-19_handoff-schema-followups.spec.md` §Phase 5 Audit Findings 中 "validate.sh 不感知 schema" 与 "字段集硬编码" 标记 `[stale: superseded by current scripts/specanchor-validate.sh:97-287]`（本 task 不直接修改该 spec，留 follow-up）

## 7.2 Handoff Packet

> 待 specanchor_handoff 生成
