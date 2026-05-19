---
specanchor:
  level: task
  task_name: "Handoff Schema Rollout Follow-ups"
  author: "@maintainer"
  created: "2026-05-19"
  status: "in_progress"
  last_change: "起 follow-up batch task spec（simple schema dogfood）"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
  branch: "feat/handoff-schema"
---

# Task: Handoff Schema Rollout Follow-ups

> 本 spec 故意用 `simple` schema：dogfood schema-aware enforce 对 simple schema 不强制 6 段（前一个 task 刚修复的能力）。前任务 §6 列了 10 个 dogfood 卡点 + 4 个 follow-ups——本 task 把可在单会话完成的部分批量推进。

## 目标

把 `2026-05-19_handoff-schema-and-aware-enforce.spec.md` §6 Review 列出的 follow-ups 中"低风险/明确范围"批次落地，并用 4 个未验证 schema 跑 dogfood 矩阵补全数据点。

## 范围

- **In-Scope**:
  - Phase 1: `/goal` × strict gate 协议降级文档化
  - Phase 2: 顶层文档"两类 handoff"术语段
  - Phase 3a/3b/3c: lint warning + ignore-pattern + boot Available Schemas
  - Phase 4: 4 schema fixture 矩阵
  - Phase 5: frontmatter 校验**审计**（不做完整改造）
  - Phase 6: module `last_synced_sha` bump
- **Out-of-Scope**:
  - P1#2 完整 frontmatter schema 校验改造 → 留独立 task spec
  - P2#7 sdd-riper-one §7.2 强制 placeholder（协议已稳定不动）
  - P3#9 Edit/Write 工具偶发问题（外部因素）

## 改动计划

| 文件 | 变更 |
|---|---|
| `references/integrations/goal-hook.md` | 新增——文档化 /goal × strict gate 降级规则 |
| `WHY.md` / `WHY_ZH.md` | 加 §"两类 handoff" 术语段（Follow-up 3） |
| `scripts/specanchor-doctor.sh` | 加 `CC_LINT_SCHEMA_NOT_FOUND` warning + `--ignore-pattern` 选项 |
| `scripts/specanchor-boot.sh` | 加 Available Schemas 段输出 |
| `.specanchor/modules/{references,scripts}.spec.md` | bump `last_synced_sha` |
| 本 spec §备注 | 录 Phase 5 frontmatter audit findings |

## Checklist

- [ ] Phase 1: 写 `references/integrations/goal-hook.md`
- [ ] Phase 2: WHY.md / WHY_ZH.md 加"两类 handoff"术语段
- [ ] Phase 3a: doctor.sh 加 `CC_LINT_SCHEMA_NOT_FOUND` warning
- [ ] Phase 3b: doctor.sh 加 `--ignore-pattern` 选项
- [ ] Phase 3c: boot 加 Available Schemas 段
- [ ] Phase 4: 4 schema fixture（research / refactor / bug-fix / openspec-compat）跑 schema-aware lint，验证 0 issue
- [ ] Phase 5: frontmatter audit（grep + 阅读 validate.sh / frontmatter-inject-and-check.sh），findings 录本 spec §备注
- [ ] Phase 6: bump module `last_synced_sha`（references + scripts）
- [ ] 收尾: 跑 lint 0 issue + spec-index 重生 + commit 拆分

## 完成确认

- [ ] 代码符合 Global Spec
- [ ] Module Spec 已同步更新（last_synced_sha bump）
- [ ] 测试覆盖（4 schema fixture + lint warning 单测）
- [ ] commit 按 scope 白名单拆

## 备注

### Phase 5 Audit Findings — frontmatter 校验现状

读 `scripts/specanchor-validate.sh` 与 `scripts/frontmatter-inject{,-and-check}.sh` 后的判断：

| 层 | 当前能力 | 缺口 |
|---|---|---|
| **validate.sh** | 校验 `level / status / module_path / created / updated / last_synced / allow_missing_module_path` 等通用字段 | **不感知 schema**——不校验 `writing_protocol` / `task_name` / `author` 与 schema 模板的对齐；字段集硬编码 |
| **frontmatter-inject.sh** | 知道 `task_name` / `writing_protocol` / `module_name`；可自动推断 `detect_task_name` / `detect_level` | 单向注入（写不查）；不知道 handoff schema 的独有字段（如 `target_session_window`）；与 schema yaml 没有 source-of-truth 关系 |
| **doctor.sh `lint=context-control`** | 仅检查 6 段 markdown headers | 完全不查 frontmatter 字段名 |

**实证（v0.5-deferred-followup 迁移前的字段漂移）**：旧 spec 使用 `schema:`（非 `writing_protocol:`）、`title:`（非 `task_name:`）、`owner:`（非 `author:`）、`target_version:`（非 `target_session_window:`）—— 所有 4 个错配都没被任何脚本检测到。Lint 静默通过，因为：
1. 6 段 markdown 检查与 frontmatter 字段名正交
2. validate.sh 的硬编码字段集不含这些字段
3. inject.sh 是单向写入，不读检

### 完整修复路线（留独立 task spec，不在本会话）

- **Step A（schema 层）**：每个 schema yaml 增 `frontmatter_fields:` 段，声明字段集（必填 / 可选 / 类型）。e.g.：
  ```yaml
  frontmatter_fields:
    required: [level, task_name, author, created, status, writing_protocol]
    optional: [last_change, related_modules, related_global, branch, target_session_window]
  ```
- **Step B（validate 层）**：`specanchor-validate.sh` 增 `validate_frontmatter_against_schema()`——读取 task 的 `writing_protocol`，加载 schema 的 `frontmatter_fields`，对比 task 实际字段集，输出 `FRONTMATTER_FIELD_UNKNOWN` / `FRONTMATTER_FIELD_MISSING_REQUIRED` warning code。
- **Step C（inject 层）**：`frontmatter-inject.sh` 改为以 schema yaml 为 source of truth，按声明字段集注入；废弃硬编码模板。

修复优先级：**Step A** 最重要（无 source of truth 一切其他都建在沙上）；Step B 次之；Step C 最后。

### Phase 4 dogfood 观察

4 schema fixture（research / refactor / bug-fix / openspec-compat）跑 schema-aware lint：均按预期 0 issue。验证 schema-aware enforce 对所有未声明 context_control 的 schema 一致工作。`--ignore-pattern` 测试场景下也未误隔离（隔离行为通过 Phase 3a CC_LINT_SCHEMA_NOT_FOUND fixture 已独立验证）。

### 已知未在本会话处理的卡点

- **P1#2 完整 frontmatter schema 校验**：见 §Phase 5 Audit 修复路线。要起独立 sdd-riper-one task spec。
- **P2#7 sdd-riper-one §7.2 强制 placeholder**：协议已稳定，不动。
- **P3#9 Edit/Write 工具偶发 file-modified**：外部因素，不在 spec-anchor scope。
