---
specanchor:
  level: task
  task_name: "Meta-Harness 协议提升：failure classification + contract compilation awareness + verification mode"
  author: "@方壶"
  created: "2026-06-02"
  status: "done"
  last_change: "实施完成：6 文件已编辑，validate+doctor 通过，agent 入口 failure_class 可见"
  related_modules:
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
---

# Task: Meta-Harness 协议提升

> 来源：论文 "Meta-Engineering Harnesses for AI-Native Software Production" (2605.25665v1) + Claude/Codex 联合分析
>
> 原则：本轮只改**协议文档和模板**，不动脚本。脚本承接作为后续任务。

## 目标

将论文中三个最具操作性的概念引入 SpecAnchor 协议层：

1. **Finding failure_class** — 失败分类 → 动作映射
2. **Task Spec 两遍 contract 意识** — completeness pass + scope/ambiguity pass
3. **Review Verdict verification_mode** — 验证模式元数据记录

## 范围

- **In-Scope**:
  - `references/concepts/findings-ledger.md` — 增加 failure_class 字段定义
  - `references/templates/finding-template.md` — 增加 failure_class 到 frontmatter
  - `references/agents/context-utilities.md` — 增加 failure_class agent-facing 指引
  - `references/schemas/sdd-riper-one/template.md` — §4 Plan (Contract) 增加两遍 contract checklist
  - `references/schemas/sdd-riper-one/template.md` — §6 Review Verdict 增加 verification_mode 记录
  - `references/schemas/sdd-riper-one/schema.yaml` — 更新 plan/review phase artifact descriptions
  - `.specanchor/modules/references.spec.md` — 同步 module contract
- **Out-of-Scope**:
  - `specanchor-finding.sh` / `specanchor-validate.sh` 脚本修改（→ 后续任务）
  - metrics 汇总脚本（→ 后续任务）
  - specialization registry（→ 后续任务）
  - dual-agent-review independence mode（已放弃）
  - dual-agent-review prompt 修改（→ 独立任务，repo 外文件不可 commit/review）

## 改动计划

### 1. Finding failure_class 字段

| 文件 | 变更说明 |
|------|---------|
| `references/concepts/findings-ledger.md` §3 | 在 frontmatter schema 中增加 `failure_class` 可选字段；增加 §3.x "Failure Class 字段" 说明表 |
| `references/templates/finding-template.md` | frontmatter 增加 `failure_class: null` 行 + 填写指引 |
| `references/agents/context-utilities.md` | agent-facing finding 创建指引中增加 failure_class 紧凑说明 |

**字段定义**：

```yaml
failure_class: null  # null | bug | spec_gap | noise | contract_ambiguity
```

| failure_class | 含义 | 推荐动作 |
|---|---|---|
| `bug` | 实现违反了明确的 spec/contract 条款 | 修 implementation；promote regression test |
| `spec_gap` | spec/contract 遗漏了必要行为 | sediment proposal → 补 contract/template |
| `noise` | 环境 / CI / 工具链无关失败 | 校准 verifier/CI 配置；可标 visibility=hidden |
| `contract_ambiguity` | spec/contract 允许多种有效解释 | refine contract；不要重试 implementation |
| `null` | 不适用或未分类 | （兼容旧 finding） |

**与现有 type 字段的关系**：

- `type` 描述**发现的形态**（fact/contradiction/risk/...）
- `failure_class` 描述**失败的来源和处置路径**
- 两者正交，不冲突。failure_class 是可选字段，null 为默认
- 不是所有 finding 都有 failure_class（纯 fact/reuse-opportunity 类 finding 通常为 null）

**路由影响**（advisory，不自动执行）：

- `failure_class=spec_gap` → sediment pipeline 优先候选
- `failure_class=bug` → 不走 sediment，留在 task scope
- `failure_class=noise` → 建议 visibility=hidden
- `failure_class=contract_ambiguity` → 应先 refine contract，再重跑 implementation

### 2. Task Spec 两遍 Contract Awareness

| 文件 | 变更说明 |
|------|---------|
| `references/schemas/sdd-riper-one/template.md` §4 | 在 §4.1 之前增加 §4.0 Contract Compilation Checklist |
| `references/schemas/sdd-riper-one/schema.yaml` | plan phase artifact description 提及 Contract Compilation Checklist |

**增加内容（§4.0 Contract Compilation Checklist）**：

```markdown
### 4.0 Contract Compilation Checklist

> 两遍 contract 编译意识（参考 Meta-Engineering Harness 的 two-pass compilation）。
> 仅在 Plan 阶段填写；不需要全部满足，但空项需标注"N/A + 原因"。

#### Pass 1: Completeness（是否遗漏了关键约束？）
- [ ] API/UI surface 已列出
- [ ] 状态转移已定义（如有状态机）
- [ ] Invariants 已列出
- [ ] Business rules 已编码（不只是"正确实现"）
- [ ] Auth/data dependencies 已声明
- [ ] Error taxonomy 已列出（不只是 try/catch）
- [ ] Acceptance criteria 可验证

#### Pass 2: Scope & Ambiguity（是否过度指定或歧义？）
- [ ] Out-of-scope 已显式标注
- [ ] 不存在"可被多种方式解读"的条款（或已消歧）
- [ ] 不存在 unsupported requirements（标了但实际无法实现的）
```

### 3. Review Verdict verification_mode

| 文件 | 变更说明 |
|------|---------|
| `references/schemas/sdd-riper-one/template.md` §6 | Review Verdict 增加 verification_mode 记录段 |
| `references/schemas/sdd-riper-one/schema.yaml` | review phase artifact description 提及 Verification Mode Record |

**增加内容（§6 末尾，Review Verdict 下）**：

```markdown
### 6.4 Verification Mode Record

> 记录本次验证的模式，使证据质量可审计（参考 Meta-Engineering Harness 的 independence/attention 二分）。

- Verification regime: independence | attention | mixed | self
  - `independence`: builder 与 verifier 从同一 contract 独立工作，verifier 未看 implementation reasoning
  - `attention`: 同一 agent 或相似 agent 切换 review lens（product/architecture/security/QA）
  - `mixed`: 同时使用了两种（如 dual-agent-review + self-review）
  - `self`: 仅 builder 自检
- Verifier saw implementation reasoning: yes | no | partial
- Review lenses applied: <列出，如 product, architecture, security, QA, spec-completeness>
- Cross-model verification: yes | no（是否使用了不同模型）
- Notes: <可选备注>
```

### 4. Module Spec 同步

| 文件 | 变更说明 |
|------|---------|
| `.specanchor/modules/references.spec.md` | 最小化更新：findings-ledger.md 新增 failure_class、context-utilities.md 新增指引、sdd-riper-one template 新增 §4.0/§6.4、schema.yaml 描述更新 |

## Checklist

- [ ] 1. 更新 `references/concepts/findings-ledger.md` — 增加 failure_class 定义
- [ ] 2. 更新 `references/templates/finding-template.md` — 增加 failure_class 到 frontmatter + 填写指引
- [ ] 3. 更新 `references/agents/context-utilities.md` — 增加 failure_class agent-facing 指引
- [ ] 4. 更新 `references/schemas/sdd-riper-one/template.md` — 增加 §4.0 + §6.4
- [ ] 5. 更新 `references/schemas/sdd-riper-one/schema.yaml` — plan/review artifact descriptions
- [ ] 6. 更新 `.specanchor/modules/references.spec.md` — 同步 module contract
- [ ] 7. Alignment Check — specanchor-check + specanchor-validate 确认无 drift

## 完成确认

- [ ] 代码符合 Global Spec（coding-standards）
- [ ] Module Spec (references.spec.md) 已同步更新
- [ ] 改动均为协议/模板文档，不涉及脚本
- [ ] `specanchor-validate.sh` 不报新错
- [ ] Agent 入口覆盖：context-utilities.md 中 failure_class 可见

## 备注

- 论文来源：Sengupta et al., "Meta-Engineering Harnesses for AI-Native Software Production", arXiv:2605.25665v1, May 2026
- 联合分析：Claude Opus（feature-oriented 分析）+ Codex（architectural 分析）→ 合并视角
- Codex 关键约束：spec-anchor 是 control plane，不是执行引擎；落地顺序为 协议 → 脚本 → metrics
