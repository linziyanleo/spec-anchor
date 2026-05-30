# Assembly Trace

Assembly Trace 用来明确本轮到底读了哪些 Spec，以及读取深度是摘要还是全文。

标准格式：

```text
Assembly Trace:
  - Global: summary|full|none|skipped -> <files or reason>
  - Module: full|summary|deferred|sources-only|none -> <files or reason>
  - Landscape Readiness: 🟢 READY | 🟡 ATTENTION | 🔴 NOT_READY | ⚪ N/A  (boot only)
  - Task: full|summary|none -> <files or reason>
  - Sources: full|summary|none -> <files or reason>
  - Missing: <count>
  - Budget: compact|normal|full, <files> files / <lines> estimated lines
```

语义：

- `summary`：只加载摘要、索引、统计，不注入正文全文。
- `full`：已读取正文全文并纳入上下文。
- `deferred`：本轮尚未加载 Module Spec，等命中路径或模块后再补。
- `sources-only`：parasitic 模式下只从外部 sources 按需读取。
- `skipped`：该层在当前模式下不自动加载。

Landscape Readiness 语义（仅 boot 产出，assemble 不产出）：

- `READY (🟢)`：Global Spec ≥1 + spec-index v3 + 所有模块 FRESH。Agent 可放心编码。
- `ATTENTION (🟡)`：存在 DRIFTED/STALE 模块或 legacy spec-index 格式，但无致命问题。Agent 可编码但建议先处理告警。
- `NOT_READY (🔴)`：无 Global Spec、spec-index 缺失、或存在 OUTDATED 模块。Agent 应先补 Spec 再编码。
- `N/A (⚪)`：parasitic mode，不适用 full-mode 的三维度判定。

规则：

1. 启动检查后先输出一次 Assembly Trace。
2. 如果后续运行了 `specanchor-assemble.sh`，应输出带 `Task` / `Sources` / `Missing` / `Budget` 的 v2 Trace。
3. 如果后续按需加载了新的 Module Spec，必须再输出一次更新后的 Trace。
4. 不要把“读过文件名”伪装成“读过全文”；`summary` 和 `full` 必须分开写。
5. `Landscape Readiness` 行仅由 `specanchor-boot.sh` 产出。`specanchor-assemble.sh` 的 v2 Trace 不包含此行。
6. **Delta-only after first trace（同 session 去重账本）**：Assembly Trace 是本 session 的「已加载」账本。同一 session 内，已经以 `full` 载入的 Spec 正文不要重复打印；后续轮次只声明相对上一条 Trace 的 delta（新增 / 变化的 Spec、freshness 变动），未变化的 Spec 用一行指针带过。仅当目标文件集合或 freshness 发生变化时才重新载入对应正文。`specanchor-boot.sh` 是 session-start / preflight，原则上每 session 一次；同 session 后续刷新优先 targeted `specanchor-assemble.sh`，不重复全量 boot。脚本无持久化状态，账本只活在对话里。
