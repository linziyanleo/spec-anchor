# specanchor_codemap

> **Status**: Draft（v0.5.0-beta.1 deferred Item 2；time-gated 到 ≥ 2026-06-15 才进入实施）。本文件先冻结接口契约，让未来实现按图索骥。

为某个 Task Spec 生成 **task-local codemap**——一份按"读次顺序"组织的上下文文件，列出该 task 涉及的代码入口、跨模块流、外部依赖。Codemap 是 task spec §1.5 字段的 first-class 命令化产物。

**用户可能这样说**: "给这个 task 生成 codemap" / "扫一下这个任务涉及的代码入口" / "生成 task-local 上下文文件"

## 参数

- `task_spec`（必须）: Task Spec 文件路径，如 `.specanchor/tasks/_cross-module/2026-05-XX_<task>.spec.md`
- `--mode=feature|project`（可选，默认 `feature`）: 与 task spec §1.5 `Codemap Mode` 字段对齐
- `--output=<path>`（可选）: codemap 输出路径，默认 `mydocs/codemap/YYYY-MM-DD_hh-mm_<task-name>.md`
- `--write-back`（可选）: 同时把 codemap 路径回写到 task spec §1.5 `Codemap File` 字段

## 输入

- 主：`task_spec` 文件，特别是：
  - §1 Requirements（Goal / In-Scope / Out-of-Scope）
  - §4.1 File Changes（实施目标文件清单）
  - §1.1 Context Sources（已有 design refs 不重复）
- 辅：anchor.yaml `scope_hints` / Module Spec `module_path` 字段（用于路径前缀匹配）

## 输出

`mydocs/codemap/YYYY-MM-DD_hh-mm_<task-name>.md`，结构：

```markdown
# Codemap: <task-name>

> Generated <YYYY-MM-DD hh:mm> by specanchor_codemap for `<task_spec_path>`

## 读次顺序（Read Order）

1. <file:line> — <一句话职责>
2. <file:line> — ...
...

## 入口点 / 架构层（Entry Points / Architecture Layers）

- <file>: <说明>

## 核心逻辑 / 跨模块流（Core Logic / Cross-Module Flows）

- <flow 1>: <from> → <to>
- <flow 2>: ...

## 依赖 / 外部系统（Dependencies / External Systems）

- <dep>: <usage>
```

## 与 specanchor_assemble 的关系

| 维度 | `specanchor_assemble` | `specanchor_codemap` |
|---|---|---|
| 输入 | `--files=<csv>` + `--intent=<text>` | `task_spec` 路径 |
| 输出 | bounded read plan + Assembly Trace（agent context 装配） | task-local codemap 文档（人 + agent 共用） |
| 时机 | 进 EXECUTE 前每轮装配 | task 创建后一次性 / 阶段切换时刷新 |
| 边界 | 不读业务文件 | 可读业务文件提取入口点 |
| 产物寿命 | 单次 prompt | 持久化到 mydocs/codemap/ |

**关系**：补充，不替代。`assemble` 是 per-prompt 的 read plan；`codemap` 是 per-task 的持久化上下文映射，supply assemble 的 `--files` 列表来源。

## 与 mydocs/codemap/ 衔接

- 输出路径默认 `mydocs/codemap/YYYY-MM-DD_hh-mm_<task-name>.md`，与现有手工 codemap 共存（手工的不带时间戳前缀）
- `mydocs/` 在 .gitignore 中——codemap 是 maintainer 本地工作产物，**不被 git 追踪**
- task spec §1.5 `Codemap File` 字段记录路径，让 clean checkout 上的开发者知道要重跑 codemap

## 执行

1. 解析 `task_spec` 提取 §1.Goal / §4.1.File Changes / §1.1.Context Sources
2. 按 `--mode`：
   - `feature` → 仅扫 §4.1 列出的文件 + 直接依赖
   - `project` → 加 §1.Goal 关键词在全仓库 grep 的匹配 + Module Spec 覆盖范围
3. 对每个文件提取 entry point（函数 / class / 配置块顶层 anchor）
4. 计算"读次顺序"：按 entry point 调用图 topo 排序，叶子节点最先读
5. 渲染输出文件
6. 如 `--write-back`：把输出路径写到 task spec §1.5 `Codemap File`

## 退出码
- 0 = ok
- 1 = task_spec 文件缺失或解析失败
- 2 = 参数错误

## 实施时机门控
- **不在 v0.5.0 stable 实施**——time-gated 到 2026-06-15+
- 实施前必须重审本草稿：dogfood 几个 task 后调整字段（如读次顺序算法、project mode 范围）
- 实施 task 应起新 `2026-06-XX_codemap-command-impl.spec.md`（sdd-riper-one schema）

## 设计开放问题（implementation 时回填）

- 读次顺序算法：调用图 topo vs 文件大小排序 vs LLM heuristic？
- entry point 提取：tree-sitter / LSP / 纯 regex？跨语言策略？
- `project` mode 的边界：避免无界扩散
- codemap 与 §1.5 `Codemap File` 字段的双向同步：覆盖 vs append vs version chain？
