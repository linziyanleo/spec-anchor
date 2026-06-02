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
summary: <≤120 字符单行：主语 + 事实 + 锚点（路径/数字/对比）>  # v0.6 新增必填
type: fact | contradiction | stale-claim | risk | reuse-opportunity | pattern
status: candidate | accepted | rejected | superseded | archived
confidence: low | medium | high
impact: low | medium | high
visibility: hidden | handoff | sediment_queue | immediate  # 控制 review 成本与 lazy-load tier
affects:                                              # 影响范围
  - module: <module-name>          # 或 path: <file-path>，或 contract: <contract-name>
evidence_ref:                                         # 证据引用（可空）
  - type: diff | command | test | file-snapshot
    ref: <git-sha-or-file-or-command>
suggested_target: none | task | module | global | codemap
failure_class: null                                   # null | bug | spec_gap | noise | contract_ambiguity（可选，v0.7）
created: 2026-05-24
updated: 2026-05-24
source_task: <task-spec-path-or-null>                 # 哪个任务过程中发现
---
```

### Summary 字段（v0.6 新增）

`summary` 是必填字段，控制 lazy-load 行为下 agent 在 sediment_queue / handoff 层看到的内容。

- 长度：≤120 字符单行（不允许换行）
- 内容：主语 + 事实 + 锚点（路径 / 数字 / 对比）
- 占位禁止：`<...>` 占位串会被 `specanchor-finding.sh new` 与 `specanchor-validate.sh` 拒绝（candidate 状态 fail；非 candidate 仅 warn）
- 写作示例：
  - ✓ `auth session TTL: doc=1h, code=24h (auth/session.go:42)`
  - ✓ `RetryQueue already implemented in lib/queue.ts:88; no need to reinvent`
  - ✗ `auth issue`（无锚点）
  - ✗ `<待补充>`（占位串）

**宽容期（symmetric grace period）**：旧的 finding 没有 summary 时，`specanchor-validate.sh` 不会立刻 fail——仅当 `status: candidate` 时 fail，其他 status（accepted / rejected / superseded / archived 与未来新增 status）只 warn。这给老仓库一个迁移窗口而不阻断 CI。

### Type 字段含义

| type | 含义 | 典型例子 |
|---|---|---|
| `fact` | 客观事实发现 | "auth 模块的 session 实际过期时间是 24h 而非文档说的 1h" |
| `contradiction` | spec 与代码 / spec 与 spec 矛盾 | "Global Spec 说用 UTC，Module Spec 写 local time" |
| `stale-claim` | spec 声明已过期 | "API 文档说支持 v1，代码已下线 v1" |
| `risk` | 风险点 | "retry 无 backoff，雪崩风险" |
| `reuse-opportunity` | 可复用机会 | "已有 RetryQueue 类，新代码不必新建" |
| `pattern` | 反复出现的模式 | "三个模块都自实现 idempotency key，应抽公共组件" |

### Failure Class 字段（v0.7 新增，可选）

描述**失败的来源和处置路径**，与 `type`（描述发现形态）正交。不是所有 finding 都有 failure_class——纯 fact / reuse-opportunity 类 finding 通常为 null。

| failure_class | 含义 | 推荐动作 |
|---|---|---|
| `bug` | 实现违反了明确的 spec/contract 条款 | 修 implementation；promote regression test |
| `spec_gap` | spec/contract 遗漏了必要行为 | sediment proposal → 补 contract/template |
| `noise` | 环境 / CI / 工具链无关失败 | 校准 verifier/CI 配置；可标 visibility=hidden |
| `contract_ambiguity` | spec/contract 允许多种有效解释 | refine contract；不要重试 implementation |
| `null` | 不适用或未分类 | 兼容旧 finding（默认值） |

**路由影响**（advisory，不自动执行）：
- `spec_gap` → sediment pipeline 优先候选
- `bug` → 不走 sediment，留在 task scope
- `noise` → 建议 visibility=hidden
- `contract_ambiguity` → 先 refine contract 再重跑

**宽容期**：`failure_class` 为可选字段，缺失或 null 均合法，`specanchor-validate.sh` 不报错。

### Visibility 字段（v0.6 关键设计）

控制 finding 的 review 成本与 lazy-load tier，**不是自动归档**：

| visibility | 含义 | 默认触发条件 | Bundle v1 lazy-load |
|---|---|---|---|
| `hidden` | 保留但不打扰：不进 handoff / proposal / 提示 | `confidence=low` 或 `impact=low` | 不进 bundle |
| `handoff` | 进入 handoff packet summary | `confidence=medium` | `load=title`（仅 id + summary） |
| `sediment_queue` | 进入 Sediment Proposal 候选队列，等 batch review | `confidence=high + evidence + impact>=medium` | `load=summary`（frontmatter summary 字段） |
| `immediate` | 立即提示用户，不能等 batch | 触发 stop trigger 的 finding（API/schema/security 类） | `load=full`（完整 body，不受桶 cap 限制） |

**Lazy-load 触发条件**（详见 `references/agents/context-utilities.md` §2）：仅当 assemble 调用同时具备 `--format=json` + `--bundle-schema=context_bundle.v1` + 非空 `--files=` 目标列表时启用。命中条件：finding `affects.path` 等于目标文件，或 `affects.module` 解析后命中目标文件所在模块。

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

### 推荐方式：`specanchor-finding.sh new`

```bash
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-finding.sh" new \
  --topic="auth-spec-stale" \
  --summary="auth session TTL: doc=1h, code=24h (auth/session.go:42)" \
  --type=stale-claim \
  --confidence=high \
  --impact=medium \
  --suggested-target=module
```

`--summary` 必选；脚本会：

- 自动赋 `id`（`F-YYYYMMDD-NNN`，扫描当日序号）
- 自动派生 `visibility`（按 confidence × impact 默认值）
- 自动写入 `created` / `updated` / `source_task`
- 校验 summary：≤120 字符、单行、无 `<...>` 占位

### 手工方式（仅在脚本不可用时）

```bash
cp references/templates/finding-template.md \
   .specanchor/findings/F-$(date +%Y%m%d)-001-<topic>.md
# 立即编辑 summary 字段——candidate 状态下 specanchor-validate.sh 会因占位串 fail
```

## 6. Agent 如何消费 Finding

通过 `specanchor-assemble.sh --files=<paths> --bundle-schema=context_bundle.v1` 输出的 Context Bundle，findings 作为独立 layer，**按 visibility 分级载荷**：

```json
{
  "layers": {
    "finding": [
      {
        "id": "F-20260524-001",
        "path": ".specanchor/findings/F-20260524-001-auth-spec-stale.md",
        "type": "stale-claim",
        "impact": "medium",
        "visibility": "sediment_queue",
        "affects": [{"module": "auth"}],
        "summary": "auth session TTL: doc=1h, code=24h (auth/session.go:42)",
        "load": "summary",
        "freshness": "fresh",
        "confidence": "high",
        "source_type": "finding"
      }
    ]
  },
  "agent_instructions": [
    "finding load=full means read the entire file body",
    "finding load=summary means use only the frontmatter summary field",
    "finding load=title means treat as bare reminder (id + summary only)"
  ]
}
```

**Lazy-load 流程**（v0.6 主流程）：

1. Agent 调用 `specanchor-assemble.sh --files=src/auth/session.ts --intent="..." --format=json --bundle-schema=context_bundle.v1`
2. Assembler 扫 `.specanchor/findings/*.md`，按 `affects.path` / `affects.module` 命中目标文件
3. 按 visibility 分桶：`immediate` → `load=full`，`sediment_queue` → `load=summary`，`handoff` → `load=title`，`hidden` → 不进 bundle
4. 桶排序：precision（path > module > none） desc → impact desc → created desc
5. 共享桶 cap（默认 50；`--max-findings=N` / `anchor.yaml.findings.max_per_bundle` 覆写）；immediate 桶不受 cap
6. 截断时以 `finding_cap_truncated:` 前缀追加到 `warnings[]`
7. Agent 读 `load=full` 项的完整 body，`load=summary` 项只看 summary 字段，`load=title` 项作为标题级提醒

## 7. Handoff 中的 Finding

`specanchor_handoff` 导出 handoff packet 时，hot findings summary 按 visibility 过滤：

- 包含：`visibility=handoff` / `sediment_queue` / `immediate`
- 排除：`visibility=hidden`

## 8. Lint 检查

`specanchor-validate.sh` 校验：

- frontmatter 字段完整（含 v0.6 必填 `summary`）
- 枚举值合法（type / status / confidence / impact / visibility）
- `summary` 长度 ≤120 字符、单行、无 `<...>` 占位
- `accepted` finding 必须有 evidence_ref
- `superseded` finding 必须 link 到取代它的 finding（约定字段 `superseded_by`）
- **对称二分宽容期**：candidate 状态下缺字段 / 超长 / 占位均 fail；非 candidate（accepted / rejected / superseded / archived 与未来新增 status）仅 warn——给老仓库迁移窗口

`specanchor-doctor.sh` 检查：

- `visibility=sediment_queue` 且超过 N 天未处理 → warn
- `visibility=hidden` 且超过 M 天未更新 → 建议归档（不自动）
- `accepted` finding 引用的 code path 已变更 → freshness 降级警告
- 非 candidate 状态缺 `summary` → warn `FINDINGS_SUMMARY_BACKFILL`（建议回填，但不阻断）

## 9. What This is NOT

- **Not a TODO list**：findings 是发现，不是待办——TODO 留在 task spec
- **Not the source of truth**：只有 Spec 是 cold context；finding 是 hot 工作记忆
- **Not auto-applied**：再高 confidence 的 finding 都不能自动改 spec

## 10. 关联文件

- `references/templates/finding-template.md` — 模板
- `references/concepts/sediment-proposal.md` — finding → spec 的安全回流
- `references/agents/context-utilities.md` §3 — Agent 如何写回 finding
- `.specanchor/tasks/_cross-module/2026-05-24_context-system-construction.spec.md` — v0.6 整体 plan
