---
specanchor:
  level: task
  task_name: "单文件 module_path 健康度误判修复"
  author: "方壶"
  created: "2026-04-22"
  status: "draft"
  last_change: "根据 research spec 收敛实现范围，修复单文件 module_path 在 index/check/status 中的误判，并同步文档与测试。"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "simple"
  branch: "main"
---

# Task: 单文件 module_path 健康度误判修复

## 目标
修复存在的单文件 `module_path` 被错误标记为 `STALE` / `invalid module_path` 的问题，并把 `module_path` 的语义在脚本、协议文档和测试中统一为“仓库中的相对路径边界，可为目录或单文件”。

## 范围
- **In-Scope**: `scripts/specanchor-index.sh`、`scripts/specanchor-check.sh`、`scripts/specanchor-status.sh` 的路径存在性与健康度逻辑；`references/commands/module.md`、`references/commands/infer.md`、`references/specanchor-protocol.md`、`references/module-spec-template.md` 的术语对齐；单文件回归测试和 fixture。
- **Out-of-Scope**: 块级 module 建模；`index/status` 健康度逻辑抽共享 helper 的重构；为 `tests/` 新增长期 Module Spec 治理方案。

## 改动计划
| 文件 | 变更说明 |
|------|---------|
| `scripts/specanchor-index.sh` | 允许已存在的文件路径参与健康度计算，不再把单文件路径直接判为 `STALE`。 |
| `scripts/specanchor-check.sh` | 两处 `invalid module_path` 判断改为“仅路径缺失时触发”，存在的文件路径走正常新鲜度计算。 |
| `scripts/specanchor-status.sh` | 汇总健康度时接受单文件 `module_path`，避免把文件路径直接计入 `STALE`。 |
| `references/commands/module.md` | 将“模块目录路径”改为“模块路径（目录或文件）”，对单文件场景给出清晰表述。 |
| `references/commands/infer.md` | 明确单文件 infer 是否支持；若暂不支持，显式写出约束，避免术语先放开但执行语义空心化。 |
| `references/specanchor-protocol.md` | 统一 module 自动加载与管理协议中的路径语义。 |
| `references/module-spec-template.md` | 模板与字段说明对齐为路径级 module。 |
| `tests/test_specanchor_index.bats` | 补单文件 `module_path` 的健康度回归测试。 |
| `tests/test_specanchor_check.bats` | 补单文件 `module_path` 的 module 检查回归测试。 |
| `tests/test_specanchor_status.bats` | 补单文件 `module_path` 的状态汇总回归测试。 |
| `tests/setup_helper.bash` | 支持快速创建单文件 module fixture。 |
| `tests/fixtures/single-file-module/` | 新增可复用的单文件 fixture。 |

## Checklist
- [ ] 1. 修正 research spec 的 5.2 文案，使实现范围包含 `status`。
- [ ] 2. 更新 `index/check/status`，将“路径存在”从目录级放宽到目录或文件，并保留“路径不存在 → invalid”语义。
- [ ] 3. 对齐 `module` / `infer` / protocol / template 中的 `module_path` 术语与边界说明。
- [ ] 4. 增加单文件 fixture 与回归测试，覆盖 `index/check/status` 的核心误判路径。
- [ ] 5. 运行针对性验证，确认单文件路径不再被误报，且无新增格式错误。

## 完成确认
- [ ] 代码符合 Global Spec
- [ ] Module Spec 已同步更新（如有变更）
- [ ] 测试覆盖

## 备注
- 本任务基于 `.specanchor/tasks/_cross-module/2026-04-22_single-file-module-path-health.spec.md` 的 research 结论执行。
- 选择 `simple` schema 是因为本次修复范围已经被 research spec 锁定，且用户要求“修复之后直接开始进行修改”，不适合再引入 strict gate。
- 当前实现会改到 `tests/`，但仓库还没有 `tests` 的 Module Spec；这次先把测试修改作为实现范围显式记录，`tests` 的长期治理可另开 task。
