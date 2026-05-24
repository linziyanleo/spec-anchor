---
specanchor:
  level: task
  task_name: "Context System Construction Plan"
  author: "@方壶"
  created: "2026-05-24"
  status: "draft"
  last_change: "v1: 三轮多模型讨论收敛；v2: 采纳 GPT 反馈，收窄 v0.6 为单仓库 + Hot/Cold 核心 / External 扩展位 / freshness 三源 / stop_trigger advisory|enforceable / finding visibility / sediment operation"
  related_modules: []
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
---

# Plan: Context System Construction

> 来源：2026-05-24 与多个模型（Opus 4.7 / GPT-5.5）三轮讨论收敛的产品方向修订
> 关联：`mydocs/idea.md` 附录 D（需选择性回滚）/ 附录 C / §11.1
> 姊妹文档：`2026-05-24_cross-repo-context-management.spec.md`（跨 repo 上下文方案）

## 0. 核心一句话

**SpecAnchor 为 AI coding agent 编译有边界、可审计、可沉淀的工程上下文。它不拥有 agent 执行循环。**

英文等价表述：

> SpecAnchor compiles bounded, auditable, sedimentable engineering context for coding agents. It does not own the agent loop.

### 0.1 v0.6 范围限定

v0.6 仅承诺**单仓库 + 跨会话 + schema-agnostic** 的 context construction。以下三件事是愿景，**不进 v0.6**：

| 维度 | v0.6 是否承诺 | 何时考虑 |
|---|---|---|
| cross-session | ✅ 是 v0.6 核心 | now |
| cross-tool（adapter） | ❌ 不在 v0.6 | v0.7：Claude Code + Codex 最小 bootloader |
| cross-repository | ❌ 不在 v0.6 | v1.0+：见姊妹文档 `2026-05-24_cross-repo-context-management.spec.md` |

收窄理由：跨仓库会立刻引入 provenance / trust boundary / version pinning / source freshness / repo access control / conflict resolution，比单仓库 findings / bundle / sediment 复杂一个数量级。**先打通单仓库链路**：source → selection → bundle → agent work → findings/evidence → sediment proposal → curated cold context。

## 1. 定位修正

### 1.1 当前内在张力

- `SKILL.md` 自称 "Harness Context Control plane"——但 SpecAnchor 形态是 skill + markdown + shell script，无法真正约束 agent。形容词组合本身拧巴。
- `agent-contract.md` 是 7 步 deterministic loop——这是 Harness 契约，不是 context utility。
- `anchor.yaml` 默认 `writing_protocol.schema: sdd-riper-one`——开箱即默认 Harness。
- 三个矛盾点本质都源于 `mydocs/idea.md` 附录 D.1 引入的"安全放权给 Agent 的规格控制平面"叙事。

### 1.2 修正声明

| 当前 (`mydocs/idea.md` 附录 D.1) | 修订后 |
|---|---|
| "让人类能够安全放权给 Agent 的规格控制平面" | "为 agent 提供它自己 harness 装不下的长期工程记忆" |
| Schema Gate 控盘 | Schema Gate 降级为 optional workflow（仅 strict schema 使用） |
| 7 步 Agent Loop 作为默认契约 | 拆解为 context utility 与 optional workflow |

### 1.3 与 v0.1.0 立场的关系

回归 `mydocs/idea.md` §11.1 "SpecAnchor 是 Spec 文档的 Git，不是 Spec 的 IDE" 的克制定位，叠加 hot context（finding / decision / evidence）能力。

## 2. 附录 D 修订映射表

| 概念 | 当前定位 | 修订后 |
|---|---|---|
| Spec Landscape | 核心术语 | 保留，可考虑改名 Context Landscape |
| Schema Gate | 核心控制点 | 降级为 optional workflow gate（仅 strict schema 使用） |
| Alignment Surface | 规格-代码对齐检测 | 保留，扩展为含 context drift 维度 |
| Spec Sediment | 任务后回流 spec | 保留，新增 Sediment Proposal 中间态（不自动改 spec） |
| 7 步 Agent Loop | 默认契约 | 拆解：步骤 1/2/6 是 context utility；3/4/5/7 归属可选 workflow |
| sdd-riper-one | 默认 schema | 降级为 optional workflow integration |
| "安全放权"叙事 | 顶层愿景 | 替换为"工程记忆"叙事 |
| Layer 0/1/2/3 产品分层 | 隐式架构 | **保留并显式化**（这是附录 D 里最稳的部分） |

## 3. 三类 Context 模型

1. **Hot context（v1 核心）** — finding / decision / evidence。短期、跨阶段、可被 agent 写回。
2. **Cold context（v1 核心）** — spec（global / module / task）/ codemap。长期、人类 curate、稳定。
3. **External context（v1 扩展位）** — 来自其他 repo 或 source 的 spec。**仅保留接入位，v0.6 不做主推**。详见姊妹文档 `2026-05-24_cross-repo-context-management.spec.md`。

转化路径：

- Hot → Cold：通过 Sediment Proposal（不直接污染 spec）
- Cold → assemble 进 Context Bundle 时按 inclusion / budget / freshness 选择性 hot 化

### 3.1 四类工作记忆产物（严格分离）

| 产物 | 性质 | 谁产生 | 谁消费 |
|---|---|---|---|
| **Finding** | 观察 | agent 在 explore / execute / review 中发现 | assembler 装入 bundle；reviewer 评审 |
| **Evidence** | 证明 | agent 跑测试 / 命令的结果 | reviewer 审核 finding / acceptance criteria |
| **Sediment Proposal** | 变更建议 | accepted finding 触发生成 | 人类 batch review |
| **Spec Update** | 长期记忆 | 人接受 Proposal 后应用 | 所有后续 agent session 作为 cold context |

四者必须分开。不能让 finding 直接变 spec、不能让 evidence 直接变 finding、不能让 proposal 自动 apply。

## 4. 应该做的（核心交付物）

### 4.1 Findings 独立 artifact

- 位置：`.specanchor/findings/F-YYYYMMDD-NNN-<topic>.md`
- 不嵌入 task spec
- 跨任务、跨会话引用
- frontmatter:
  ```yaml
  id: F-20260524-001
  type: fact | contradiction | stale-claim | risk | reuse-opportunity | pattern
  status: candidate | accepted | rejected | superseded | archived
  confidence: low | medium | high
  impact: low | medium | high
  visibility: hidden | handoff | sediment_queue | immediate    # 控制 review 成本
  affects: [module / path / contract]
  evidence_ref: [diff / command / test]
  suggested_target: none | task | module | global | codemap
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  source_task: ...
  ```

**visibility 字段（采纳 GPT 修正，替代"自动归档"）**：

| visibility | 含义 | 触发条件 |
|---|---|---|
| `hidden` | 不进 handoff / proposal / 提示，但保留在 findings 目录 | `confidence=low` 或 `impact=low` 默认值；过期由 doctor 建议归档 |
| `handoff` | 进入 handoff packet 摘要 | `confidence=medium` 默认值 |
| `sediment_queue` | 进入 Sediment Proposal Queue 待 batch review | `confidence=high + evidence + impact>=medium` |
| `immediate` | 立即提示用户（不能等 batch） | 触发 stop trigger 的 finding（API/schema/security 类） |

**关键原则**：低置信 finding **不自动归档**——避免过早丢失弱信号。它们以 `hidden` 状态保留在目录中，由 `specanchor-doctor` 在 N 天后建议（不是自动）归档。

### 4.2 Context Bundle JSON v1

升级 `scripts/specanchor-assemble.sh --format=json` 的 schema：

- 新增 `schema_version: specanchor.context_bundle.v1` 输出
- **保留 `specanchor.assembly.v1` 向后兼容**（用 `--bundle-schema=v1` 切换；默认仍是 assembly.v1，给老消费者留迁移期）
- 新增 `layers`：{ spec, decision, evidence, finding, codemap }
- 每个 item 加字段：`load`（summary / full / deferred / manual）+ `freshness` + `freshness_reasons` + `source_type` + `confidence`
- 保留 markdown Assembly Trace 作为 human-readable view（不重写两套渲染）

**Freshness 三源（采纳 GPT 修正，替代单一日期）**：

```text
time freshness:      created / updated age
code freshness:      referenced file hash / git commit / path last modified since finding/spec created
evidence freshness:  test command / validation command / evidence timestamp
```

Bundle 输出示例：

```json
{
  "path": ".specanchor/findings/F-20260520-001-auth-stale.md",
  "freshness": "stale",
  "freshness_reasons": [
    "referenced file src/auth/session.ts changed since finding was created (2026-05-20 → 2026-05-23)",
    "evidence command not rerun after latest diff"
  ]
}
```

v0.6 实现优先级：time freshness 必须；code freshness 用 git 文件 mtime 实现；evidence freshness 留接口、不强求实现。

**boot 与 assemble 共存（采纳 GPT 修正）**：

```text
boot --agent --intent "<intent>"   # session 起步，包装 assemble 输出 preflight bundle
assemble --files ... --intent ...  # 精准上下文（agent 已知目标文件）
boot --format=summary              # 人类概览
assemble --format=json             # agent 执行输入
```

boot 包 assemble，**不取代 assemble**。两者面向不同用户/场景。

### 4.3 Sediment Proposal

位置：`.specanchor/sediment/proposals/SP-YYYYMMDD-<topic>.md`

- 由 `visibility=sediment_queue` 的 finding 触发生成
- **不自动改 module / global spec**
- 接 GitHub PR 流程作为 review surface（每个 proposal 作为独立 PR 或 PR comment）
- 人批量 review 而非 per-finding review，避免 review 地狱

**frontmatter（采纳 GPT 修正，加 operation 字段）**：

```yaml
id: SP-20260524-auth-spec-stale
source_findings:
  - F-20260524-001
target:
  path: .specanchor/modules/auth.spec.md
  section: "Session invariants"
operation: append | replace | supersede | deprecate | delete | merge   # 不只 append
supersedes: []           # 如果 operation=supersede，列被替换的 spec section/claim
status: proposed | accepted | rejected | deferred
created: 2026-05-24
```

正文结构：

```markdown
## Proposed Change
（具体改什么——可以是 diff/patch 形式，也可以是描述）

## Evidence
（关联的 evidence_ref / test 结果 / 命令输出）

## Why This Should Become Cold Context
（为什么这是长期 spec 而非临时 finding——证明它的稳定性和广泛适用性）

## Reviewer Decision
- accept / reject / defer
- 如果 accept：是 merge as-is / edit and merge / supersede existing section / 其他
```

**关键原则**：Spec 更新不一定是 append。可能是 replace（替换旧 claim）/ supersede（标记被取代）/ deprecate（标记 stale）/ delete（删除过时规则）/ merge（合并重复 invariant）。避免 spec 变成 append-only 垃圾场。

**默认沉淀策略（与 4.1 visibility 字段联动）**：

| Finding 状态 | 处置 |
|---|---|
| `visibility=hidden` | 不进 proposal；过期由 doctor 建议归档 |
| `visibility=handoff` | 进 handoff summary；不主动建 proposal |
| `visibility=sediment_queue` | 触发生成 Sediment Proposal，进 batch review queue |
| `visibility=immediate` | 触发生成 Sediment Proposal **且** 立即提示用户 |

### 4.4 拆 `references/agents/agent-contract.md`

拆成两份：

- `references/agents/context-utilities.md`（SpecAnchor 提供的 context 能力）
  - boot project context
  - assemble context bundle
  - explain assembly trace
  - detect stale / missing context
  - record finding / evidence
  - propose sediment
- `references/integrations/sdd-riper-one-flow.md`（可选 workflow）
  - Research → Innovate → Plan → Execute → Review
  - Plan Approved gate
  - Checkpoint decisions
  - Evidence ledger（已有部分迁移）

### 4.5 `anchor.yaml` 加 `context` + `workflow` 段

当前 `context_control` 段实际是 lint / enforce 配置。**新增两个段**：

```yaml
# v0.6 新增：context 段（构建上下文）
context:
  layers:
    hot:
      - findings
      - decisions
      - evidence
    cold:
      - specs
      - codemap
    external:
      enabled: false           # v0.6 仅保留扩展位
  inclusion:
    global: always
    module: fileMatch
    decision: hot
    evidence: hot
    findings: hot
    codemap: intentMatch
  budget:
    default_profile: normal    # compact | normal | full
    max_files: 12
    max_lines: 1500
    auto_downgrade: true
  staleness:
    fresh_days: 14
    stale_days: 30
    outdated_days: 90
    use_code_freshness: true   # 用 git mtime 增强 time staleness
    use_evidence_freshness: false  # v0.6 留接口，不强求
  exclusions:
    - "mydocs/**"

# v0.6 新增：workflow 段（默认 context-only，不再默认 Harness）
workflow:
  default: context-only         # 采纳 GPT 修正：不是 null，是 context-only
  schema: null                  # 老字段保留，但新项目 init 默认置 null
  optional_integrations:
    - simple
    - sdd-riper-one
    - handoff
    - bug-fix
    - refactor
    - research
```

保留旧 `context_control` / `enforce` / `pre_commit` / `writing_protocol.schema` 字段做兼容（老项目继续工作），但顶层叙事用新段。

**新项目 init 默认生成 `workflow.default: context-only` + `workflow.schema: null`**——避免新用户被强绑定 sdd-riper-one。

### 4.6 SKILL.md 主叙事重写

第一段从 "Harness Context Control plane + 三级 Spec + Schema Gate ..." 改为：

> SpecAnchor compiles bounded, auditable, sedimentable engineering context for coding agents. Specs, decisions, evidence, and findings are the layers; context bundles are the product. Workflow schemas are optional integrations. SpecAnchor does not own the agent loop.

### 4.7 Stop Trigger 区分 advisory / enforceable（采纳 GPT 修正）

SpecAnchor 自身只能产生 **advisory** stop trigger（warning）；真正阻断执行必须由外部 hook / CI / pre-commit / agent harness 承担。

```yaml
stop_triggers:
  advisory:                    # SpecAnchor 自己能检测的
    - public_api_change        # api/ schema/ openapi/ 路径变更
    - schema_change            # db/migrations/ 路径变更
    - dependency_change        # package.json/Cargo.toml/go.mod/requirements.txt 变更
    - security_path_change     # auth/ security/ privacy/ 路径变更
    - verification_failed_twice
    - missing_module_spec_for_behavior_change
    - spec_code_contradiction
  enforceable:                 # 需要外部接入
    - configured_hook          # 用户配置的 git hook
    - ci_policy                # CI pipeline policy
    - pre_commit_block         # pre-commit 阻断
```

Bundle 输出里每个 trigger 必须标 `mode`：

```json
{
  "type": "schema_change",
  "severity": "high",
  "mode": "advisory",          // 永远诚实地标记
  "reason": "changed files under db/migrations/",
  "enforcement_hint": "consider wiring pre-commit hook or CI check"
}
```

**语义诚实原则**：SpecAnchor 不声称自己能"硬约束 agent"。文档与脚本输出都必须明确：advisory = 警告/建议，不阻断。

## 5. 不应该做的（明确边界）

| 项目 | 不做的理由 |
|---|---|
| Schema Router / Autonomy Router | risk 自评是漂移源；按 intent 字符串猜风险不可靠 |
| 新增 adaptive-discovery-one 作为默认 schema | 用户已表态不强绑定 schema；新 schema 应是 opt-in，不作为默认 |
| Context Graph（System→Repo→Module→Symbol 多层节点 + 横向 API/Event 节点） | over-engineering；多数项目只需 2-3 层 |
| 角色化 bundle 默认（architect / implementer / reviewer / release） | 暂无真实用户用例；先做一个默认 profile，按需扩展 |
| 多工具 adapter（Kiro / Cursor / Gemini / Copilot） | 每个 adapter 是 staleness 源；只维护 Claude Code + Codex 最小 bootloader |
| Hard runtime enforcement | skill + script 没这个能力；hooks / CI / agent harness 才有 |
| 多 agent runtime / orchestration | 超出 context 系统职责，归属 Claude Code / Codex / Cursor 等 |

## 6. 落地顺序（Phase 0-5，按上游 → 下游）

> 原则：每个 Phase 独立可逆。Phase 之间可拆 PR。每 Phase 完成后停下评估。

### Phase 0: 定位锚点（零代码改动）

**目标**：先把产品身份定准，不动代码、不动配置、不动主叙事文档。

- 在 `mydocs/idea.md` 末尾追加附录 F：
  - 定位回归声明（v0.1.0 + 附录 C 立场 + 工程记忆叙事）
  - 附录 D 术语修订映射表
  - 关联本 plan 与姊妹文档
- 后续所有改造都引用附录 F 作为思想锚点

### Phase 1: SKILL.md 与 agent-contract 拆分

**目标**：消除"默认 Harness"叙事，保留旧入口兼容。

- 重写 `SKILL.md` description 与第一段（用 §4.6 句式）
- 拆 `references/agents/agent-contract.md` 成：
  - `references/agents/context-utilities.md`（SpecAnchor 真正提供的能力）
  - `references/integrations/sdd-riper-one-flow.md`（可选 workflow）
- `references/workflow-gates.md` 调整：明确 `context-only` 是新默认，schema-driven 是 opt-in
- 不删 `agent-contract.md` 旧文件，留为 deprecated alias 指向新文件（避免老引用断裂）
- 不改 `anchor.yaml` 默认值（迁移留到 Phase 5）

### Phase 2: Context Bundle JSON v1（核心交付物）

**目标**：建立产品核心 artifact。

- 升级 `scripts/specanchor-assemble.sh --format=json` 输出
- 新增 `--bundle-schema=v1` 触发 `specanchor.context_bundle.v1` 输出
- 默认仍 `specanchor.assembly.v1`（向后兼容，给老消费者迁移期）
- 字段：layers / freshness / freshness_reasons / source_type / confidence
- freshness：v0.6 实现 time + code（用 git mtime），evidence 留接口
- `specanchor-boot.sh` 新增 `--agent --intent` 模式包装 assemble 输出 preflight bundle（**不取代 assemble**）

### Phase 3: Findings 独立 artifact（hot context 写回入口）

**目标**：让 context 既是输入也是输出。

- 新增 `.specanchor/findings/` 目录约定（含 `.gitkeep`）
- 写 `references/concepts/findings-ledger.md`
- 新增 `references/templates/finding-template.md`（含 visibility 字段）
- 更新 task spec 模板加 "Related Findings" refs 段（不嵌入 finding 本体）
- handoff packet 加 hot findings summary（按 visibility 过滤）
- `anchor.yaml.paths` 加 `findings: ".specanchor/findings/"`

### Phase 4: Sediment Proposal（hot → cold 回流）

**目标**：finding → 长期 spec 的安全中间态。

- 新增 `.specanchor/sediment/proposals/` 目录约定（含 `.gitkeep`）
- 写 `references/concepts/sediment-proposal.md`
- 新增 `references/templates/sediment-proposal-template.md`（含 operation 字段）
- `anchor.yaml.paths` 加 `sediment_proposals: ".specanchor/sediment/proposals/"`

### Phase 5: 基础 Lint / Doctor + 配置迁移

**目标**：脚本化确定性检查 + 推动新用户走 context-only 默认。

- 扩展 `scripts/specanchor-validate.sh`：
  - 校验 findings frontmatter（含 visibility 枚举）
  - 校验 sediment proposal frontmatter（含 operation 枚举）
- 扩展 `scripts/specanchor-doctor.sh`：
  - 检查 `visibility=sediment_queue` 但长期未处理的 finding
  - 检查 `hidden` finding 过期（建议但不自动归档）
  - 检查 proposal 的 source_findings 是否存在
- `anchor.yaml` 加 `context` 段（v0.6 新字段，optional，不破坏老项目）
- `anchor.yaml` 加 `workflow.default: context-only`（新项目 init 默认值）
- 不强制迁移老 anchor.yaml，但 `specanchor-doctor` 输出迁移建议

## 7. 验证标准

- 新用户读 SKILL.md 第一段能理解 "context system not Harness"
- 不装任何 schema 也能用 SpecAnchor（boot + assemble + findings）
- agent 可以只读 context bundle JSON 就知道下一步该读什么
- finding 不会自动污染 module / global spec
- 高 confidence finding 不会无限沉睡（doctor 会 warn）
- 现有 sdd-riper-one 用户的工作流不受影响

## 8. 不在本方案内

- 跨 repo 共享 spec 的 distribution 与消费 → 见 `2026-05-24_cross-repo-context-management.spec.md`
- 完整的脚本实施细节 → 每个 Step 启动时拆独立 task spec
- 单步 PR 颗粒度细分 → 实施时按需

## 备注

- 三轮模型讨论的 transcript 不留存，结论以本文档为准
- 附录 F 是这份方案的思想锚点，应先写完再启动 Step 2+
- 任何"再加一层 context 分类"的提议默认暂缓，除非有真实用户用例
- 本文档本身遵循"小而准"原则——避免成为 GPT 那种 10-PR 蓝图，每 Step 都该是独立可验证的小动作
