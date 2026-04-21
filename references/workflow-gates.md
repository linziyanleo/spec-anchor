# Workflow Gates

SpecAnchor 在 full 模式下要先做工作流选择：

- `⚡ 轻量流程`：单文件、小修、预计 < 2 小时，直接执行。
- `📋 <schema>`：多文件、多模块、结构性变更、数据流/API 变更，先创建 Task Spec，再进入实现。

## Strict Gate Rules

对 `philosophy: strict` 的 schema：

1. 先创建 Task Spec。
2. 按 schema 写出阶段产物，而不是只在对话里口头描述。
3. 如果 schema 声明了 gate，例如 `Plan Approved`，必须停下并向用户请求确认。
4. 收到确认前，不进入 Execute。

`philosophy: fluid` 的 schema 没有强制 gate，但仍要保持 Spec 与实现同步。

## Full vs Parasitic

- `full`：允许 `specanchor_task`、`specanchor_module`、`specanchor_global` 等 full-only 操作。
- `parasitic`：只治理外部 sources；命中 full-only 命令时应提示先升级到 full 模式。
