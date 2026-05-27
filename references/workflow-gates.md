# Workflow Gates

SpecAnchor v0.6 把工作流选择从"二选一（lightweight / standard schema）"扩展为三档：

- `⚡ 轻量流程`：单文件、小修、预计 < 2 小时，直接执行。
- `📋 context-only`（**v0.6 新默认**）：装配 context bundle、按需创建 Task Spec、记录 Finding、产生 Sediment Proposal；不强制阶段门禁。
- `🔒 schema-driven`（opt-in）：用户显式选择 `sdd-riper-one` / `handoff` / `bug-fix` 等 schema，启用相应 phase gate。

> v0.6 重定位：SpecAnchor 不默认拥有 agent execution loop。Workflow 是 optional integration。详见 `mydocs/idea.md` 附录 F。

## 默认选择规则

- 新项目（`anchor.yaml` 含 `workflow.default: context-only` 或缺省 `workflow.schema`）→ context-only
- 老项目（`anchor.yaml.writing_protocol.schema: sdd-riper-one` 等）→ 兼容老行为，按 schema 走
- 用户在意图里显式提到"严格审计 / Plan Approved / RIPER / handoff" → schema-driven

## Strict Gate Rules（仅 schema-driven 模式适用）

对 `philosophy: strict` 的 schema：

1. 先创建 Task Spec。
2. 按 schema 写出阶段产物，而不是只在对话里口头描述。
3. 如果 schema 声明了 gate，例如 `Plan Approved`，必须停下并向用户请求确认。
4. 收到确认前，不进入 Execute。

`philosophy: fluid` 的 schema 没有强制 gate，但仍要保持 Spec 与实现同步。

`philosophy: context-only`（v0.6 引入）没有 schema 概念，只装配 context bundle，由 agent / harness 自己决定怎么用。

## Context-only 工作流（v0.6 主流程）

1. **Boot**：`bash scripts/specanchor-boot.sh --format=json`（或 `--agent --intent="..."` 出 preflight bundle，需后续 PR）
2. **Assemble**：`bash scripts/specanchor-assemble.sh --files=... --intent="..." --bundle-schema=context_bundle.v1 --format=json`
3. **执行**：在 cold context（spec）+ hot context（finding/decision/evidence）约束下编辑代码
4. **记录 Finding**（执行中产生的新发现）：`bash scripts/specanchor-finding.sh new --topic="..." --summary="..." --type=... --confidence=...`（`--summary` 必选；≤120 字符单行）
5. **Alignment Check**：`bash scripts/specanchor-check.sh task <spec-file>` 或 `bash scripts/specanchor-doctor.sh`
6. **Propose Sediment**（如 finding visibility=sediment_queue）：`bash scripts/specanchor-sediment.sh propose --finding=... --target=... --operation=...`
7. **Review Sediment Proposal**：batch review；accept 后人手动 apply 到 spec（不自动）

详见 `references/agents/context-utilities.md`。

## Full vs Parasitic

- `full`：允许 `specanchor_task`、`specanchor_module`、`specanchor_global`、`specanchor_finding`、`specanchor_sediment_propose` 等 full-only 操作。
- `parasitic`：只治理外部 sources；命中 full-only 命令时应提示先升级到 full 模式。
