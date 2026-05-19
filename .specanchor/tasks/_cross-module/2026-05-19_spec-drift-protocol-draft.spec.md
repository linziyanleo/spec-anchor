---
specanchor:
  level: task
  task_name: "Spec↔Spec Drift Protocol Draft"
  author: "@方壶"
  created: "2026-05-19"
  status: "done"
  last_change: "DONE：references/spec-drift-protocol.md 草稿落地（8bf0772）；v0.5-followup Item 4 ✅；implementation 是 v0.6 候选"
  related_modules:
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
---

# Task: Spec↔Spec Drift Protocol Draft

## 目标
落 `references/spec-drift-protocol.md` 草稿，**定义** spec↔spec drift 是什么、按哪些维度检测、用什么策略（静态 vs LLM-assisted）。**不实施检测器**（v0.6 候选）。

## 范围
- **In-Scope**: 写 `references/spec-drift-protocol.md`（维度清单 + 检测策略矩阵 + open questions）
- **Out-of-Scope**: 不实现 `scripts/specanchor-spec-drift.sh`；不改现有 spec↔code drift 算法（`scripts/lib/health.sh`）；不动 anchor.yaml

## 改动计划
| 文件 | 变更说明 |
|------|---------|
| `references/spec-drift-protocol.md` | 新建 |
| `.specanchor/tasks/_cross-module/2026-05-19_v0.5-deferred-followup.spec.md` | Item 4 标 ✅ + link |
| `.specanchor/modules/references.spec.md` | sha bump（commit 之后） |

## Checklist
- [ ] 1. 写 protocol 草稿
- [ ] 2. 更新 v0.5-followup Item 4 标 ✅
- [ ] 3. lint + spec-index regen
- [ ] 4. commit + sha bump

## 完成确认
- [x] 代码符合 Global Spec（无代码改动）
- [ ] Module Spec 已同步更新（references.spec.md sha bump）
- [x] 测试覆盖（不适用，protocol 草稿）

## 备注
- protocol 文档是"定义"层，不是"实施"层——v0.6 实施 task 应起新 sdd-riper-one task spec
- 维度清单按 v0.5-followup §Item 4 列出的 4 候选展开：术语漂移 / 引用链断 / 版本错配 / 概念迁移
- 检测策略矩阵区分静态分析（grep / yaml parser）vs LLM-assisted（embedding 比较 / 语义相似度）
