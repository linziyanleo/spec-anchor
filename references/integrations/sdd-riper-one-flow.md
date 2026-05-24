# SDD-RIPER-ONE Workflow Integration

`sdd-riper-one` 是 SpecAnchor 的 **opt-in workflow integration**——不是默认骨架。当任务属于高风险 / 多模块 / 多人 handoff / 审计场景时显式选择。

> v0.6 重定位：sdd-riper-one 从"默认 schema"降级为"optional integration"。新项目 init 默认 `workflow.default: context-only`，不再默认绑死 7 步 deterministic loop。
>
> 老项目（`anchor.yaml.writing_protocol.schema: sdd-riper-one`）继续兼容工作，不需要迁移。

---

## 何时使用 sdd-riper-one

| 场景 | 推荐 |
|---|---|
| 高风险生产改动 | ✅ |
| 多模块、多天、多参与者任务 | ✅ |
| 外部协作者 / 新人接手 | ✅ |
| 需要审计、handoff、证据链 | ✅ |
| 需求非常明确、实现很小 | ❌（用 context-only 或 lightweight） |
| 强模型探索未知代码库 | ❌（用 context-only + findings ledger） |
| 架构方向不明、需要发现问题 | ❌（用 context-only） |

判定原则：**任务风险 × 不可逆性 × 多人协作**决定是否启用 strict workflow，而不是模型能力。

---

## 7 步流程

```
1. Research        — 读代码、查 spec、识别约束
2. Innovate        — 提出实现方案
3. Plan            — 写明确 checklist
4. [Plan Approved] — Schema Gate：必须停下请人类确认
5. Execute         — 按 Plan 推进，记录 Execution Log
6. Review          — 验证 acceptance criteria，写 Evidence Ledger
7. Spec Sediment   — 评估是否更新 Module / Global Spec
```

### Schema Gate 规则

- 在 `Plan Approved` 之前不能进入 Execute
- 收到用户确认前停下，不要"自我授权"继续
- 严格规则见 `references/workflow-gates.md`

### 与 Context Utilities 的关系

sdd-riper-one 流程的 **Step 1（Research）**和 **Step 6（Review）**与 context utilities 重叠：

| sdd-riper-one 步骤 | 复用的 context utility |
|---|---|
| Step 1 Research | Enter Context Landscape + Resolve Anchors |
| Step 6 Review | Alignment Check + 评估 Sediment |
| Step 7 Spec Sediment | Propose Sediment（生成 Proposal，不自动 apply） |

也就是说：**Context utilities 是公共底座；sdd-riper-one 在底座上额外加 Innovate / Plan / Plan Approved / Execute Log 这几步**。

### Findings 在 sdd-riper-one 中的位置

v0.6 之前：Findings 是 sdd-riper-one §3 的阶段产物（Research Findings 段）。

v0.6 之后：Findings 升级为 **跨阶段独立 artifact**（`.specanchor/findings/`）——可以在 Research / Execute / Review 任何阶段产生。sdd-riper-one Task Spec 中保留 "Related Findings" refs 段引用本任务相关的 finding 文件，不再嵌入 finding 本体。

---

## 启用方式

### 老项目（继续兼容）

```yaml
# anchor.yaml
specanchor:
  writing_protocol:
    schema: sdd-riper-one
```

### 新项目（按需 opt-in）

```yaml
# anchor.yaml
specanchor:
  workflow:
    default: context-only       # v0.6 新默认
    schema: null                # 不强绑 schema
    optional_integrations:
      - sdd-riper-one           # 列出，但不默认启用
```

启动 sdd-riper-one workflow 的任务时：

```bash
specanchor_task --schema=sdd-riper-one --intent="<task>"
```

或者在 anchor.yaml 临时设：

```yaml
workflow:
  schema: sdd-riper-one         # 当前会话改写默认
```

---

## 关联文件

- `references/schemas/sdd-riper-one/schema.yaml` — schema 定义
- `references/schemas/sdd-riper-one/template.md` — task spec 模板
- `references/workflow-gates.md` — Schema Gate 规则
- `references/agents/context-utilities.md` — 公共 context 能力（sdd-riper-one Step 1/6/7 复用）
- `references/concepts/findings-ledger.md` — Findings 独立 artifact 协议（v0.6 新增）
- `references/integrations/sdd-riper-one.md` — schema 接入方式（已存在）
