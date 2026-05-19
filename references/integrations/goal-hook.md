# `/goal` Hook Integration

`/goal` 是会话级用户指令——它注册一个 Stop hook，要求 agent **持续推进直到 condition 满足**。当目标条件涉及非平凡实现时，会与 `sdd-riper-one` schema 的 strict gate（`gate.phrase = "Plan Approved"`）冲突——schema 要求等待显式人工批准才能从 PLAN 进 EXECUTE，但 hook 要求不停。

本文档定义这种冲突的协议降级规则，避免每次会话重复推导决策。

## 优先级

按用户全局 `CLAUDE.md` 与 `superpowers:using-superpowers` 显式声明：

```
1. 用户 explicit instructions（CLAUDE.md / 直接指令 / /goal）—— 最高
2. Skill 协议（spec-anchor schema gate / superpowers TDD 等）
3. 默认系统 prompt
```

`/goal` 是 (1)，sdd-riper-one strict gate 是 (2)。**(1) 覆写 (2)**。

## 协议降级规则

当 `/goal` hook 处于 active 状态、且当前 task spec 用 strict schema：

### 降级项

- **Plan gate (`Plan Approved` phrase) 视为 auto-approved**：agent 写完 §4 Plan 后直接推进到 §5 Execute，不阻塞等待用户敲 phrase。
- agent **必须**在 §5.2 Checkpoint Decisions Log 录一条 decision，type = `redirect`，pin = true，标注：
  ```
  - **cp-NN** (YYYY-MM-DD, PLAN→EXECUTE) [redirect, active, pin]
    - rule: "/goal hook active → plan auto-approved；CP 仍停"
    - by: agent (依据 user instructions 优先级)
  ```

### 不降级项（必须保留）

- **Checkpoints (§4.7)**：所有 CP 触发条件仍要 stop 汇报。CP 是协议契约的核心，不被 goal-hook 绕过。Stop hook 检查 condition 时**应判定 CP 触发为合规暂停**，不算"未推进"。
- **Hard Boundaries (§1.2)**：违反触发 Steering Trigger，halt——goal-hook 不能让 agent 越界。
- **commit-msg scope 白名单**：与 gate 无关，正常 enforce。
- **pre-commit lint blocking**：lint 失败仍 abort commit，与 gate 无关。

### 跨 schema 影响

- `simple` / `research` / `handoff` / `bug-fix` / `refactor` / `openspec-compat`：philosophy 已是 `fluid` 或不含 `Plan Approved` 类 gate，`/goal` 与这些 schema 不冲突，无降级需要。
- 仅 `sdd-riper-one`（philosophy=strict）需要本协议处理。

## 用户侧操作

- **取消降级**：用户在任意 turn 回复"halt"或"reject plan"或显式 reset goal（`/goal clear`），agent 回到正常 strict gate。
- **微调 plan**：用户可指出具体段落要改，agent 在 §4 Plan 修订后继续。这不算 reject，仅是 plan 演进。
- **提前完成 condition**：用户可显式说 condition 已达成；hook 自清。

## 向后兼容

无 `/goal` hook 时（普通会话）：行为完全不变——`Plan Approved` 仍是 hard gate，agent 必须停下等用户敲 phrase。

## 历史

本协议规则在 `.specanchor/tasks/_cross-module/2026-05-19_handoff-schema-and-aware-enforce.spec.md` §5.2 cp-01 首次显式记录，并在 §6 Review P1#1 列为应近期解决的 dogfood 卡点。本文档把该决策固化。
