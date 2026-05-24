# Findings Ledger

> SpecAnchor v0.6 新增：跨阶段、跨会话、独立 artifact 形态的 hot context 写回入口。
>
> 关联：`references/templates/finding-template.md`（模板）/ `references/concepts/sediment-proposal.md`（hot→cold 回流）

---

## 1. 设计动机

强模型在 explore / execute / review 任何阶段都会发现重要事实——但如果没有独立 artifact，这些发现会：

1. 散落在聊天历史，新 session 无法召回
2. 被直接写入 Module / Global Spec，污染长期规范
3. 锁在某个 Task Spec 内，跨任务无法引用

Findings Ledger 解决这三个问题：finding 是**独立文件**，可跨任务、跨会话引用；只能进入 Sediment Proposal、不能直接污染 spec。

## 2. 目录约定

```
.specanchor/findings/
  F-20260524-001-auth-spec-stale.md
  F-20260524-002-retry-already-implemented.md
  F-20260525-001-payment-contract-mismatch.md
```

文件名格式：`F-YYYYMMDD-NNN-<topic-kebab>.md`

- `YYYYMMDD`：发现日期
- `NNN`：当天序号（001 起）
- `<topic-kebab>`：简短主题描述

## 3. Frontmatter Schema

```yaml
---
id: F-20260524-001                                    # 必须，与文件名前 14 字符匹配
type: fact | contradiction | stale-claim | risk | reuse-opportunity | pattern
status: candidate | accepted | rejected | superseded | archived
confidence: low | medium | high
impact: low | medium | high
visibility: hidden | handoff | sediment_queue | immediate  # 控制 review 成本
affects:                                              # 影响范围
  - module: <module-name>          # 或 path: <file-path>，或 contract: <contract-name>
evidence_ref:                                         # 证据引用（可空）
  - type: diff | command | test | file-snapshot
    ref: <git-sha-or-file-or-command>
suggested_target: none | task | module | global | codemap
created: 2026-05-24
updated: 2026-05-24
source_task: <task-spec-path-or-null>                 # 哪个任务过程中发现
---
```

### Type 字段含义

| type | 含义 | 典型例子 |
|---|---|---|
| `fact` | 客观事实发现 | "auth 模块的 session 实际过期时间是 24h 而非文档说的 1h" |
| `contradiction` | spec 与代码 / spec 与 spec 矛盾 | "Global Spec 说用 UTC，Module Spec 写 local time" |
| `stale-claim` | spec 声明已过期 | "API 文档说支持 v1，代码已下线 v1" |
| `risk` | 风险点 | "retry 无 backoff，雪崩风险" |
| `reuse-opportunity` | 可复用机会 | "已有 RetryQueue 类，新代码不必新建" |
| `pattern` | 反复出现的模式 | "三个模块都自实现 idempotency key，应抽公共组件" |

### Visibility 字段（v0.6 关键设计）

控制 finding 的 review 成本，**不是自动归档**：

| visibility | 含义 | 默认触发条件 |
|---|---|---|
| `hidden` | 保留但不打扰：不进 handoff / proposal / 提示 | `confidence=low` 或 `impact=low` |
| `handoff` | 进入 handoff packet summary | `confidence=medium` |
| `sediment_queue` | 进入 Sediment Proposal 候选队列，等 batch review | `confidence=high + evidence + impact>=medium` |
| `immediate` | 立即提示用户，不能等 batch | 触发 stop trigger 的 finding（API/schema/security 类） |

**关键原则**：

- 低 confidence / 低 impact finding **不自动归档**——保留在目录中，由 `specanchor-doctor` 在 N 天后建议（不是自动）归档
- visibility 由 agent 写入时按规则自动赋默认值，但人可以手动调整

## 4. 生命周期

```
candidate (新建)
   │
   ├──→ rejected     (人审拒绝，但保留文件做证据)
   │
   ├──→ accepted     (人审接受 → 可进 Sediment Proposal)
   │       │
   │       └──→ Sediment Proposal generated
   │              │
   │              └──→ Spec Update applied → finding superseded
   │
   ├──→ superseded   (被更新的 finding 取代)
   │
   └──→ archived     (过期或 doctor 建议归档后人确认)
```

**关键不变量**：

- `candidate finding ≠ spec fact`
- `accepted finding ≠ 自动 update global/module spec`
- 只有经 Sediment Proposal + 人审 + `operation` 字段明确后才能 apply 到 spec

## 5. Agent 如何创建 Finding

### 当前阶段（v0.6 初版）

手动按模板创建：

```bash
cp references/templates/finding-template.md \
   .specanchor/findings/F-$(date +%Y%m%d)-001-<topic>.md
# 编辑 frontmatter 和正文
```

### 后续阶段（候选 sh 工具）

可能提供 `specanchor-finding.sh new` 命令，参数化生成 finding 骨架并自动赋 id / created 字段。见 v0.6 实施 plan §Phase 5+。

## 6. Agent 如何消费 Finding

通过 `specanchor-assemble.sh --bundle-schema=v1` 输出的 Context Bundle，findings 作为独立 layer：

```json
{
  "layers": {
    "finding": [
      {
        "path": ".specanchor/findings/F-20260524-001-auth-spec-stale.md",
        "load": "summary",
        "source_type": "finding",
        "freshness": "fresh",
        "confidence": "high"
      }
    ]
  }
}
```

Assembler 按 `inclusion.findings` / `visibility != hidden` / `freshness != outdated` 筛选哪些 finding 进 bundle。

## 7. Handoff 中的 Finding

`specanchor_handoff` 导出 handoff packet 时，hot findings summary 按 visibility 过滤：

- 包含：`visibility=handoff` / `sediment_queue` / `immediate`
- 排除：`visibility=hidden`

## 8. Lint 检查（Phase 5）

`specanchor-validate.sh` 校验：

- frontmatter 字段完整
- 枚举值合法（type / status / confidence / impact / visibility）
- `accepted` finding 必须有 evidence_ref
- `superseded` finding 必须 link 到取代它的 finding（约定字段 `superseded_by`）

`specanchor-doctor.sh` 检查：

- `visibility=sediment_queue` 且超过 N 天未处理 → warn
- `visibility=hidden` 且超过 M 天未更新 → 建议归档（不自动）
- `accepted` finding 引用的 code path 已变更 → freshness 降级警告

## 9. What This is NOT

- **Not a TODO list**：findings 是发现，不是待办——TODO 留在 task spec
- **Not the source of truth**：只有 Spec 是 cold context；finding 是 hot 工作记忆
- **Not auto-applied**：再高 confidence 的 finding 都不能自动改 spec

## 10. 关联文件

- `references/templates/finding-template.md` — 模板
- `references/concepts/sediment-proposal.md` — finding → spec 的安全回流
- `references/agents/context-utilities.md` §3 — Agent 如何写回 finding
- `.specanchor/tasks/_cross-module/2026-05-24_context-system-construction.spec.md` — v0.6 整体 plan
