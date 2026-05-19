---
specanchor:
  level: task
  task_name: "Codemap Command Draft (time-gated implementation)"
  author: "@方壶"
  created: "2026-05-19"
  status: "done"
  last_change: "DONE：references/commands/codemap.md 草稿落地（3328e74）；v0.5-followup Item 2 ✅；implementation time-gated 到 ≥2026-06-15"
  related_modules:
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
---

# Task: Codemap Command Draft

## 目标
落 `references/commands/codemap.md` 命令文档草稿——明确 specanchor_codemap 的输入/输出契约，与 specanchor_assemble / mydocs/codemap/ 的关系。**不实施命令**（time-gated 到 2026-06-15）。

## 范围
- **In-Scope**: 写 `references/commands/codemap.md` 草稿（参考 `commands/load.md` 等现有命令文档风格）
- **Out-of-Scope**: 不实现 `scripts/specanchor-codemap.sh`；不动 task spec template 的 §1.5；不动 `specanchor-assemble.sh`

## 改动计划
| 文件 | 变更说明 |
|------|---------|
| `references/commands/codemap.md` | 新建——参数 / 执行 / 输出 / 关系说明 / 时间门 |
| `.specanchor/tasks/_cross-module/2026-05-19_v0.5-deferred-followup.spec.md` | Item 2 标 ✅ + link |

## Checklist
- [ ] 1. 写 codemap.md 草稿（含 4 要点：输入/输出/与 assemble 关系/与 mydocs 衔接）
- [ ] 2. 更新 v0.5-followup §Items.Item 2 标 ✅
- [ ] 3. spec-index regen
- [ ] 4. commit

## 完成确认
- [x] 代码符合 Global Spec（无代码改动）
- [ ] Module Spec 已同步更新（references.spec.md 需要 bump sha）
- [x] 测试覆盖（不适用，文档草稿）

## 备注
- 文档草稿不会被 doctor lint 强制——但会进 references.spec.md 的 module path scope，可能触发 DRIFTED
- 草稿目录结构按 v0.5-followup §Item 2 4 个要点：1) 输入；2) 输出；3) 与 assemble 关系；4) 与 mydocs/codemap/ 衔接
