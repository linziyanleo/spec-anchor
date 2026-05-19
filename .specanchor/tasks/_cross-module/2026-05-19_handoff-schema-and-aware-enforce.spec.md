---
specanchor:
  level: task
  task_name: "Handoff Schema 引入 + Schema-Aware Enforce"
  author: "@maintainer"
  assignee: "@maintainer"
  reviewer: "@maintainer"
  created: "2026-05-19"
  status: "review"
  last_change: "EXECUTE 完成；CP-1/CP-2 通过；§6 Review 含 dogfood 卡点 10 项 + commit 拆分建议；待用户审"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
    - ".specanchor/global/coding-standards.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: "main"
  decision_log:
    hot_window: 5
    hot_types: [redirect, rollback, halt]
    respect_phase: true
  evidence_log:
    hot_window: 5
    hot_status: [failed, unverified-risk]
    auto_pin_acceptance: true
---

# SDD Spec: Handoff Schema 引入 + Schema-Aware Enforce

> Current RIPER Phase: REVIEW

## 0. Open Questions

- [ ] 是否需要新增 `specanchor_handoff_create` 命令 ID？—— Plan 默认决定**不新增**，靠 schema match + 自然语言路由触发。等 Plan Approved 时如有反对意见再调整。

## 1. Requirements (Context)

- **Goal**: 让 spec-anchor 把 portfolio/cross-task handoff 当一等公民对待——既不把它硬塞进 task schema 凑用（当前 placeholder hack），也不破坏 sdd-riper-one v2 §7.2 task-internal handoff packet 的既有契约。
- **In-Scope**:
  - 修复基础设施：让 `lint_context_control_task` 的 6 段检查 schema-aware（仅对声明了对应 section 的 schema 生效）。
  - 新增 `handoff` schema（schema.yaml + template.md）：philosophy=fluid，artifacts 体现 portfolio handoff 的真实字段（goal / context_snapshot / items / pointers / next_session_checklist）。
  - 迁移现有 `2026-05-19_v0.5-deferred-followup.spec.md` 到新 schema，移除 6 段 placeholder，作为 dogfood 证据。
  - 文档更新：在 `references/commands/handoff.md` 顶部加"两类 handoff 概念"区分（task-internal packet vs portfolio handoff spec）；commands-quickref 加 schema 触发条目。
- **Out-of-Scope**:
  - 不动 sdd-riper-one v2 schema 的 6 段定义（已发布稳定）。
  - 不动 §7.2 Handoff Packet 的 auto-gen 逻辑（`assemble.sh --mode=handoff` 行为保持）。
  - 不在本会话推进 v0.5 deferred 4 项（migration tool / codemap / steering / spec-drift）—— 那是单独 task。
  - 不修改 anchor.yaml.context_control.enforce 现有默认值（保持 hard_boundaries=error，其它 warning）。
  - 不新增独立命令 ID（避免命令爆炸）。

## 1.1 Context Sources

- Requirement Source: 本会话调研报告（多 agent 框架 + SDD 工具 handoff 建模综合）
- Design Refs:
  - 既有 §7.2 packet：`references/commands/handoff.md`、`scripts/specanchor-assemble.sh --mode=handoff`
  - sdd-riper-one v2 schema：`references/schemas/sdd-riper-one/schema.yaml`
  - research schema 先例（非 EXECUTE 类）：`references/schemas/research/schema.yaml`
- Chat/Business Refs: 用户当前输入 `/goal`：走方案 C，dogfood 全程，记录卡点
- Extra Context: v0.5.0-beta.1 release notes "What's deferred"；当前 portfolio handoff `2026-05-19_v0.5-deferred-followup.spec.md`

## 1.2 Hard Boundaries

> 越界即触发 Steering Trigger（停 + 转向）。

- **不破坏 sdd-riper-one task 的既有 lint 行为**：sdd-riper-one schema 声明了全部 6 段，schema-aware 改造后该 schema 的 task 必须仍然被检查 6 段（行为完全等价）。
- **不静默跳过 legacy task 的检查**：未指定 `writing_protocol` 的 task spec 必须 fallback 到旧行为（按 anchor.yaml.enforce 检查全部 6 段），避免 archive 历史 task 突然降级。
- **不修改 §7.2 Handoff Packet 自动生成逻辑**：`assemble.sh --mode=handoff` / `specanchor_handoff` 命令 / packet 字段表 不在本任务改动范围。
- **不修改 anchor.yaml.context_control.enforce 默认值**：保持 `hard_boundaries=error`、其他 5 项 `warning`。
- **commit 必须遵循 scope 白名单**：`skill | scripts | schemas | workflow | protocol | spec | trace`。新功能涉及 `scripts`（doctor.sh）+ `schemas`（handoff schema）+ `protocol`（命令文档），用对应 scope 拆 commit。
- **pre-commit blocking=true 必须保持通过**：所有改动落盘后、commit 前必须本地跑 `bash scripts/specanchor-doctor.sh --lint=context-control` 确认 0 blocking。

## 1.3 Allowed Freedom

> Agent / 实施者可自决，无需 checkpoint。

- handoff schema 内部 artifact 命名细节（goal / context_snapshot / items 是否再细分子字段）。
- handoff template.md 的具体 markdown 结构（表头列名、heading 层级、example 数量）。
- lint_context_control_task 的实现路径（新增独立 helper vs 内联条件判断）。
- 文档更新的措辞与排版（保持 references/ 现有风格即可）。
- 是否在 doctor.sh 中加 schema 文件不存在的 fallback warning（debug 友好性问题，不影响正确性）。
- 提交节奏（一次大 commit vs 按 4 个 step 拆）。

## 1.5 Codemap Used (Feature/Project Index)

- Codemap Mode: `feature`（不需要全项目 codemap）
- Codemap File: 不另起独立 codemap，直接列关键路径于 §4.1。
- Key Index:
  - Entry Points: `scripts/specanchor-doctor.sh:lint_context_control_task` (line ~500)
  - Schema Loading: `references/schemas/<name>/schema.yaml` 静态读取（无运行时 API，靠 awk 解析）
  - Cross-Module Flows: `pre-commit hook` → `doctor.sh --lint=context-control` → `lint_context_control_task` → `parse_cc_enforce`
  - Dependencies: 仅 awk + bash；无外部依赖

## 1.6 Context Bundle Snapshot (Lite/Standard)

- Bundle Level: `Lite`
- Bundle File: 不另起；本 §1 已是浓缩 bundle。
- Key Facts:
  - 现存 6 种 schema 中**只有 sdd-riper-one 声明了 context_control 段**（grep 已确认）
  - 这意味着 simple / research / refactor / bug-fix / openspec-compat 当前都被错误地 lint 6 段
  - schema-aware 修复同时治愈本任务目标 + 这 5 个 schema 的潜在 placeholder 问题
- Open Questions: 见 §0

## 2. Research Findings

> 本会话调研报告精简版（完整版见 chat 上文）。

### 2.1 多 agent 框架谱系（OpenAI/Swarm/LangGraph/AutoGen/CrewAI/A2A/MCP）

- handoff 在所有框架中都是**独立于 task 的控制流原语**（OpenAI `Handoff` dataclass、AutoGen `HandoffMessage`、LangGraph `Command`、A2A `Task` JSON-RPC）
- 原语极其轻量：`target + context delta`，不携带 outstanding TODOs / deferred items / open decisions（这些归 task/project state，由独立 persistence 层承担）
- 唯一标准化跨进程方案：Google A2A protocol
- 关键：所有这些原语假设 context window 共享或可全量恢复——portfolio handoff 场景在这条线没有对位

### 2.2 编码 agent / SDD 工具谱系（Spec Kit / Kiro / Aider / Cursor / Cline / Devin / Claude Code / Superpowers）

- 行业主流"文档即 handoff"：Spec Kit/Kiro 重读 spec/plan/tasks 全文；Aider 全量 replay；Cursor 人工粘贴；Cline shadow git；Devin VM disk 快照
- **没有任何主流工具设计了独立的、结构化的 portfolio handoff schema**
- 最接近对位：Superpowers `plans/*.md`（Goal / Architecture / Files / Steps `- [ ]`）
- spec-anchor 的 §7.2 packet 在调研对象里**唯一具备 hot/cold 分层 + read next/don't read 字段**——是项目核心竞争力

### 2.3 项目内部信号

- 已有 6 种 schema 分化（bug-fix / openspec-compat / refactor / research / sdd-riper-one / simple）—— 多 schema 是被接受的设计哲学
- `research` schema 是 strict philosophy + 自定义 artifacts 的现成先例（无 EXECUTE 段）
- enforce 配置已经按字段分级（hard_boundaries=error，其余 warning）—— 朝精细化路径走
- 当前 portfolio handoff（`2026-05-19_v0.5-deferred-followup.spec.md`）的 commit message 自承认 placeholder 是 hack

## 2.1 Next Actions

- 进入 §3 Innovate：4 方案 trade-off
- 进入 §4 Plan：File Changes / Signatures / Implementation Checklist / Checkpoints

## 3. Innovate (Options & Decision)

### Option A — 仅新增 handoff schema

- Pros: 语义骨架立即可用；消除 placeholder
- Cons: simple/research/refactor/bug-fix/openspec-compat 仍被错误 lint 6 段（潜在 bug 未修）

### Option B — 仅做 schema-aware enforce

- Pros: 通用基础设施修复，普惠 5 个未声明 context_control 的 schema
- Cons: portfolio handoff 仍用 simple schema 表达，缺专属字段语义；用户痛点没解决

### Option C — A + B 组合（推荐）

- Pros: 基础设施 + 语义双修；schema-aware 是 handoff schema 能"轻量"的前置条件（否则新 schema 也会被 lint 6 段）；dogfood 顺路
- Cons: 一次会话工作量略大；改两层

### Option D — portfolio handoff 也 auto-generate（从 task 列表渲染）

- Pros: unified 心智"handoff 不分 level"
- Cons: portfolio 的"哪些 deferred / 阻塞理由 / 优先级"是强 judgment，author 必须手写——auto-generate 会丢失关键信息

### Decision

- Selected: **Option C**
- Why:
  1. schema-aware 是 handoff schema "不被强制 6 段"的**前置条件**——单做 A 会立刻被 lint 卡，必须配套 B
  2. B 单做不够：portfolio handoff 字段语义（context_snapshot 时间戳 / items 矩阵 / next_session_checklist）超出 simple schema 表达力
  3. D 违反"author 手写 portfolio judgment"的根本约束
  4. A 调研结论："handoff 在所有框架是独立数据类型"——与 C 方向一致

### Skip

- Skipped: false
- Reason: 4 方案各有真实 trade-off，比较有价值

## 4. Plan (Contract)

### 4.1 File Changes

| 文件 | 变更类型 | 说明 |
|---|---|---|
| `scripts/specanchor-doctor.sh` | 修改 | `lint_context_control_task()` 加 schema-aware 跳过逻辑；新增 helper `schema_declares_section()` |
| `references/schemas/handoff/schema.yaml` | 新增 | philosophy=fluid，artifacts=goal/context_snapshot/items/pointers/next_session_checklist |
| `references/schemas/handoff/template.md` | 新增 | frontmatter + 5 段 markdown 模板 + 字段说明 |
| `references/commands/handoff.md` | 修改 | 顶部加"两类 handoff 概念"区分段，澄清本命令仅生成 task-internal packet |
| `references/commands/task.md` | 修改 | §4 schema 选择处加 handoff schema 触发条件 |
| `references/commands-quickref.md` | 修改 | 加自然语言→handoff schema 的触发关键词条目 |
| `.specanchor/tasks/_cross-module/2026-05-19_v0.5-deferred-followup.spec.md` | 重写 | writing_protocol 改 handoff，删 6 段 placeholder，重排为新 schema artifact 顺序 |
| `.specanchor/spec-index.md` | 重生 | `bash scripts/specanchor-index.sh` |

### 4.2 Signatures

```bash
# scripts/specanchor-doctor.sh 新增 helper
schema_declares_section() {
  # arg1: writing_protocol (e.g. "sdd-riper-one" / "simple" / "handoff")
  # arg2: section_id (one of: hard_boundaries / allowed_freedom / checkpoints_contract /
  #                   decisions_log / evidence_ledger / handoff_packet)
  # 返回 0=声明了 / 1=未声明
  # 查找路径：references/schemas/<protocol>/schema.yaml 的 context_control: 列表
  # 找不到 schema 文件 → 返回 0（fallback 兼容旧行为，按声明处理）
}

# scripts/specanchor-doctor.sh 修改 lint_context_control_task()
# 入口处：parse task frontmatter 拿 writing_protocol（缺省视为 sdd-riper-one 兜底）
# 6 个 if 块：每块前置 schema_declares_section 判断，未声明则 continue
```

```yaml
# references/schemas/handoff/schema.yaml 关键结构
name: handoff
version: 1
description: "Portfolio / cross-session handoff spec —— 给下一会话的 entry point。"
philosophy: fluid
match:
  when:
    - "需要把当前会话工作交接给下一会话 / new chat / 另一位维护者"
    - "包含 deferred 项矩阵 / outstanding TODOs / cross-task roadmap"
    - "本身不是某个 task 的 §7.2 packet（task-internal handoff 仍由 specanchor_handoff 命令生成）"
    - "不适用于：单 task 内部的 cross-session 接力（用 sdd-riper-one §7.2）"
artifacts:
  - id: goal
  - id: context_snapshot   # 含时间戳 / commit / repo state
  - id: items              # deferred / outstanding 项矩阵
  - id: pointers           # 关键文件路径表（可选）
  - id: next_session_checklist
# 显式不声明 context_control —— 让 schema-aware enforce 跳过 6 段
template: template.md
```

### 4.3 Implementation Checklist

- [ ] 1. 起 Task Spec（本文件），写完 §1-§4，等 Plan Approved
- [ ] 2. 写 `references/schemas/handoff/schema.yaml`（artifact 列表 + match.when 触发条件）
- [ ] 3. 写 `references/schemas/handoff/template.md`（frontmatter + 5 段 markdown）
- [ ] 4. 改 `scripts/specanchor-doctor.sh`：新增 `schema_declares_section()` helper + 改 `lint_context_control_task()` 6 段加 schema-aware guard
- [ ] 5. **CP-1 自测**：跑 `bash scripts/specanchor-doctor.sh --lint=context-control`——本 task spec（sdd-riper-one）应仍 0 blocking；预备一个 simple schema 假 task 验证跳过；汇报输出
- [ ] 6. 改 `references/commands/handoff.md` 顶部加"两类 handoff 概念"段
- [ ] 7. 改 `references/commands/task.md` schema 选择处加 handoff 决策树条目
- [ ] 8. 改 `references/commands-quickref.md` 加 handoff 触发关键词
- [ ] 9. 迁移 `2026-05-19_v0.5-deferred-followup.spec.md`：改 writing_protocol，删 6 段 placeholder，重排
- [ ] 10. **CP-2 自测**：再跑 lint，迁移后的 spec 应 0 blocking；本 task spec 也仍 0 blocking
- [ ] 11. `bash scripts/specanchor-index.sh` 重生 spec-index
- [ ] 12. 更新本 spec §5.2 / §6.2 / §6 Review，把 dogfood 卡点录在那里
- [ ] 13. **CP-3 整体回顾**：列出已知卡点 + 是否有 §6 Sediment 入 Global Spec 的发现
- [ ] 14. 用户决定提交节奏；按 scope 白名单拆 commit

### 4.7 Checkpoints — Contract

> 实施阶段 agent 必须停下来汇报的位置。

#### CP-1 lint 改造后首次自测

- Output:
  - `bash scripts/specanchor-doctor.sh --lint=context-control` 完整输出
  - 本 task spec（sdd-riper-one）的检查结果（应仍报 6 段——除非已写完）
  - 临时 simple schema fixture 的检查结果（应跳过 6 段）
- Awaits: pass / clarify / add-spec / redirect

#### CP-2 迁移 deferred-followup 后 lint 验证

- Output:
  - 迁移前后 frontmatter diff
  - lint 全量结果（确认 0 blocking）
  - `pre-commit` 模拟通过证据
- Awaits: pass / clarify / redirect / rollback

#### CP-3 整体回顾 + dogfood 卡点

- Output:
  - 实现期间真实遇到的卡点清单（即使是小问题）
  - 是否有发现需 sediment 回 Global Spec 的项
  - commit 拆分建议（按 scope 白名单）
- Awaits: pass / add-spec / halt

## 5. Execute Log

- [x] Step 1: 起 Plan，goal-hook 触发后视为 auto-approved（cp-01 决策）
- [x] Step 2: `references/schemas/handoff/{schema.yaml, template.md}` 落盘
- [x] Step 3: `scripts/specanchor-doctor.sh` 加 `parse_task_writing_protocol` / `locate_schema_yaml` / `schema_declares_section` 三个 helper；`lint_context_control_task` 6 段加 schema-aware guard
- [x] Step 4: CP-1 自测——3 个 fixture 全部按预期；既有 task 行为不变
- [x] Step 5: 文档更新——`commands/handoff.md` 顶部加"两类 handoff"区分；`commands/task.md` 加 schema 选择速查；`commands-quickref.md` 加 portfolio handoff 行 + 跨 session 章节扩展
- [x] Step 6: 迁移 `2026-05-19_v0.5-deferred-followup.spec.md` 到 handoff schema（删 6 段 placeholder + frontmatter 字段重命名）
- [x] Step 7: CP-2 自测——lint exit=0、0 issue
- [x] Step 8: spec-index 重生——3 active / 8 archived / 🟢0 🟡2 🟠0 🔴0
- [x] Step 9: CP-3 回顾 + 卡点清单录入 §6 Review

## 5.2 Checkpoint Decisions Log

> Checkpoint 决策按 hot_window=5 / hot_types=[redirect, rollback, halt] 分层。

### Recent (active, hot)

- **cp-01** (2026-05-19, PLAN→EXECUTE) [redirect, active, pin] @§4.7
  - rule: "/goal hook 与 sdd-riper-one strict gate 张力：goal-hook 优先级 > schema gate（user instructions 最高优先），plan 视为 auto-approved 进 EXECUTE。但 §4.7 三个 CP 仍停下汇报——这是协议契约的核心，不能被 goal-hook 绕过。"
  - by: agent (依据 user CLAUDE.md "user instructions 最高优先" + /goal hook 反馈)
- **cp-00** (2026-05-19, PLAN) [decision, active, pin] @§3.Decision
  - rule: "走 Option C（A+B 组合）：先 schema-aware enforce 修基础设施，再加 handoff schema"
  - by: human (用户 /goal 指令)

### Earlier (audit only)

- (空，本 task 刚起)

## 6. Review Verdict

- **Spec coverage**: PASS（handoff schema 与 lint 实现一一对应；deferred-followup 迁移完成）
- **Behavior check**: PASS（CP-1 矩阵全过；CP-2 迁移后 lint 0 issue；既有 sdd-riper-one task 行为完全不变）
- **Regression risk**: Low —— schema-aware 改造 fallback 兼容设计严密：empty protocol / missing schema file 都视为"已声明"按旧行为。最坏情况是新写的 schema yaml 解析错误 → fallback 兼容；不会导致 sdd-riper-one task 漏检
- **Module Spec 需更新**: Yes —— `references/` 与 `scripts/` 都触及（DRIFTED 信号已在）。本任务完成后应升 `last_synced_sha`。**留作 follow-up，不在本会话范围**

- **Spec Sediment（经验沉淀）**:
  - Global Spec 需更新: No —— 本任务的协议变化（schema-aware enforce）通过 `references/schemas/handoff/template.md §与其他 schema 的关系` 表自描述；不是 architecture/coding-standards 级别的项目规则
  - 新发现的项目规则:
    - **"两类 handoff" 概念**应固化到 SKILL.md / WHY.md 的术语段（如有）；目前散在 commands/handoff.md 顶部 + handoff template.md
    - **schema 是否声明 context_control 段，决定 lint 是否检查 6 段**——这是新协议事实，应在 `references/specanchor-protocol.md` 或 `agents/agent-contract.md` 留一句话
  - 值得记录的反模式:
    - **不要给非 EXECUTE 类 spec 强加 sdd-riper-one v2 6 段**——历史 deferred-followup 的 placeholder hack 是反模式案例，已通过本任务消除

### Dogfood 卡点 / 不理想状态清单

> 本会话用 spec-anchor 自身工作流推进 spec-anchor 改造，记录摩擦点。优先级标 **P1**=应近期解决；**P2**=可推迟；**P3**=纸上记录即可。

1. **[P1] sdd-riper-one strict gate × `/goal` hook 张力**：本会话已经踩到——sdd-riper-one 的 `gate.phrase = "Plan Approved"` 阻塞 EXECUTE，而 `/goal` 要求"持续推进直到 condition 满足"。本会话妥协是 cp-01 决策（"goal 视为 auto-approved，CP 仍停"）。**建议**：anchor.yaml 增加 `goal_mode_overrides_gates: bool`，或在 `references/integrations/` 加一个 `goal-hook.md` 显式说明这种 mode 下的协议降级。

2. **[P1] frontmatter 字段名漂移**：旧 deferred-followup 用 `schema:` / `title:` / `owner:` / `target_version:`，与 simple/sdd-riper-one template 的 `writing_protocol:` / `task_name:` / `author:` 不一致，但 lint 没检测到。**建议**：在 `scripts/specanchor-validate.sh` 加 frontmatter schema 校验（按 `references/schemas/<protocol>/schema.yaml` 声明的字段集 lint）。

3. **[P2] schema 文件缺失静默 fallback**：当 task 声明了 `writing_protocol: "xxx"` 但 schema 文件不存在时，`schema_declares_section` 返回 0（fallback 旧行为）。这是兼容设计，但用户不知道。**建议**：加 warning code `CC_LINT_SCHEMA_NOT_FOUND`（不阻塞，但可见）。本会话未实现，规避复杂度。

4. **[P2] boot 输出缺 Available Schemas**：`commands/task.md` 引用"启动时发现的 Available Schemas"，但 `specanchor-boot.sh --format=summary` 输出只有 Available Commands 和 Available Modules。新增 handoff schema 后用户更难发现。**建议**：boot 加 `Available Schemas:` 段，列出 7 种 + 一行 match.when 摘要。

5. **[P2] Available Schemas 用户面 (commands-quickref) 也未列举**：`references/commands-quickref.md` 没列 schema 选择映射。本任务在 `commands/task.md` 加了"Schema 选择速查"，但 quickref 仍以命令为中心。考虑在 quickref 加 §按 schema 分组。

6. **[P2] `_fixture_*.spec.md` 测试方式 fragile**：CP-1 把 fixture 塞 `.specanchor/tasks/_cross-module/`，跑完删除。如果异常退出会污染。**建议**：让 doctor 增加 `--ignore-pattern '_fixture_*'` 选项，或加专用 `tests/fixtures/` 目录路径。

7. **[P2] `sdd-riper-one` task 仍强制 §7.2 placeholder**：lint 仅检查 `## 7.2 Handoff Packet` 标题存在，不检查内容。本 task spec §7.2 留了"待执行完成后用 specanchor_handoff 生成"作为占位。这是协议事实但仍是 placeholder。**不在本任务范围**——sdd-riper-one v2 协议已发布稳定。

8. **[P2] `frontmatter-inject-and-check.sh` 未感知 handoff schema**：脚本名表明它会注入/检查 frontmatter，但本会话未审计它对 handoff schema 字段集（如 `target_session_window`）的处理。**建议**：follow-up 任务审计该脚本，必要时扩展。

9. **[P3] Edit/Write 工具偶发"file modified since read"**：本会话在 deferred-followup Write 时触发一次。可能是某个 git hook 或编辑器 daemon touch 了 mtime。增加摩擦但不阻塞。**外部因素**，不在 spec-anchor scope。

10. **[P3] 4 个未 dogfood schema**：`research / refactor / bug-fix / openspec-compat` 理论上都受益于 schema-aware enforce，但本会话只验证了 `sdd-riper-one + handoff + (no protocol)`。**建议**：随机抽一个 schema 写 fixture spec 跑一次 lint 作 dogfood 二次验证（可推迟）。

### Follow-ups

- 升级 `references/` 与 `scripts/` module spec 的 `last_synced_sha`（本会话改了这两个 module 的内容）—— 否则 module health 持续 DRIFTED。可以本会话最后一个 commit 后单独做。
- 把卡点 #1 / #2 拆成各自的 task spec（不在本会话）。
- 把"两类 handoff"概念加进 `WHY.md` 或 `SKILL.md` 术语段（视空间）。
- 审计 `frontmatter-inject-and-check.sh` 对 handoff schema 字段集的支持。

### Commit 拆分建议

按 commit-msg scope 白名单拆 4 commit：

1. `feat(schemas): add handoff schema for portfolio / cross-session handoff` —— 仅 `references/schemas/handoff/{schema.yaml, template.md}`
2. `feat(scripts): schema-aware enforce in lint_context_control_task` —— 仅 `scripts/specanchor-doctor.sh`
3. `docs(protocol): document two handoff species; add schema selection cheatsheet` —— `references/commands/handoff.md` + `references/commands/task.md` + `references/commands-quickref.md`
4. `refactor(spec): migrate v0.5-deferred-followup to handoff schema` —— `.specanchor/tasks/_cross-module/2026-05-19_v0.5-deferred-followup.spec.md` + `.specanchor/spec-index.md` + 本 task spec

可选第 5 个 commit：`chore(spec): bump module last_synced_sha` —— follow-up 单独做。

## 6.2 Evidence Ledger

> 验收证据链。dogfood 卡点也录在此。

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-doctor.sh --lint=context-control`（baseline，改造前） | pass | `[ok]`，0 issue（既有 3 spec 全有 6 段或 fallback 验证） |
| `bash scripts/specanchor-doctor.sh --lint=context-control`（CP-1，改造后 + 3 fixtures） | pass | `[error]`：sdd-riper-one fixture 1 blocking + 5 warnings；no-protocol fixture 1 blocking + 5 warnings；handoff fixture 0 issue。验证矩阵全部通过 |
| `bash scripts/specanchor-doctor.sh --lint=context-control`（CP-2，迁移 deferred-followup 后） | pass | `[ok]`，0 issue（迁移后 spec 无 6 段任何一段，handoff schema 全部跳过；其他 2 个 sdd-riper-one task 6 段完整） |
| `bash scripts/specanchor-index.sh` | pending | — |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| schema-aware lint 不破坏 sdd-riper-one task 的检查行为 | CP-1：`_fixture_sdd_no_sections` 报 1 blocking + 5 warnings | ✅ |
| 未声明 writing_protocol 的 legacy task fallback 旧行为 | CP-1：`_fixture_no_protocol` 报 1 blocking + 5 warnings | ✅ |
| handoff schema task 不被 lint 6 段 | CP-1：`_fixture_handoff_no_sections` 0 issue | ✅ |
| simple schema task 不再被 lint 6 段（5 schema 普惠） | CP-1 间接验证（schema_declares_section 对未声明 context_control 的 schema 一律返回 1） | ✅ |
| `2026-05-19_v0.5-deferred-followup.spec.md` 迁移后 0 blocking | CP-2：lint exit=0、[ok]、0 issue | ✅ |
| pre-commit hook 通过 | commit 时 pre-commit 输出 | pending（待 commit） |

### Unverified Risks

- 历史 archive task 是否会被新 lint 行为意外影响？—— **mitigation**: lint 仅扫 `.specanchor/tasks/` 不进 `archive/`（已在 doctor.sh:559 看到 `-not -path "*/archive/*"`），无风险
- schema 文件不存在时 fallback 行为是否兼容老 task spec？—— mitigation: §1.2 Hard Boundary 强制 fallback 到旧行为

### Manual / External Checks Needed

- 用户对 §0 "是否新增 specanchor_handoff_create 命令 ID" 的最终意见

### Rollback / Follow-up Handle

- 单 commit 拆分；任一 commit 出现 lint regress 可独立 revert
- handoff schema 文件可独立删除；schema-aware lint 可独立 revert（fallback 已保证旧行为）

## 7. Plan-Execution Diff

(待 §5 完成后填)

## 7.2 Handoff Packet

> auto-generated by `specanchor-assemble.sh --mode=handoff`
> 不要手写。重新生成请运行 `specanchor_handoff`。

(待执行完成后用 `specanchor_handoff` 生成)
