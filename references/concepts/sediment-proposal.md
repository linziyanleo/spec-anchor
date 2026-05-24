# Sediment Proposal

> SpecAnchor v0.6 新增：Findings（hot context）→ Spec（cold context）的安全回流中间态。
>
> 关联：`references/concepts/findings-ledger.md`（上游）/ `references/templates/sediment-proposal-template.md`（模板）

---

## 1. 设计动机

如果没有 Sediment Proposal，系统会在两个极端摇摆：

- 极端 A：findings 永远停在 `candidate`，没有沉淀路径 → 工作记忆堆积
- 极端 B：agent 直接把 findings 写入 Module / Global Spec → spec 被未验证发现污染

Sediment Proposal 是中间态：

```
Finding (observation)
  → Evidence (proof)
  → Sediment Proposal (change suggestion)
  → Spec Update (long-term memory, after human review)
```

四者**必须分开**——不能让 finding 直接变 spec、不能让 evidence 直接变 finding、不能让 proposal 自动 apply。

## 2. 目录约定

```
.specanchor/sediment/proposals/
  SP-20260524-001-auth-spec-stale.md
  SP-20260525-002-extract-retry-queue.md
```

文件名格式：`SP-YYYYMMDD-NNN-<topic-kebab>.md`

## 3. Frontmatter Schema

```yaml
---
id: SP-20260524-001
source_findings:                                # 必须，至少 1 个
  - F-20260524-001
target:                                         # 拟更新的 spec 目标
  path: .specanchor/modules/auth.spec.md
  section: "Session invariants"                 # 可空，针对 spec 内某段
operation: append                               # append | replace | supersede | deprecate | delete | merge
supersedes: []                                  # operation=supersede 时列被取代的 section/claim
status: proposed                                # proposed | accepted | rejected | deferred
created: 2026-05-24
updated: 2026-05-24
reviewer: null                                  # batch review 时填
review_decision: null                           # accept | reject | defer | merge-with-edit
---
```

### Operation 字段（v0.6 关键设计，采纳 GPT 反馈）

**不只是 append**——spec 更新可能是多种形态，必须显式声明：

| operation | 含义 | 典型场景 |
|---|---|---|
| `append` | 追加新内容到 target section | 新增 invariant、新增 reuse note |
| `replace` | 替换 target section 内容 | 旧 claim 已过时，整段重写 |
| `supersede` | 标记旧 claim 被新内容取代（保留历史） | 决策演化、版本迁移 |
| `deprecate` | 标记 target section / claim 为 stale，但不删 | 待后续清理的过时规则 |
| `delete` | 删除 target section / claim | 已不适用的规则 |
| `merge` | 合并多个重复 invariant / claim | 多个 finding 指出同一概念 |

**关键原则**：避免长期 spec 变成 append-only 垃圾场。reviewer 必须为每个 proposal 选择合适的 operation。

## 4. 生命周期

```
proposed       (新建，由 visibility=sediment_queue/immediate 的 finding 触发)
   │
   ├──→ rejected   (review 拒绝，保留文件做决策记录)
   │
   ├──→ deferred   (暂缓，下次 batch review 再看)
   │
   └──→ accepted   (review 通过)
          │
          └──→ Spec Update applied
                 │
                 └──→ source findings → status: superseded
                       proposal → archived
```

## 5. 谁能产生 Proposal

### Agent 自动触发

当 finding 满足以下条件时，agent / `specanchor-doctor.sh` 建议生成 proposal：

```text
visibility=sediment_queue
+ status=accepted (或 candidate 但 confidence=high + evidence)
+ suggested_target != none
```

或者：

```text
visibility=immediate
→ 立即生成 proposal 且立即提示用户
```

### 手动创建

```bash
cp references/templates/sediment-proposal-template.md \
   .specanchor/sediment/proposals/SP-$(date +%Y%m%d)-001-<topic>.md
# 编辑 source_findings / target / operation 字段
```

### 后续候选 sh 工具

可能提供 `specanchor-sediment.sh propose <finding-id>` 自动生成 proposal 骨架。见 v0.6 plan §Phase 5+。

## 6. Review 流程

Sediment Proposal **不自动 apply 到 spec**。Review 流程：

```
1. 收集 proposed 状态的 proposal（specanchor-doctor.sh 列出）
2. Batch review（建议 sprint / 周级别）
3. 每个 proposal 决定：
   - accept：apply 到 target spec（按 operation 字段）
   - reject：保留 proposal 文件做决策记录
   - defer：下次 review 再看
   - merge-with-edit：人改 proposal 内容后 accept
4. accepted proposal 触发：
   - source findings 状态变 superseded
   - target spec 按 operation 更新
   - proposal 归档到 .specanchor/sediment/archive/
```

### 接入 GitHub PR 流程

Sediment Proposal 可以作为 PR 的一部分 review：

- PR 中包含 proposal 文件 + 拟应用的 spec diff
- reviewer 同时看 proposal 内容和 spec diff
- merge PR = accept proposal + apply spec update
- 这样 review 已有 git/GitHub workflow 加持，不需要额外 review UI

## 7. 关键不变量

- **proposal 必须有 source_findings**（不能凭空提出 spec change）
- **operation 必须显式选择**（不允许默认 append）
- **status=accepted 之前 spec 文件不被修改**（reviewer 决定才生效）
- **rejected proposal 保留文件**（决策记录，便于追溯）

## 8. Lint 检查（Phase 5）

`specanchor-validate.sh` 校验：

- frontmatter 字段完整
- `source_findings` 列表非空，且每个 finding 文件存在
- `operation` 枚举值合法
- `operation=supersede` 时 `supersedes` 非空

`specanchor-doctor.sh` 检查：

- `proposed` 状态 proposal 超过 N 天未处理 → warn（review 拖延）
- proposal 的 source findings 已 `superseded` 或 `archived` → warn（stale proposal）
- accepted 但 spec 未应用 → warn（执行漏环）

## 9. What This is NOT

- **Not auto-apply machinery**：再高 confidence 的 proposal 都不自动改 spec
- **Not a substitute for finding**：proposal 是变更建议；finding 是发现。一个 finding 可以产生 0/1/多个 proposal
- **Not for ad-hoc spec edits**：如果只是手动改 spec，不需要走 proposal——proposal 是 agent-discovered changes 的安全通道

## 10. 关联文件

- `references/concepts/findings-ledger.md` — Findings（proposal 的上游）
- `references/templates/sediment-proposal-template.md` — 模板
- `references/agents/context-utilities.md` §5 — Propose Sediment utility
- `.specanchor/tasks/_cross-module/2026-05-24_context-system-construction.spec.md` — v0.6 整体 plan
