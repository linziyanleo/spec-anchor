---
id: SP-YYYYMMDD-NNN
source_findings:
  - F-YYYYMMDD-NNN
target:
  path: .specanchor/modules/<module>.spec.md
  section: <section-name-or-empty>
operation: append           # append | replace | supersede | deprecate | delete | merge
supersedes: []              # operation=supersede 时列被取代的 section/claim 名
status: proposed            # proposed | accepted | rejected | deferred
created: YYYY-MM-DD
updated: YYYY-MM-DD
reviewer: null              # batch review 时填
review_decision: null       # accept | reject | defer | merge-with-edit
---

# Sediment Proposal: <短描述>

## Source Findings

（链接到 source_findings 列出的每个 finding 文件，简述其核心观察）

- [F-YYYYMMDD-NNN](../../findings/F-YYYYMMDD-NNN-<topic>.md) — <一句话核心观察>

## Proposed Change

（具体改什么——可以是 diff/patch 形式，也可以是描述）

```diff
- (旧内容，如果 operation 是 replace/supersede/delete)
+ (新内容，如果 operation 是 append/replace/merge)
```

或描述形式：

> 在 `<target.section>` 中追加 invariant：...

## Why This Should Become Cold Context

（为什么这是长期 spec 而非临时 finding——证明它的稳定性和广泛适用性）

- 稳定性：（这个规则在可预见的未来不会变 / 已经被反复证实 / 是不可变约束）
- 广泛适用性：（这个规则适用于整个 module / 整个项目 / 跨模块）
- 不可遗忘性：（如果不写入 spec，后续 agent / 人会反复重蹈覆辙）

## Evidence

（关联的 evidence_ref / test 结果 / 命令输出 / git diff）

## Risk / Trade-off

（应用这个变更可能带来的风险或权衡——比如收紧约束可能限制某些场景）

## Reviewer Decision

> 由 batch review 时 reviewer 填写

- [ ] accept：按 operation 字段 apply 到 target spec
- [ ] reject：拒绝并归档
- [ ] defer：下次 review 再看
- [ ] merge-with-edit：人改 proposal 内容后 accept

Decision rationale: ...

---

> **填写指引**（删除此段）：
>
> - **operation 选择**：
>   - 新增内容 → `append`
>   - 整段重写 → `replace`
>   - 旧 claim 被新内容取代（保留历史） → `supersede`（必须填 `supersedes`）
>   - 标记 stale 但暂不删 → `deprecate`
>   - 删除过时规则 → `delete`
>   - 合并多个 finding 指出的同一概念 → `merge`
> - **source_findings** 必须非空——proposal 必须有发现作为依据
> - **status=proposed** 是新建默认。`accepted` 后才能改 spec
> - 提交前删除本"填写指引"段
