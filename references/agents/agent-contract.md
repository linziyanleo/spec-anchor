# Agent Contract — DEPRECATED

> ⚠️ **v0.6 起本文件 deprecated**。原 7 步 deterministic loop 已拆分为两份：
>
> - **Context utilities**（SpecAnchor 真正提供的能力，对应原步骤 1/2/6）：见 [`references/agents/context-utilities.md`](./context-utilities.md)
> - **SDD-RIPER-ONE workflow**（opt-in 7 步流程，对应原步骤 3/4/5/7）：见 [`references/integrations/sdd-riper-one-flow.md`](../integrations/sdd-riper-one-flow.md)
>
> 拆分原因：SpecAnchor v0.6 重定位为 context construction system，不再以 7 步 deterministic loop 作为默认骨架。Workflow 是 optional integration。详见 `mydocs/idea.md` 附录 F 和 `.specanchor/tasks/_cross-module/2026-05-24_context-system-construction.spec.md`。

本文件保留为 deprecated alias，避免老引用断裂。**新代码 / 新文档不要引用本文件**——按上面两个新文件分流。

---

## 历史 7 步循环（保留为参考）

```
1. Enter Spec Landscape     → 现：Enter Context Landscape（context-utilities.md §1）
2. Resolve Anchors          → 现：Resolve Anchors（context-utilities.md §2）
3. Workflow Selection       → 现：workflow-gates.md（不再默认强制）
4. Schema Gate (if standard) → 现：sdd-riper-one-flow.md §Schema Gate（opt-in）
5. Execute                  → 现：sdd-riper-one-flow.md §Execute（opt-in）
6. Alignment Check          → 现：Alignment Check（context-utilities.md §4）
7. Spec Sediment            → 现：Propose Sediment（context-utilities.md §5；不自动 apply）
```

## Must Never Do（仍然适用）

- 不要跳过 boot
- 不要在 missing context 时凭空发明业务规则
- 不要把 shell script 名称当作用户面的命令语言
- 不要在没有 alignment evidence 的情况下声称工作完成
- **v0.6 新增**：不要让 agent 直接把 finding 写入 Global / Module Spec（必须经 Sediment Proposal + 人审）
