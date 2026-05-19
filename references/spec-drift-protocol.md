# Spec↔Spec Drift Protocol

> **Status**: Draft（v0.5.0-beta.1 deferred Item 4；v0.6 候选 implementation）。本文件定义 spec↔spec drift 的语义边界、检测维度、策略矩阵，让未来检测器按图索骥。

## 与已有 drift 检测的关系

| 类型 | 主体 | 已有支持 | 本协议覆盖 |
|---|---|---|---|
| spec↔code | spec vs 当前代码 | ✅ `scripts/lib/health.sh`（FRESH / DRIFTED / STALE / OUTDATED 4 态，基于 `last_synced_sha` vs git log） | — |
| **spec↔spec** | spec vs 其他 spec | ❌ 无 | **本协议** |

spec↔spec drift 描述的是 **spec 自己之间的内在不一致**——而非 spec 与代码的不同步。它最常出现在 Global / Module / Task 三层 Spec 互相引用、相同概念分散在多个 spec 文件、长时间演化中术语悄悄改变这些场景。

## 定义

> **Spec↔Spec Drift**：跨 spec 文件（Global / Module / Task / external sources）的相同对象（术语、概念、引用、版本）出现不一致状态，且该不一致不能被 spec↔code drift 检测器捕获。

四个**互不重叠**的维度（按典型严重程度排序）：

### Dim 1 — 引用链断（Reference Link Rot）

**定义**：spec A 引用 spec B（或 spec B 的某段），但 spec B 已被改名、删除、归档，或目标段落已重命名。

**示例**：
- Task Spec §1.1 `Requirement Source: .specanchor/tasks/.../2026-04-22_foo.spec.md`，但该 task 已 archive 到 `.specanchor/archive/2026-04/...`
- Module Spec 引用 Global Spec 的 `§4 coding-standards`，但 Global Spec 重构后 §4 改名为 `§5 style-guide`
- Spec 中 `[[name]]` 链接的目标 memory 文件被删

**严重性**: 🔴 高（断链让 audit 链失效）。

### Dim 2 — 版本错配（Version Mismatch）

**定义**：跨 spec 同一对象的版本号 / sha / date 字段不一致。

**示例**：
- Module Spec frontmatter `version: 2.3.0` 但 spec 正文 §1 写"v2.4 引入 X 字段"
- Global Spec 称"参考 anchor.yaml v0.5.0-beta.1"，但 anchor.yaml 实际是 v0.5.0
- 两个 Task Spec 都引用同一个 archived task，但一个写 sha=abc123 另一个写 def456

**严重性**: 🟡 中（version drift 通常是手写疏忽，可自动校对）。

### Dim 3 — 术语漂移（Term Drift）

**定义**：跨 spec 对同一概念使用不同术语，或对不同概念误用同一术语。

**示例**：
- Global Spec 说"Spec Landscape"，Module Spec 说"Spec Topology"，Task Spec 说"Spec Map"——三个词指同一对象
- "Checkpoint" 在 sdd-riper-one schema 指 §4.7 CP，在 spec-anchor README 指 git commit milestone
- "Hot/Cold" 在 §5.2 Decisions Log 指 hot_window 窗口，在 §6.2 Evidence Ledger 指 verified vs unverified

**严重性**: 🟡 中（不影响 grep 工具，但损害人 readability + LLM 一致性）。

### Dim 4 — 概念迁移（Concept Migration）

**定义**：跨 spec 同一概念的语义、边界、契约随时间悄悄演变，但旧 spec 未更新追上新定义。

**示例**：
- Module Spec 仍写"`writing_protocol` 字段可选"，但 schema-aware enforce 落地后实际已强制
- Global Spec 写"task spec 必须含 6 段"，但 schema-aware enforce 后 simple/handoff schema 不需要
- Archive 中旧 Task Spec §3 设计"会话内同步 sha"，但当前实际工作流是异步 chore commit

**严重性**: 🔴 高（最隐蔽，但最致命——会让基于旧 spec 的 agent 实施失败）。

## 检测策略矩阵

| 维度 | 静态分析 | LLM-assisted |
|---|---|---|
| 1. 引用链断 | ✅ **首选**：grep `[[name]]` / `: \`<path>\`` / file existence check / heading anchor check | ❌ 过 over-engineer |
| 2. 版本错配 | ✅ **首选**：yaml frontmatter parser + 正文 version regex 对比 | ❌ 不必要 |
| 3. 术语漂移 | 🟡 部分（同义词清单 `references/terminology.yaml` 静态比对） | ✅ **首选**：embedding 相似度聚类 + 异常术语标识 |
| 4. 概念迁移 | ❌ 静态难以捕获 | ✅ **首选**：跨 spec 同概念段对比，LLM 判定语义是否一致 |

**实施建议**：
- v0.6 第一阶段优先实现 Dim 1 + Dim 2（静态分析，性价比最高）
- Dim 3 / Dim 4 留作 v0.6 第二阶段，引入可选 LLM API（如 anchor.yaml `spec_drift.llm_provider`）
- LLM-assisted 模式必须缓存（avoid token cost on every doctor run）+ 可降级（offline 时只跑静态）

## 输出建议

类比 `scripts/lib/health.sh` 的 4 态：

| 状态 | 含义 |
|---|---|
| ✅ COHERENT | 全部维度通过 |
| 🟡 SUSPECT | 1-2 处 Dim 2 / Dim 3 warning（不阻断） |
| 🟠 DRIFTED | 1+ 处 Dim 1 / Dim 4 issue（建议修） |
| 🔴 INCOHERENT | Dim 1 broken link ≥3 或 Dim 4 high-severity ≥1（阻断 release profile） |

## 与 doctor 的集成

提议接口（v0.6 实施时定）：
```
specanchor-doctor.sh --lint=spec-coherence [--scope=global|module|task|all] [--include-archive]
```

类似 `--lint=context-control` 接口模式；输出 `SC_DRIFT_<DIM>_<CODE>` warning code 体系。

## Open Questions

- **Dim 4 LLM cost 控制**：每次 doctor 跑全量 LLM 比对显然不可行——需要 incremental（只比 changed since last_synced_sha）。何时触发全量？
- **terminology.yaml 维护负担**：手写同义词清单容易腐化。是否首次扫描时自动 bootstrap？
- **多 Module / Task 间触发顺序**：Dim 1 引用链断会级联——A→B→C，B 改名时 A 也 stale。检测器是否要做 transitive closure？
- **与 spec↔code drift 的协同**：若一个文件 spec↔code DRIFTED，还要不要再跑 spec↔spec 检测？或合并 verdict 为统一健康度？

## v0.6 implementation 入口

实施 task 应起 `2026-XX-XX_spec-drift-impl.spec.md`（sdd-riper-one schema），按本协议落地 Dim 1+2 → Dim 3 → Dim 4 三阶段。第一个 PR 不应早于 v0.5.0 stable 发布后。
