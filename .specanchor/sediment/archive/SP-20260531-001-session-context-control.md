---
id: SP-20260531-001
source_findings:
  - F-20260530-001

target:
  path: .specanchor/modules/scripts.spec.md
  section: 2. 业务规则
operation: append
supersedes: []
status: proposed
created: 2026-05-31
updated: 2026-05-31
reviewer: null
review_decision: null
---

# Sediment Proposal: session-context-control

## Source Findings

- [F-20260530-001](../../findings/F-20260530-001-session-context-bloat.md) — same-session boot/assemble re-emits anchors; scripts have no cross-call de-dupe，同一 session 多轮激活线性堆叠重复上下文。

## Proposed Change

向 `scripts.spec.md §2 业务规则` **append** 一条新规则，把「session 上下文加载契约」固化为模块级约束（与既有 §4「无持久化状态」互为表里）：

```diff
  - 幂等安全：重复运行同一脚本不产生副作用
+ - **Session 上下文加载契约（boot / assemble）**：`specanchor-boot.sh` 是 session-start / preflight，
+   同一 session 原则上只运行一次；同 session 内后续上下文刷新优先用 targeted
+   `specanchor-assemble.sh --files=...`，不重复全量 boot。脚本本身保持「无持久化状态」（见 §4）——
+   "已加载" 账本由调用方 / Assembly Trace 在对话内维护、不落盘；脚本只在单次调用内对目标集合去重。
+   已 `full` 加载过的 spec 正文不重复打印，除非目标集合或 freshness 发生变化。
+   该契约为 advisory（不机械阻断），且必须保留 fail-fast 与每次调用 bounded 输出。
```

> 注：本 proposal 只固化 **契约**（cold 约束）。其机械实现（boot `--tasks=open|all|none` 截断、assemble `--budget` 收紧、可选的 stateless delta 模式）属于 scripts.spec.md §3 接口条目的后续变更，由对应 Task Spec 跟踪，不在本 proposal 的 append 范围内。

## Why This Should Become Cold Context

- **稳定性**：这是架构不变量——boot=preflight、脚本无持久化状态——可预见未来不会变，且直接强化既有 §4 约束。
- **广泛适用性**：适用于所有运行时上下文装配脚本（boot / assemble / resolve），不是单脚本特例。
- **不可遗忘性**：若不写入 spec，后续 agent / 人会（a）在每次调用重复全量打印，或（b）为"去重"而给脚本加 session 缓存——后者直接违反 §4 并制造新的 drift 源。F-20260530-001 已经实测到 (a)。

## Evidence

- Finding evidence_ref：`specanchor-boot.sh --format=summary`（每次全量重印 Global summary + 17 active tasks）、`specanchor-assemble.sh --files=...`（6 files / 408 lines，Global summary 重复、references.spec.md full）。
- `scripts/specanchor-assemble.sh:174-184`：仅对单次调用内 `FILES_TO_READ_PATHS` 去重；无持久 / 跨调用缓存。
- `scripts.spec.md §4`：「无持久化状态。脚本间通过文件系统和 stdout 交互」——硬契约，排除脚本自管缓存方案。
- Phase 0 核实（2026-05-31）：P4（install 滞后）与 P3（plugin + skills-manager 双安装）均为本机安装卫生问题，与本加载契约正交，**无需 repo 代码改动**；`skills/spec-anchor/SKILL.md` wrapper 是 plugin 必需入口，不可删。
- 双 agent 评审（dual-agent-review）3 轮收敛 `CONVERGED_APPROVE`：`.specanchor/tasks/agent_review_20260530-234214-pane-p_1-710b/final.md`。

## Risk / Trade-off

- **Advisory，非强制**：契约依赖 agent 自觉，不机械阻断；需硬阻断时应配 hooks / CI（与 context-utilities.md「Not a runtime enforcer」一致）。
- **软约束分散风险**：活契约文案分散在 SKILL.md / agent docs / boot-install 注入块，需保持一致（见 Task Spec R4）。
- 不影响既有 CLI / 输出 shape：本 proposal 只 append 一条业务规则，不改 §3 接口签名。

## Reviewer Decision

> 由 batch review 时 reviewer 填写

- [ ] accept：按 operation 字段 apply 到 target spec
- [ ] reject：拒绝并归档
- [ ] defer：下次 review 再看
- [ ] merge-with-edit：人改 proposal 内容后 accept

Decision rationale: ...
