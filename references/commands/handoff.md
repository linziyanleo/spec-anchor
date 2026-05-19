# specanchor_handoff

跨 session / new chat 导出当前 Task Spec 的 handoff packet——把 Spec / Decision / Evidence 三类 Context 的 hot 视图凝固成一个简短的指引文档，喂给新 chat 让它从同一个上下文继续工作。

> **概念区分（v0.5.0-beta.2 起）**：spec-anchor 把"handoff"分成两个独立物种——
>
> | 物种 | 物理位置 | 生成方 | 适用场景 | 触发 |
> |---|---|---|---|---|
> | **Task-internal handoff packet** | sdd-riper-one task 内的 §7.2 段 | tool（auto-generated） | **单 task** 跨 session 接力（同一任务换 chat 继续） | **本命令 `specanchor_handoff`** |
> | **Portfolio handoff spec** | 独立 spec 文件（用 `handoff` schema） | author（手写） | **跨 task / 跨 release** roadmap、deferred items 矩阵 | `specanchor_task` + `writing_protocol: handoff` |
>
> 两者**不是替代关系**。本命令仅生成 Task-internal packet。需要 portfolio handoff 时见 `references/schemas/handoff/template.md`。

**用户可能这样说**: "把这个任务交给新 chat 继续" / "导出 handoff packet" / "换个 session 接着做" / "生成 §7.2 handoff" / "做一个跨会话的接手包"

## 参数

- `task-spec`（必填）: Task Spec 文件路径
- `format`（可选）: `text` / `markdown` / `json`（默认 `text`）
- `write-back`（可选）: 是否同时回写到 Task Spec §7.2 区段（默认否）

## 执行

调用 `$SA_SKILL_DIR/scripts/specanchor-assemble.sh --mode=handoff`：

```bash
bash "$SA_SKILL_DIR/scripts/specanchor-assemble.sh" \
  --mode=handoff \
  --task-spec=<path> \
  [--format=text|markdown|json] \
  [--write-back]
```

## Packet 字段（按 spec §7.2 设计）

- **Task**: `name (status: ..., phase: ...)`
- **Spec Landscape**: 列出 task spec frontmatter 的 `related_modules`
- **Active Decisions (hot)**: 当前阶段 hot 段 `cp-NN` 列表——lazy 视图，按 `anchor.yaml.context_control.decision_log` + task frontmatter override（默认 `hot_window=5`、`hot_types=[redirect, rollback, halt]`、`respect_phase=true`）
- **Evidence Status**: `verified / unverified-risk / failed / pending` 计数
- **Read next**: 建议新 chat 优先加载的 files
- **Don't read**: `cold + superseded + withdrawn` 总数（提示新 chat 不要被过期 context 干扰）
- **Next step**: 第一个未完成的 §5 Execute Log 步骤

## 三个使用场景

**1. 跨 session 切换（最常见）**: 当前 session token 接近上限或要切到新 chat 时，运行 `specanchor_handoff` 拿到精炼 handoff packet，粘进新 chat 作为开场白。

**2. 任务交接**: 把任务交给另一位维护者（或 reviewer），handoff packet 给出最关键的 hot 决策 + 当前进度，不需要 reviewer 读完整 Task Spec 几百行。

**3. Audit / status check**: 随时跑一次看看任务现状（hot 决策、evidence 进度），不必滚动浏览 §5.2 / §6.2 大表格。

## 与其他命令的关系

- `specanchor_load`: 通用加载任何 Spec 文件——handoff 是 task 级专用导出
- `specanchor_status`: 项目级覆盖率/健康度摘要——handoff 是 task 级 context summary
- `specanchor_check`: 检测漂移——handoff 不检测，只快照导出
