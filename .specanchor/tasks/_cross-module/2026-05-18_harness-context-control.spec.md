---
specanchor:
  level: task
  task_name: "Harness Context Control 定位收束 v0.5.0"
  author: "@fanghu"
  assignee: "@fanghu"
  reviewer: "@fanghu"
  created: "2026-05-18"
  status: "draft"
  last_change: "brainstorming 完成；Vision + 第一波 Implementation 双层 design 落 spec"
  related_modules:
    - ".specanchor/modules/references.spec.md"
    - ".specanchor/modules/scripts.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
    - ".specanchor/global/coding-standards.spec.md"
    - ".specanchor/global/project-setup.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: "feat/harness-context-control"

  # === Decision Log 配置（dogfood 第一例）===
  decision_log:
    hot_window: 5
    hot_types: [redirect, rollback, halt]
    respect_phase: true
  evidence_log:
    hot_window: 5
    hot_status: [failed, unverified-risk]
    auto_pin_acceptance: true
---

# SDD Spec: Harness Context Control 定位收束 v0.5.0

> Current RIPER Phase: PLAN
> 此 spec 包含 Vision（§1–§3）与第一波 Implementation（§4–§7）双层
> 本 spec 自身 dogfood：使用本次新增的 §1.2 Hard Boundaries / §1.3 Allowed Freedom / §4.7 Checkpoints Contract / §5.2 Decisions Log / §6.2 Evidence Ledger / §7.2 Handoff Packet 字段

## 0. Open Questions

- [x] **Decision**: 外部使用者升级到 v0.5.0-beta.1 时，**不写自动迁移工具**——仅提供升级文档（指向 `docs/release/v0.5.0-beta.1.md` + `references/schemas/sdd-riper-one/template.md`）。自动迁移作为 v0.5.0 stable 前的 follow-up，待 beta 真实使用反馈再决定是否需要。理由：YAGNI——实施范围已经较大，迁移工具是想象中的需求，不应阻塞 PLAN。审计痕迹保留。

## 1. Requirements (Context)

- **Goal**:
  把 spec-anchor 从 "spec control plane" 收束为 **Harness Context Control plane**，显式化 Context 三类（Spec / Decision / Evidence）。在 v0.5.0-beta.1 一次到位地落地：定位文档改写、sdd-riper-one schema 扩展、`specanchor-assemble.sh --mode=handoff`、anchor.yaml `context_control` 配置块、`specanchor-doctor.sh --lint=context-control`、pre-commit hook 集成、self-dogfood drift 修复。
- **In-Scope**:
  - 定位收束：README / README_ZH / WHY / WHY_ZH / SKILL.md description 改写
  - sdd-riper-one schema 扩展（5 字段，6 区段）
  - anchor.yaml `context_control` 配置块（含 `decision_log` / `evidence_log` 规则配置 + `enforce` 等级 + `pre_commit` 开关）
  - `scripts/lib/decision-filter.sh` + `evidence-filter.sh` 纯函数库
  - `specanchor-doctor.sh` 增加 `--lint=context-control` 检查
  - `.githooks/pre-commit` 集成 lint，按 `pre_commit.blocking` 决定阻断
  - `specanchor-assemble.sh --mode=handoff` 输出 handoff packet
  - self-dogfood drift 修复：`.specanchor/modules/references.spec.md` + `scripts.spec.md` 同步当前实际能力
  - schema 全量升级：spec-anchor 自身所有现存 task spec 必须升级到含新字段
- **Out-of-Scope**:
  - Steering Trigger（运行时 verification fail × 2 → 自动 halt 事件）—— 推迟到第三波
  - task-local codemap 命令化 / Evidence Ledger 命令化 —— 推迟到第二波
  - Spec ↔ Spec drift 检查 —— 推迟到第三波
  - 多 agent room、cloud runner、灰度发布平台、完整 Harness runtime —— 永久 out-of-scope
  - 外部项目存量 task 的自动 migration 工具 —— 仅提供升级文档
  - 中英文 spec 双语漂移检测 —— 沿用现有 lint，不新增

## 1.1 Context Sources

- Requirement Source: 本地文章 `Code is cheap. Don't write any.` —— Harness 方法论、水流理论、最小混沌单元、6 种 checkpoint 动作、多层 safety net
- Design Refs: Codex 评价（用户提供，2026-05-18 同日）—— 6 条改造方向 + 不建议方向边界
- Chat/Business Refs: 本次 brainstorming 流程（2026-05-18 全程）
- Extra Context: spec-anchor README / WHY / SKILL.md / anchor.yaml / `references/schemas/sdd-riper-one/template.md`

## 1.2 Hard Boundaries

> 越界即触发 Steering Trigger（停 + 转向）。本 spec 自身 dogfood 此字段。

- 不动 `anchor.yaml` 现有已发布字段名（向后兼容）；`context_control` 是新顶层块，老字段不挪
- 不删除 `.specanchor/archive/` 下任何文件
- 不引入新依赖（除非 checkpoint 批准）；YAML 解析继续用 `parse_yaml_field()` 单行简单值，不引 `yq` 强依赖（pre-commit 中 `yq` 是 optional fallback）
- 不破坏 Bash 3.2+ 兼容（macOS 默认 Bash）
- 不接管 conversation/runtime——spec-anchor 仍是 control plane，不做 agent runtime 或 multi-agent 编排
- 不在 v0.5.0-beta.1 范围内实现 Steering Trigger / task-local codemap / Spec↔Spec drift（已列入 Out-of-Scope）
- README/WHY 中英文必须同 PR 同步，不允许只改一边

## 1.3 Allowed Freedom

> Agent / 实施者可自决，无需 checkpoint。

- `scripts/lib/decision-filter.sh` 与 `evidence-filter.sh` 的内部实现（递归 / 迭代 / awk 风格选择）
- 内部函数命名（在 coding-standards 范围内）
- doctor `--lint=context-control` 的输出排版（彩色 / 表格 / 行号）
- handoff packet 内部字段排序（只要包含 §7 Handoff Packet 列出的全部信息项）
- 测试组织方式（`tests/` 下新建 fixture 目录的命名）
- 文档里的代码示例如何精简（保留语义即可）

## 1.5 Codemap Used (Feature Index)

- Codemap Mode: `feature`
- Codemap File: `.specanchor/project-codemap.md`（已有，本任务范围内不重写整张）
- Key Index:
  - Entry Points: `SKILL.md` / `anchor.yaml` / `scripts/specanchor-boot.sh` / `scripts/specanchor-assemble.sh`
  - Core Logic: `scripts/specanchor-doctor.sh`（lint 入口）/ `scripts/specanchor-assemble.sh`（handoff packet 生成）/ `references/schemas/sdd-riper-one/template.md`（schema 字段）/ `.githooks/pre-commit`（阻断点）
  - Cross-Module Flows: pre-commit → doctor → context-control lint → 读 anchor.yaml `enforce` → exit 0/1
  - Dependencies: bash 3.2+, 现有 `parse_yaml_field()` / `parse_frontmatter_*()` 工具
  - External Systems: 无新增

## 1.6 Context Bundle Snapshot

- Bundle Level: `Standard`
- Bundle File: 本 spec 自身（无独立 bundle 文件）
- Key Facts:
  - 文章核心：两个底层事实 → 水流理论 + 最小混沌单元 → spec/codemap/new-chat 三件套；6 种 checkpoint 动作中加料 47% / 追问 25% / 放水 9%
  - Codex 评价：6 条改造方向 + "不要扩成 multi-agent room / cloud runner / 灰度平台" 边界
  - spec-anchor 现状：三级 Spec + Assembly Trace + Schema Gate + Alignment Surface + Spec Sediment 已落地；`mydocs/codemap/` 与 `mydocs/context/` 已为 task-local 形态留下结构钩子
  - self-dogfood drift：`references.spec.md` + `scripts.spec.md` 已 drifted（boot Landscape Readiness ATTENTION 报告）
- Open Questions: 见 §0

## 2. Research Findings

### 文章方法论核心（《Code is cheap. Don't write any.》）

- 大模型两个底层事实：**概率生成器**（事实一：自由空间越大越易跑偏）+ **上下文宝贵**（事实二：长上下文中段腐烂、recency bias、自动总结无法挽救）。
- 水流理论：堤坝（静态边界）/ 水闸（checkpoint 6 动作）/ 水位标尺 / 溢洪区 / 导洪渠 / 缓存湖泊 / 下游验收点。
- 最小混沌单元：**小到可检查、大到可自治**——直接对抗两个事实。
- 上下文三件套：**spec**（持久化精炼）/ **codemap**（读码有重点）/ **new-chat**（跨 session 换水）。
- Checkpoint 6 动作（实际人工输入分布）：放水 ~9% / 阻止 <1% / 绕道 ~5% / 回炉 ~2% / 追问 ~25% / **加料 ~47%**——加料和追问占 72%，是 checkpoint 真正的主流动作。
- 转向硬规则：**spec 冲突 / 越界 / 连续验证失败**。
- 多层 safety net：自验 → 自测 → 他测 → 自动化回归+巡检 → 灰度+金丝雀。
- 工程师价值结构迁移：从"写代码的人"上移到"切任务包 + 做 checkpoint + 看证据的人"。

### Codex 评价的 6 + 1 条改造方向

| # | 方向 | 是否在 v0.5.0-beta.1 范围 | 备注 |
|---|---|---|---|
| 1 | Task Spec 写进最小混沌单元（5 字段） | ✅ 第一波 | sdd-riper-one schema 扩展 |
| 2 | checkpoint 协议产品化（6 动作 + decision_log） | ✅ 第一波 | §5.x Decisions Log + 规则 A/B/C |
| 3 | new-chat / handoff 一等能力 | ✅ 第一波 | `assemble.sh --mode=handoff` |
| 4 | task-local codemap | ❌ 第二波 | 现有 §1.5 Codemap Used 已是雏形，不命令化 |
| 5 | Evidence Ledger | ✅ 第一波 | §6.x Evidence Ledger |
| 6 | self-dogfood drift 修复 | ✅ 第一波 | references.spec.md + scripts.spec.md |
| 7 | Steering Trigger（本 spec 作者补充） | ❌ 第三波 | 需要先收集 ≥50 条真实 decision 数据 |

### spec-anchor 当前能力盘点

- ✅ 三级 Spec（Global / Module / Task）
- ✅ Assembly Trace + Loading Strategy（full / parasitic）
- ✅ Schema Gate（sdd-riper-one 阶段门禁）
- ✅ Alignment Surface（`specanchor-check` 四种模式）
- ✅ Spec Sediment（Review Verdict 末尾的经验沉淀字段）
- ✅ `specanchor-assemble.sh` 已有 bounded read plan 输出
- ✅ Schema 系统可插拔（sdd-riper-one / simple / bug-fix / refactor / research / openspec-compat）
- ⚠️ Decision Context 与 Evidence Context 未显式化——存在但未结构化、未抗腐烂
- ⚠️ `.specanchor/modules/references.spec.md` + `scripts.spec.md` 已 drifted

### Decision Context 的 47% 信号是 ROI 来源

文章数据：checkpoint 上 ~47% 的人工输入是"加料"（沿原方向叠新约束），~25% 是"追问"。spec-anchor 当前的 Spec Sediment 是任务结束后批量回写，没有 checkpoint 粒度的实时沉淀——**这 47% 信号目前每一轮都被丢弃**。把它沉淀化是本次改造的最大单点 ROI。

## 2.1 Next Actions

- 推进到 §3 Innovate 完成定位选项与三类 Context 设计
- 推进到 §4 Plan 落地 Vision + 第一波 Implementation 全部细节
- §5 Execute Log 仅在 implementation 阶段填，本 spec 处于 PLAN 阶段
- 进入 writing-plans skill 出实施计划

## 3. Innovate (Options & Decision)

### 3.1 命名收束的两个候选

#### Option A：Harness Context Control + 显式 Context 三类
- Pros: "Harness" 是文章已普及的术语；"Context Control" 直接映射事实二；保留 spec-anchor 的 Context Compilation 哲学
- Cons: Context 语义需扩展到 Decision/Evidence，否则 Codex 方案 2/5 看似 out of scope —— 通过文档显式定义三类内涵化解

#### Option B：Harness Spec Plane / Harness Anchor Plane
- Pros: 名字宽，自然容纳 Decision/Evidence
- Cons: 比 "Context Control" 直白度低；丢失 "上下文宝贵"这个核心痛点 framing

### 3.2 Decision Context 物理存储的两个候选

#### Option A：内嵌 Task Spec 内部
- Pros: Task Spec 已是 single source of truth；assembly trace 自动覆盖；handoff 直接抓单文件；不引入新文件类型
- Cons: Task Spec 体量增大；归档前长度可能 >1000 行（dogfood 本 spec 已接近）

#### Option B：拆出 `.specanchor/decisions/<task-id>/`
- Pros: 单文件不膨胀；可独立检索
- Cons: 多文件同步开销；handoff packet 需要额外 fetch；assembly trace 需扩展

### 3.3 specanchor_handoff 实现的两个候选

#### Option A：复用 `specanchor-assemble.sh --mode=handoff`
- Pros: 一个 binary 一个心智模型；assemble 与 handoff 80% 逻辑重叠；保留 `specanchor_handoff` 作为意图层 ID
- Cons: assemble.sh 已 14.6K，加 mode 进一步膨胀——通过 `scripts/lib/` 抽函数库缓解

#### Option B：新建 `specanchor-handoff.sh`
- Pros: 语义清晰；可独立演进
- Cons: 复制 80% 逻辑；增加脚本数量；与 spec-anchor 已有的 assemble hub 哲学冲突

### Decision

| 选项 | 选定 | 理由 |
|---|---|---|
| 3.1 | **Option A**：Harness Context Control + 三类 Context | 用户决策（cp-03）；保留 framing 优势，通过文档显式化扩展 Context 内涵 |
| 3.2 | **Option A**：内嵌 Task Spec | 用户决策（cp-10）；single source of truth + 抗 assembly 复杂化 |
| 3.3 | **Option A**：复用 assemble | 用户决策（cp-10）；意图层与实现层解耦的现有契约延续 |

### Skip
- Skipped: false
- Reason: 这是定位收束级别的决策，必须走 Innovate

## 4. Plan (Contract — Vision + 第一波 Implementation)

### 4.1 Three Categories of Context (Vision)

新定位：**SpecAnchor is a Harness Context Control plane** —— 不负责"让水流"，负责"堤坝、水位标尺、闸门记录、下游验收证据"。

| Context 类 | 来源 | 典型工件 | 对应文章语义 |
|---|---|---|---|
| **Spec Context** | 团队/模块/任务的契约 | `.specanchor/global/`, `modules/`, `tasks/`、Assembly Trace | 任务包的"目标 + 边界 + 自由度 + 验收"——堤坝 |
| **Decision Context** | checkpoint 上的人工输入沉淀 | Task Spec §5.x Checkpoint Decisions Log；沉淀到 §6 Spec Sediment | 6 种动作（加料 47% / 追问 25% / 绕道 / 回炉）——闸门记录 |
| **Evidence Context** | 验收证据链 | Task Spec §6.x Evidence Ledger；可导出为 handoff bundle | 多层 safety net 第 1–2 层产出——下游验收 |

三者协作：**Spec 是先验、Decision 是过程沉淀、Evidence 是事后证据**——共同构成"下一轮 / 下一个 chat / 下一个 reviewer"看到的 Context。

### 4.2 Context Injection Pipeline (Vision)

**核心决策**：三类 Context 物理上不分家——全部内嵌 Task Spec 内部。

注入时机：

| 时机 | 注入内容 | 触发器 |
|---|---|---|
| **Boot** | Global Spec（summary/full）+ Assembly Trace 元信息 | 进入项目 |
| **Task 启动** | 路径相关 Module Spec 全文 + 当前 Task Spec 全文（含 Decision/Evidence 内嵌段） | `specanchor_task` / `specanchor-assemble.sh --files=... --intent=...` |
| **Checkpoint** | **不新注入**——agent 输出 `Diff Plan + Risk`，用户反馈写回 Task Spec.Decisions Log | agent 准备改代码前停下来 |
| **Handoff / New chat** | 导出 handoff packet 喂给新 chat | `specanchor_handoff` 命令 |

**反直觉点**：Decision 不需要在每次 checkpoint 之间重新喂给 LLM——它写回 Task Spec 后，下一次 LLM 读 Task Spec 自然带上。spec-anchor 不做"对话注入器"，仍是"持久化 + 装配"的 control plane。

### 4.3 Decision/Evidence Lifecycle Rules (Vision → 落 schema)

#### 规则 A：status (active / superseded / withdrawn) ——只允许显式声明

**Status enum 严格三值**：`active | superseded | withdrawn`。`archived` 是 task-level lifecycle（`task.status` 中的 `archived`），**不污染 decision.status**——decision filter / lint enum 只需识别这三值。

| 触发 | 动作 | 谁声明 |
|---|---|---|
| 新 decision 写入时附 `supersedes: cp-NN` | cp-NN.status 立即设为 `superseded`，cp-NN.superseded_by 指向新 id | LLM 写入时显式声明 |
| 用户在 review 阶段手动改 `status: superseded` | 立即生效 | 人工 |
| 用户手动改 `status: withdrawn` | 表示"决策本身错了，从未生效" | 人工 |
| 关系标注（被吸收/被精炼/依赖等） | 自由文本写入 `note:` 字段；不改 status；不入 enum | LLM/人工 |

**约束**：status 是 eager 的——`supersedes` 一旦写入立即变更（修一处文件），spec 文件永远反映当前状态。**关系标注用 note 文本而非新增 enum 值**（YAGNI；本 spec 13 个 decision 仅 1 例"被吸收"，未达到加结构化字段的频率门槛）。

**`note` 字段语义边界**：`note` 仅用于人类 audit / display；`scripts/lib/decision-filter.sh` **不读取、不解析** `note` 内容，**不影响 hot/cold 分层或 prompt inclusion**。后续若出现需要机器理解的关系（如自动构建 decision 关系图），先评估频率，再决定是否升级到结构化字段——不要从 `note` 文本里反向解析 `absorbed/refined` 之类的关键字。

#### 规则 B：hot / cold 分层（assembly 时现算的视图，不持久化）

进入 hot 段（OR 关系）：

| 条件 | 触发原因 |
|---|---|
| 最近 N 条（默认 N=5，可在 anchor.yaml 配） | 时间近因 |
| `pin: true`（用户标记） | 关键决策永驻 hot |
| `type: redirect \| rollback \| halt` | 转向类天然重要 |
| 当前 RIPER phase 内产生的 decision | 同一 phase 内全部 hot |

进入 cold：不满足以上条件 **AND** 至少跨过当前 phase。

#### 规则 C：触发时机（混合策略）

| 维度 | 策略 | 计算位置 |
|---|---|---|
| status | **eager**（写入即生效） | spec 文件持久化 |
| hot/cold | **lazy**（assemble 时按规则算） | `scripts/lib/decision-filter.sh` |
| pin | **eager**（显式标记） | spec 文件持久化 |
| 归档 | **eager**（archive 时一次性扫） | spec 文件持久化 |

#### 规则 D：Evidence 生命周期（精简，复用 A/B/C）

- 不需要 `superseded`（证据不会被覆盖，只可能补充或作废）
- `status`: `pending / verified / failed / unverified-risk`
- `pin: true`（默认 acceptance criteria 对应证据自动 pin）
- 进入 hot 的条件：`pin` OR 最近 N 条 OR `status: failed | unverified-risk`

#### Status / hot 正交

| 状态组合 | 进 prompt？ |
|---|---|
| active ∩ hot | ✅ 默认装载 |
| active ∩ cold | ✅ 仅在 Spec Sediment / 审计回看时展示 |
| superseded（任意 hot/cold） | ❌ 不进 prompt（除非用户显式 query） |
| withdrawn | ❌ 仅审计存档 |

### 4.4 Schema 5 字段（6 区段）落地

加在 `references/schemas/sdd-riper-one/template.md`：

| # | 字段 | 位置 | 性质 | 写入者 |
|---|---|---|---|---|
| 1 | **Hard Boundaries** | §1.2（紧贴 In/Out-of-Scope） | 静态契约 / 堤坝 | 任务作者 |
| 2 | **Allowed Freedom** | §1.3（贴 Hard Boundaries） | 静态契约 / 自由水域 | 任务作者 |
| 3a | **Checkpoints — Contract** | §4.7（在 Plan 内） | 静态契约（在哪里必须停） | 作者 |
| 3b | **Checkpoint Decisions Log** | §5.2（紧贴 §5 Execute Log） | 动态记录（实际停了什么） | agent / 人混合 |
| 4 | **Evidence Ledger** | §6.2（紧贴 §6 Review Verdict） | 验收证据链 | agent 写，人核对 |
| 5 | **Handoff Packet** | §7.2（紧贴 §7 Plan-Execution Diff） | 自动生成视图 | `assemble.sh --mode=handoff` |

#### Frontmatter 配置块（统一规则 A–D 入口）

```yaml
specanchor:
  level: task
  task_name: "..."
  ...
  decision_log:
    hot_window: 5
    hot_types: [redirect, rollback, halt]
    respect_phase: true
  evidence_log:
    hot_window: 5
    hot_status: [failed, unverified-risk]
    auto_pin_acceptance: true
```

#### 新区段示例（节选，详见 implementation 阶段写入 template.md）

**§1.2 Hard Boundaries**
```markdown
> 越界即触发 Steering Trigger
- 不动 anchor.yaml 已发布字段名
- 不引入新依赖（除非 checkpoint 批准）
```

**§1.3 Allowed Freedom**
```markdown
> Agent 自决，无需 checkpoint
- 实现路径选择（递归 vs 迭代）
- 内部函数命名
```

**§4.7 Checkpoints — Contract**
```markdown
### CP-1 改代码前
Output: Diff Plan + Risk + Next Verification
Awaits: pass / clarify / add-spec / redirect / rollback / halt

### CP-2 引入新依赖前
Output: 依赖名、版本、引入理由

### CP-3 验证连续失败 (×2 同路径)
Output: 失败现象、已尝试方案
Awaits: redirect / rollback / halt（强制非 pass）
```

**§5.2 Checkpoint Decisions Log**
```markdown
### Recent (active, hot — auto-filtered)
- cp-12 (2026-05-18T14:32) [add-spec, active] @§4.2
  rule: "改用本地 LRU 替代 Tair"
  by: human
- cp-11 (2026-05-18T14:10) [redirect, active, pin] @§4.1
  rule: "回到 §1.2 Hard Boundaries: 不引入新依赖"
  supersedes: cp-09
  by: human

### Earlier (audit only)
- cp-09 (2026-05-17) [add-spec, superseded by cp-11]
- cp-03 (2026-05-15) [clarify, active, cold]
```

**§6.2 Evidence Ledger**
```markdown
### Commands Run
| Command | Status | Output ref |
|---|---|---|
| bash tests/run.sh | pass | mydocs/evidence/<task>/run.log |

### Acceptance Criteria Mapping
| Criterion | Evidence | Status |
|---|---|---|
| 5 schema fields validated | doctor --strict pass | ✅ |

### Unverified Risks
- migration script 未在 100k+ task corpus 上演练

### Manual / External Checks Needed
- 人工 review README diff

### Rollback / Follow-up Handle
- revert commits: <SHA list>
- feature flag: N/A
```

**§7.2 Handoff Packet**
```markdown
> auto-generated by specanchor-assemble.sh --mode=handoff
> 不要手写。重新生成请运行 specanchor_handoff
> Last generated: 2026-05-18T15:00 (phase: PLAN)

- Task: <task_name> (status: in_progress)
- Spec Landscape: Global summary + Module(...)
- Active Decisions (hot, last 5): cp-12, cp-11, cp-08, cp-07, cp-04
- Evidence Status: 4 verified / 2 unverified-risk
- Read next: <files>
- Don't read (cold/superseded): 7 entries
- Next step: <what agent should do first>
```

#### 兼容性

- v0.5.0-beta.1 全量升级：spec-anchor 自身所有现存 task spec 必须升级（含新字段，必填字段不得为空）
- 外部项目升级 v0.5.0-beta.1 时 fresh install 启用；存量 task 升级仅提供文档说明，不写 `specanchor_migrate` 工具（推迟到 stable）
- doctor `--lint=context-control` 通过 frontmatter `context_control` 块或 `decision_log/evidence_log` 字段存在性检测是否启用，未启用项目零影响

### 4.5 anchor.yaml `context_control` 配置块

```yaml
specanchor:
  version: "0.5.0-beta.1"
  ...
  # === 新增：Harness Context Control 配置 ===
  context_control:
    decision_log:
      hot_window: 5
      hot_types: [redirect, rollback, halt]
      respect_phase: true
    evidence_log:
      hot_window: 5
      hot_status: [failed, unverified-risk]
      auto_pin_acceptance: true
    enforce:
      hard_boundaries: error      # error | warning | off
      allowed_freedom: warning
      checkpoints_contract: warning
      evidence_ledger: warning
      handoff_packet: warning     # 默认开为 warning（不阻断 commit，仅提醒）
    pre_commit:
      enabled: true
      blocking: true              # release 默认阻断；implementation 阶段先用 false（见 §4.10 顺序）
```

#### 配置优先级（解决两个 source of truth 问题）

**`anchor.yaml` 是全局默认 → task frontmatter 仅 override → 无 override 则继承全局值**。

`assemble --mode=handoff` / `doctor --lint=context-control` 按以下顺序读：
1. 当前 task spec frontmatter 的 `decision_log` / `evidence_log` / `enforce` 字段（同字段 override 全局）
2. 项目 `anchor.yaml` 的 `context_control.decision_log` / `context_control.evidence_log` / `context_control.enforce`
3. 内置 default（`hot_window: 5` 等，见 `scripts/lib/decision-filter.sh`）

task frontmatter 不必声明所有字段——未声明的字段沿用 anchor.yaml；anchor.yaml 也未声明的沿用内置 default。

### 4.6 README + WHY/WHY_ZH/SKILL 改写关键点

#### README.md（5 处定向修改 + 1 处新增章节）

| 位置 | 改动 |
|---|---|
| L38–42 "What SpecAnchor Is" | "spec control plane" → "**Harness Context Control plane**"，加入"organizes context across three categories: Spec / Decision / Evidence" |
| 紧贴 "What SpecAnchor Is" 之后 | 新增一节 "What Counts as Context" —— 三类表格（同 §4.1） |
| L113 比较表 | 加 2 行：**"Checkpoint decisions captured"** + **"Evidence ledger as first-class"**（vanilla / Spec-Kit / OpenSpec 都 ❌，SpecAnchor ✅） |
| L155–172 "What Gets Created" | 在 archive/ 之后加 `mydocs/evidence/`、`mydocs/handoff/`，标注 "auto-generated by specanchor_handoff" |
| L178 "Day 2" 表格 | 加 1 行 `*"Hand off this task to a new chat"*` → `specanchor_handoff` |

#### README_ZH.md：与 README.md 同步改 5+1 处。

#### WHY.md（3 处）

| 位置 | 改动 |
|---|---|
| "Compiled Knowledge vs Retrieved Knowledge" 之后 | 新增章节 **"Three Categories of Context"** —— 解释为什么 Decision 和 Evidence 也是 Context；引用文章事实二（上下文宝贵） |
| "Problems It Solves" 表格 | 加 2 行：**"Checkpoint 决策被对话腐烂吃掉" → Decision Context with status & hot/cold lifecycle**；**"完成报告说'通过了'但没证据链" → Evidence Ledger with auto-pinned acceptance** |
| "Evolution Roadmap" Current 段 | "Three-level Spec system" → "Three-level Spec + Decision/Evidence Context system"；末尾加 `Steering Trigger emit (推迟)` 与 `specanchor_handoff command` 两条路标 |

#### WHY_ZH.md：与 WHY.md 同步改 3 处。

#### SKILL.md（2 处）

**(1) frontmatter description 改写**：
```diff
-description: 规格控制平面——三级 Spec 体系（Global/Module/Task），在 AI 生成代码前自动组装 Spec Landscape...
+description: Harness Context Control——三类 Context（Spec/Decision/Evidence）合一的规格控制平面，在 AI 生成代码前装配 Spec Landscape，运行中沉淀 Checkpoint 决策，验收时输出 Evidence Ledger，跨 session 通过 handoff packet 重启...
```

**(2) Command Routing 表加一行**：
```
| `specanchor_handoff` | 跨 session 导出 handoff packet | `references/commands/handoff.md` |
```

### 4.7 Checkpoints (Contract)

> 本 spec 自身的 implementation 阶段，agent 必须停下来汇报的位置。

#### CP-1 self-dogfood drift 修复完成
- Output: 改后的 `references.spec.md` + `scripts.spec.md` 摘要 + boot 输出对照（确认 ATTENTION 消除）
- Awaits: pass（继续 schema 扩展）/ add-spec / redirect

#### CP-2 sdd-riper-one schema 扩展前
- Output: template.md 的 diff plan（哪 6 个区段加在哪、frontmatter 配置块结构）
- Awaits: pass / clarify / redirect

#### CP-3 anchor.yaml `context_control` 块加入前
- Output: 字段名、默认值、`examples/minimal-full-project/` 同步范围
- Awaits: pass / clarify

#### CP-4 lib 函数库与 doctor lint 实现前
- Output: `scripts/lib/decision-filter.sh` + `evidence-filter.sh` + `doctor --lint=context-control` 接口签名 + test fixture 设计
- Awaits: pass / clarify / redirect

#### CP-5 pre-commit 集成前
- Output: hook diff + 失败时的 fallback 路径（`pre_commit.blocking: false`）演示
- Awaits: pass / clarify

#### CP-6 specanchor-assemble.sh `--mode=handoff` 实现前
- Output: handoff packet 输出格式 fixture + active/superseded 过滤 unit test
- Awaits: pass / clarify / redirect

#### CP-7 README + WHY 改写前
- Output: 中英文 diff plan（不写全文，列改动行号 + 新增章节大纲）
- Awaits: pass / clarify

#### CP-8 端到端 dogfood 验证前
- Output: 用本 spec 自己作为 task 跑完整循环（从 task 创建 → checkpoint × N → completed → handoff packet 导出）的脚本/记录
- Awaits: pass（→ §6 Review Verdict）/ rollback

#### CP-9（人工触发）验证连续失败 ×2 同路径
- Output: 失败现象 + 已尝试方案 + 是否触发 redirect / rollback
- Awaits: redirect / rollback / halt（强制非 pass）
- Note: Steering Trigger 自动化推迟到第三波；v0.5.0-beta.1 范围内此规则由人工监测触发，doctor lint 不自动 emit STEER 事件

### 4.8 File Changes

| 路径 | 变更类型 | 说明 |
|---|---|---|
| `.specanchor/modules/references.spec.md` | UPDATE | 同步当前实际能力（drift 修复） |
| `.specanchor/modules/scripts.spec.md` | UPDATE | 同步 spec-index v3 / lib / handoff mode 等 |
| `references/schemas/sdd-riper-one/template.md` | UPDATE | 加 6 区段 + frontmatter 配置块 |
| `references/schemas/sdd-riper-one/schema.yaml` | UPDATE | 反映新字段 |
| `anchor.yaml` | UPDATE | 加 `context_control` 块；version → 0.5.0-beta.1 |
| `examples/minimal-full-project/anchor.yaml` | UPDATE | 同步 |
| `scripts/lib/decision-filter.sh` | CREATE | 规则 B/C 纯函数 |
| `scripts/lib/evidence-filter.sh` | CREATE | 规则 D 纯函数 |
| `scripts/specanchor-doctor.sh` | UPDATE | 加 `--lint=context-control` |
| `scripts/specanchor-assemble.sh` | UPDATE | 加 `--mode=handoff` |
| `scripts/specanchor-boot.sh` | UPDATE | boot 输出嵌入 `specanchor_handoff` 路由 |
| `references/commands/handoff.md` | CREATE | `specanchor_handoff` 命令定义文件 |
| `references/commands-quickref.md` | UPDATE | 加 "Hand off this task to a new chat" → `specanchor_handoff` |
| `.githooks/pre-commit` | UPDATE | 集成 context-control lint |
| `README.md` | UPDATE | 5+1 处 |
| `README_ZH.md` | UPDATE | 同步 |
| `WHY.md` | UPDATE | 3 处 + 新章节 |
| `WHY_ZH.md` | UPDATE | 同步 |
| `SKILL.md` | UPDATE | description 改写 + Command Routing 表加 `specanchor_handoff` 一行 |
| `.specanchor/tasks/**/*.spec.md` | UPDATE | 全量升级到新 schema |
| `tests/fixtures/context-control/` | CREATE | doctor lint + handoff fixture |
| `tests/run.sh` | UPDATE | 加 context-control 测试入口 |
| `CHANGELOG.md` | UPDATE | v0.5.0-beta.1 条目 |
| `docs/release/v0.5.0-beta.1.md` | CREATE | 发布说明 |

### 4.9 Signatures

```bash
# 新增脚本接口
scripts/lib/decision-filter.sh \
  --task-spec=<path> \
  --hot-window=<int> \
  --hot-types=<csv> \
  --respect-phase=<bool> \
  --format=text|json

scripts/lib/evidence-filter.sh \
  --task-spec=<path> \
  --hot-window=<int> \
  --hot-status=<csv> \
  --auto-pin-acceptance=<bool> \
  --format=text|json

# 新增 doctor 选项
specanchor-doctor.sh --lint=context-control [--strict] [--format=text|json]

# 新增 assemble 模式
specanchor-assemble.sh --mode=handoff \
  --task-spec=<path> \
  [--format=text|markdown|json] \
  [--write-back]   # 是否回写 §7.2 Handoff Packet
```

### 4.10 Implementation Checklist

> **顺序设计原则**（开发体感导向）：pre-commit blocking 推迟到最后；中间所有步骤在 warning-only 模式下推进；module spec 同步拆两次（先修当前 drift，最后同步新能力）；命令路由作为对外接口必须落地。

- [ ] 1. **self-dogfood drift 修复（仅当前 drift）** —— 同步 `.specanchor/modules/references.spec.md` + `scripts.spec.md` 到**当前实际已落地能力**（spec-index v3 / agent-contract / landscape readiness 等）。**不写入 lib / handoff / 命令路由等本次新增能力**——那些留到 step 14
- [ ] 2. **sdd-riper-one schema 扩展** —— `references/schemas/sdd-riper-one/template.md` 加 6 区段 + frontmatter 配置块；同步 `references/schemas/sdd-riper-one/schema.yaml`
- [ ] 3. **anchor.yaml schema 扩展** —— 主项目 anchor.yaml + `examples/minimal-full-project/anchor.yaml` 加 `context_control` 块；**`pre_commit.blocking: false` 启动开发期默认**（最后一步切 true）
- [ ] 4. **`scripts/lib/decision-filter.sh`** —— 规则 B/C 的纯函数（输入 decisions array → 输出 hot/cold 分组）；按 §4.5 配置优先级读 anchor.yaml + task frontmatter
- [ ] 5. **`scripts/lib/evidence-filter.sh`** —— 规则 D 的纯函数
- [ ] 6. **`specanchor-doctor.sh --lint=context-control`** —— 调用 lib + 读 anchor.yaml `enforce` → exit 0/1/2；与现有 `--strict` 兼容
- [ ] 7. **`.githooks/pre-commit` 集成 lint（warning-only 模式）** —— hook 读 `pre_commit.blocking`；当前 anchor.yaml 仍是 `false`，所以本步只把 hook 接上、不阻断；对未启用项目零影响
- [ ] 8. **`specanchor-assemble.sh --mode=handoff`** —— 调用 lib，输出 packet（text / markdown / json 三格式）；写入 `mydocs/handoff/<task-id>_<ts>.md` 并回写 §7.2
- [ ] 9. **命令路由（`specanchor_handoff`）** —— 创建 `references/commands/handoff.md` 命令定义；`commands-quickref.md` 加 "Hand off this task to a new chat" 行；`SKILL.md` Command Routing 表加 `specanchor_handoff`；`scripts/specanchor-boot.sh` 输出嵌入新意图映射
- [ ] 10. **schema 全量升级（spec-anchor 自身现存 task）** —— 所有 `.specanchor/tasks/` 下现存 task spec 升级到含新字段；空字段允许 `note: "(not applicable)"` 占位避免 lint 阻断 archive 流程
- [ ] 11. **README + README_ZH 改写** —— §4.6 列出的 5+1 处定向修改
- [ ] 12. **WHY + WHY_ZH 改写** —— §4.6 列出的 3 处定向修改 + 新增 "Three Categories of Context" 章节
- [ ] 13. **SKILL.md description 改写** —— 仅改 frontmatter description（Command Routing 表已在 step 9 落地，本步不再触碰，避免和 step 9 在同一处来回改）
- [ ] 14. **module spec 最终同步（本次新增能力沉淀）** —— `references.spec.md` + `scripts.spec.md` 再补本次新增的 `lib/decision-filter.sh` / `lib/evidence-filter.sh` / `specanchor-assemble --mode=handoff` / `specanchor-doctor --lint=context-control` / 命令路由 `specanchor_handoff` 等能力；regenerate `spec-index.md`；boot 复验 Landscape Readiness 无 ATTENTION
- [ ] 15. **切换 `pre_commit.blocking: true` + 端到端 dogfood 验证** —— anchor.yaml 改 true；运行 `boot --format=summary` / `doctor --strict --lint=context-control` / `tests/run.sh` / `git diff --check` 全 pass；用本 spec 跑完整循环（task 创建 → checkpoint × N → completed → handoff packet 导出回写 §7.2）

## 5. Execute Log

> 此 task 处于 PLAN 阶段，Execute Log 在进入 implementation 阶段后由各 checkpoint 填入。

- [ ] Step 1（CP-1 完成后）: ...
- [ ] Step 2（CP-2 完成后）: ...

## 5.2 Checkpoint Decisions Log

> dogfood：以下记录本次 brainstorming 流程中用户做出的决策（按时间倒序）。

### Recent (active, hot — last 5 within current PLAN phase)

- **cp-13** (2026-05-18, PLAN) [pass + add-spec, active, pin] @§4.6 节 6
  - rule: "Steering Trigger 推迟到第三波；v0.5.0-beta.1 一次性到位（讨论点全部落地）；schema 全量升级（spec-anchor 自身所有现存 task）"
  - by: human
- **cp-12** (2026-05-18, PLAN) [add-spec, active] @§4.5 节 5
  - rule: "anchor.yaml `context_control` 配置块合理；`enforce.handoff_packet` 默认开（warning 级别，不阻断 commit）；中英文同步；比较表加两行 OK"
  - by: human
- **cp-11** (2026-05-18, PLAN) [add-spec, active, pin] @§4.4 节 4
  - rule: "Checkpoints 拆 §4.7 Contract（静态）+ §5.2 Decisions Log（动态）；Handoff Packet 落 §7.2 自动视图（不手写）；doctor lint 在 anchor.yaml 配置 + 默认 pre-commit 阻断"
  - by: human
- **cp-10** (2026-05-18, PLAN) [add-spec, active] @§4.3 节 3
  - rule: "1) Decision/Evidence 内嵌 Task Spec 接受 / 2) Hot/Cold 分层是 nice-to-have，要写成规则 / 3) handoff 复用 vs 新建——agent 推荐复用"
  - by: human
- **cp-09** (2026-05-18, PLAN) [add-spec, active, pin] @§4.1 节 1
  - rule: "三类划分清楚；Decision/Evidence 都归进 Context；README/WHY 这次一并改（加入第一波 Implementation 范围）"
  - by: human

### Earlier (audit only — within RESEARCH phase, before §4 PLAN gate)

- **cp-08** (2026-05-18, RESEARCH→PLAN 边界) [pass, active, cold] @brainstorming setup
  - rule: "Spec layout = Vision / Implementation 分段（一个文件，前半 Vision 后半 Implementation）"
  - by: human
- **cp-07** (2026-05-18) [add-spec, active, cold] @brainstorming setup
  - rule: "Schema scope = 只改 sdd-riper-one（不动 simple / bug-fix / refactor / research / openspec-compat）"
  - by: human
- **cp-06** (2026-05-18) [add-spec, active, cold] @brainstorming setup
  - rule: "Spec 文件位置 = `.specanchor/tasks/_cross-module/2026-05-18_harness-context-control.spec.md`（dogfood 优先）"
  - by: human
- **cp-05** (2026-05-18) [add-spec, active, cold] @brainstorming setup
  - rule: "Spec scope = Vision + 第一波 Implementation 合并（一个 spec 包含定位收束 + 三类语义 + 6+1 接口契约 + 第一波三件事的实施细节）"
  - by: human
- **cp-04** (2026-05-18) [add-spec, active, cold] @对外评价回应
  - rule: "Codex 评价 6 条整体认同；接受 Codex 不建议做的边界（不扩 multi-agent room / cloud runner / 灰度平台 / 完整 Harness runtime）"
  - by: human
- **cp-03** (2026-05-18) [redirect, active, cold] @初步建议回应
  - rule: "把 spec-anchor 定位从 'spec control plane' 收束为 **Harness Context Control**；选 Option A（保留命名 + 显式 Context 三类）"
  - by: human
- **cp-02** (2026-05-18) [add-spec, active, cold] @初步建议
  - rule: "推荐先做方向 1（Checkpoint Sediment）作为最大 ROI 单点"
  - note: "implementation scope 已纳入 cp-03 的更高维定位收束（v0.5.0-beta.1 第一波 Implementation 包含方向 1）；ROI rationale 仍 active 未被否定。关系标注用 note 文本而非新增 enum——参考 §4.3 规则 A 末段"
  - by: agent
- **cp-01** (2026-05-18) [pass, active, cold] @brainstorming 启动
  - rule: "用户提出'读文章 + 看项目，给改造看法'；agent 给出 3 主方向 + 3 次方向"
  - by: human

## 6. Review Verdict

> 此 task 处于 PLAN 阶段，Review Verdict 在 implementation 完成后填。

- Spec coverage: PENDING
- Behavior check: PENDING
- Regression risk: PENDING
- Module Spec 需更新: Yes —— `references.spec.md` + `scripts.spec.md` 已列入 Implementation Checklist #1
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: PENDING（implementation 阶段决定是否需要新加 `global/harness-context-control.spec.md`）
  - 新发现的项目规则: PENDING
  - 值得记录的反模式: PENDING
- Follow-ups: 第二波（task-local codemap 命令化 + Evidence Ledger 命令化）；第三波（Steering Trigger + Spec↔Spec drift）

## 6.2 Evidence Ledger

> 此 task 处于 PLAN 阶段，Evidence 在 implementation 阶段产生后填。以下为 planned commands 与 acceptance criteria 占位。

### Commands Run (planned)

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-boot.sh --format=summary` | pending | implementation 阶段产出 |
| `bash scripts/specanchor-doctor.sh --strict --lint=context-control` | pending | 同上 |
| `bash tests/run.sh` | pending | 同上 |
| `git diff --check` | pending | 同上 |
| `bash scripts/specanchor-assemble.sh --mode=handoff --task-spec=<this>` | pending | 同上（dogfood handoff packet 生成） |

### Acceptance Criteria Mapping (planned)

| Criterion | Evidence (planned) | Status |
|---|---|---|
| Harness Context Control 命名收束完成 | README/WHY/SKILL diff + grep 验证 | pending |
| 三类 Context 在 WHY 中显式化 | "Three Categories of Context" 章节存在 | pending |
| sdd-riper-one schema 6 区段 + frontmatter 配置块落地 | template.md diff + schema.yaml 同步 | pending |
| anchor.yaml `context_control` 块落地 | anchor.yaml diff + examples 同步 | pending |
| doctor `--lint=context-control` 工作 | fixture 测试 expected error/warning 矩阵 | pending |
| pre-commit 按 `pre_commit.blocking` 阻断 | 手工触发 commit 时阻断/通过两条路径 | pending |
| `assemble --mode=handoff` 输出符合 §7.2 格式 | dogfood 本 spec 跑通 | pending |
| self-dogfood drift 消除 | boot 输出无 ATTENTION | pending |
| schema 全量升级覆盖所有现存 task | `find .specanchor/tasks -name '*.spec.md'` 全部含新字段 | pending |
| README/WHY 中英文同步 | 双语 lint pass | pending |

### Unverified Risks

- pre-commit hook 在没有 yq 的环境下需 fallback 到 `parse_yaml_field()` —— 兼容性需 implementation 阶段验证
- schema 全量升级路径上若发现某些归档 task 缺信息无法补，需要决定 archive 例外规则（implementation 阶段评估）
- handoff packet 在跨 session 实际给 new chat 喂入时，是否真的能干净接手——只能靠 §4.7 CP-8 dogfood 验证
- README 改写中"比较表加两行" 的 marketing claim 是否准确反映 v0.5.0-beta.1 实际能力——文档改写阶段需对照 implementation 已落地能力做最终核对

### Manual / External Checks Needed

- 人工 review README + WHY 中英文 diff（避免双语漂移）
- 人工 review SKILL.md description 长度（避免超过推荐字数导致 skill 路由判断失准）
- v0.5.0-beta.1 发布前请至少一名 maintainer 复核

### Rollback / Follow-up Handle

- 单一 feature branch `feat/harness-context-control`，回滚通过 `git revert <merge-commit>`
- anchor.yaml 兼容性：未启用 `context_control` 的项目零影响，无需 rollback
- pre-commit blocking 紧急关闭：在 anchor.yaml 设 `pre_commit.blocking: false`，无需代码改动
- Follow-up：第二波（task-local codemap / Evidence 命令化）应在 v0.5.0-beta.1 发布并 dogfood ≥4 周后启动

## 7. Plan-Execution Diff

> 此 task 处于 PLAN 阶段；Plan-Execution Diff 在 implementation 完成后填。

- Any deviation from plan: PENDING

## 7.2 Handoff Packet

> auto-generated by `specanchor-assemble.sh --mode=handoff`
> 不要手写。重新生成请运行 `specanchor_handoff`。
> 当前为 placeholder（task 处于 PLAN 阶段；handoff packet 在 §4.7 CP-6 实现后由 dogfood 流程首次生成并回写此区段）。

- Task: harness-context-control (status: draft, phase: PLAN)
- Spec Landscape: pending generation
- Active Decisions: see §5.2 Recent (last 5)
- Evidence Status: 0 verified / 4 unverified-risk (planned)
- Read next: pending generation
- Next step: 进入 writing-plans skill 出实施计划
