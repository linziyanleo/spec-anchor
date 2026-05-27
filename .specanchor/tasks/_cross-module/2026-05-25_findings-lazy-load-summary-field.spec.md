---
specanchor:
  level: task
  task_name: "Findings Lazy-Load: summary frontmatter + 分级载荷"
  author: "@方壶"
  assignee: "@方壶"
  reviewer: "@codex"
  created: "2026-05-25"
  status: "draft"
  last_change: "v1: 初稿，承接 v0.6 finding artifact 的 lazy-load 优化"
  related_modules:
    - ".specanchor/modules/references.spec.md"
    - ".specanchor/modules/scripts.spec.md"
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

# SDD Spec: Findings Lazy-Load (summary frontmatter + 分级载荷)

> Current RIPER Phase: PLAN

## 0. Open Questions

- [ ] Q1: `affects` 字段当前 schema 允许 `module / path / contract` 三种条目，匹配 `--files=` 时是否要全部支持？（提议：v0.6 阶段只支持 `module` + `path`，`contract` 留 v0.7。）
- [ ] Q2: 多个 finding 同时命中同一组目标文件时，bundle 排序规则——按 `impact desc → created desc` 还是按 `match precision desc → impact desc`？（提议：`match precision → impact desc → created desc`，长前缀优先。）
- [ ] Q3: 老 finding（无 `summary` 字段）的 grace period 如何标识？（提议：validate 在 status=candidate 时强制；status∈{accepted,superseded,archived} 时 doctor warn 不 fail。）
- [ ] Q4: assemble 扫描 findings 目录的成本上限——上限多少 finding 后开始截断？（提议：默认 cap 50，按 visibility 优先级过滤后取 top-N，可由 `anchor.yaml.context.budget.max_findings` 覆写。）

## 1. Requirements (Context)

- **Goal**: 给 finding 加 `summary` frontmatter 字段，让 Context Bundle 默认只挂 finding 的"目录卡片"（id / type / impact / affects / summary / path），agent 看着这张卡片自己决定要不要 Read 全文；同时按 `visibility` 把载荷分级（full / summary / title），让 immediate 类强制 inline、低优 finding 不打扰主上下文。
- **In-Scope**:
  1. `references/templates/finding-template.md`：frontmatter 加 `summary: ` 字段 + 写作指引（≤120 chars 单行，"主语+事实+锚点"形态）。
  2. `references/concepts/findings-ledger.md`：补 §3 frontmatter schema 与 §4 visibility/load 映射的对照说明。
  3. `scripts/specanchor-finding.sh`：`new` 子命令加 `--summary=<text>` **必选参数**，校验非空 + 长度 ≤ 120 + 不是占位文本（`<...>` 形态）。
  4. `scripts/specanchor-validate.sh`：lint findings 时校验 `summary` 字段存在 / 长度 / 非占位；按 status 分宽容期（candidate 强制 fail；其他 warn）。
  5. `scripts/specanchor-assemble.sh`：
     - 主动扫描 `.specanchor/findings/` 按 `affects` 字段与输入 `--files=` 做前缀匹配，命中即注入 `layers.finding[]`。
     - 按 visibility 决定 `load` 标签：`immediate→full` / `sediment_queue→summary` / `handoff→title` / `hidden→ 不出现`。
     - bundle item 元数据补字段：`id` / `type` / `impact` / `affects` / `summary`。
     - `agent_instructions` 段追加 hint：`load=full MUST be read; load=summary/title 按相关性自行 Read 全文`。
  6. `scripts/specanchor-doctor.sh`：findings 缺 `summary` 字段且非 candidate 时，输出 backfill 建议（不阻塞）。
  7. `scripts/specanchor-doctor.sh` / `validate.sh` 已有 finding lint 路径如未启用，本任务一并接通（参见 §4.1 File Changes）。

- **Out-of-Scope**:
  - 不动 sediment proposal 协议——summary 字段不进 SP frontmatter，proposal 只在正文引用 finding。
  - 不引入 inline-content bundle（agent 仍通过 path Read 文件，bundle 只携带 metadata + summary 字符串）。
  - 不实现 `contract` 类 affects 匹配（留 Q1 决策后单独 PR）。
  - 不重构 freshness 算法（继续用现有 mtime-based）。
  - 不动 boot 脚本（boot --agent 模式由现有 assemble 包装，新逻辑沉到 assemble）。

## 1.1 Context Sources

- Requirement Source: 与用户 2026-05-25 多轮讨论达成的 lazy-load 设计共识（chat 摘要见本 spec §2）
- Design Refs:
  - `.specanchor/tasks/_cross-module/2026-05-24_context-system-construction.spec.md` §4.1 / §4.2（v0.6 finding & bundle 框架）
  - `references/concepts/findings-ledger.md` §3 / §4 / §6
  - `references/agents/context-utilities.md` §3
- Chat/Business Refs: 用户对 Skill `description` 字段作为 lazy-load 信号的类比
- Extra Context: 当前 `specanchor-assemble.sh:434-445` 只做被动 source_type 推断，无主动扫描

## 1.2 Hard Boundaries

> 越界即触发 Steering Trigger（停 + 转向）。

- 不允许 finding 全文自动 inline 进 bundle JSON（除 visibility=immediate 外）——避免 bundle 体积爆炸。
- 不允许在写入端绕过 `--summary` 必选校验创建 finding（包括手动 `cp template`）；validate.sh 必须在 candidate 上 fail。
- 不允许 assemble 在没有 `--files` 入参时主动注入 finding（避免 boot 起步阶段污染上下文）。
- 不允许 agent 把 `summary` 字段写超过 120 chars——validate 必须 fail。
- 不允许动 `specanchor.context_bundle.v1` 的现有字段语义；新增字段必须向后兼容（旧消费者忽略未知字段不报错）。
- 不允许在本任务内同步修改 sediment proposal 协议或老 finding 的物理文件。

## 1.3 Allowed Freedom

> Agent / 实施者可自决，无需 checkpoint。

- summary 字段在 frontmatter 内的位置（推荐紧跟 `id` 之后）。
- `--summary` 参数的 long-only / short-flag 形式（推荐 long-only `--summary=<text>`）。
- validate.sh / doctor.sh 输出文案。
- bundle `agent_instructions` hint 的具体措辞（保留语义即可）。
- assemble 扫描 findings 的实现方式（shell glob vs find），只要满足 cap 与排序规则。

## 1.5 Codemap Used (Feature/Project Index)

- Codemap Mode: 不使用（spec-anchor 自身仓库无 codemap）
- Codemap File: N/A
- Key Index:
  - Entry Points: `scripts/specanchor-assemble.sh` (装配主入口) / `scripts/specanchor-finding.sh` (写入主入口) / `scripts/specanchor-validate.sh` (lint)
  - Cross-Module Flows: agent → finding.sh new → validate.sh → assemble.sh → bundle JSON → agent 消费
  - Dependencies: bash 3.2+ / git mtime / awk / sed (现有依赖，无新增)

## 1.6 Context Bundle Snapshot

- Bundle Level: Standard
- Bundle File: 不外置（用 boot 输出做 in-task 引用）
- Key Facts:
  - v0.6 finding artifact 已落地（visibility / freshness / source_type 字段已实现）
  - `specanchor.context_bundle.v1` schema 已实装（layers.finding[] 字段已渲染）
  - 缺口：assemble **不主动扫**，summary 字段**不存在**，载荷**不分级**
- Open Questions: 见 §0

## 2. Research Findings

### 2.1 设计共识来源（chat 摘要）

- 用户提出："Findings 只显性显示缩略 summary/title 级别，然后让 agent 自己选择去看"
- 用户提出："学习 Skill 的策略，用 yaml 头写 summary。在 findings 写作的时候限制"
- 共识 1：写作端硬约束（template + finding.sh + validate.sh）比读取端启发式更稳
- 共识 2：summary 长度 120 chars 上限（够写完整结论，不爆 bundle 行宽）
- 共识 3：visibility 决定载荷粒度（immediate=full / sediment_queue=summary / handoff=title / hidden=不出现）
- 共识 4：bundle agent_instructions 加显式 hint 防止 agent 忽略
- 共识 5：老 finding 走宽容期（candidate 强制；其他 warn）

### 2.2 当前实现现状

- `specanchor-assemble.sh:434-445`：被动推断 source_type=finding（path 包含 `/findings/`）
- `specanchor-assemble.sh:506-537`：bundle 输出按 source_type 分组到 `layers.finding[]`
- `specanchor-assemble.sh`：**无主动扫描** `.specanchor/findings/` 目录的逻辑
- `specanchor-finding.sh`：`new` 子命令已实装；frontmatter 字段不含 `summary`
- `specanchor-validate.sh`：finding lint 路径需确认是否已接（待执行阶段确认）
- `infer_freshness()`：用 git/file mtime 推断，对 finding 与 spec 一视同仁，不读 visibility 字段

### 2.3 风险与不确定项

- R1: assemble 扫描 findings 目录可能放大 N×M（M=输入文件数 × N=findings 数）匹配成本——需要 cap（见 Q4）。
- R2: `affects` 字段是 list，每个条目可能是 module/path/contract——匹配规则要明确（见 Q1）。
- R3: 强制 `--summary` 会破坏现有调用者（如 sdd-riper-one 流程内自动建 finding 的脚本）——需要全局 grep 确认没有调用方。
- R4: validate.sh 升级可能让 CI 在已有项目上 break——必须跑全局现有 finding 库做 dry-run。

## 2.1 Next Actions

- 进入 Plan 阶段拆 §4 Implementation Checklist
- 在 Plan Approved 后才开始写代码

## 3. Innovate (Optional: Options & Decision)

### Option A: 主动扫描 + summary metadata（agent 看卡片自决）

- Pros: 默认安全（不 inline 全文），bundle 紧凑，agent 有自由度
- Cons: 依赖 agent 自觉 Read 全文；弱模型可能跳过

### Option B: visibility-driven inline content

- Pros: immediate 类强制可见，agent 不会漏
- Cons: bundle 体积膨胀，与 v0.6 path-only 哲学冲突

### Option C: 两者结合（visibility 决定载荷形态）

- immediate → 全文 inline 进 bundle metadata
- sediment_queue → 只挂 summary 字符串
- handoff → title-only（id/type/impact/affects+path，无 summary 字符串）
- hidden → 不出现

### Decision

- **Selected: Option C**
- **Why**:
  - 保留 path-only 兼容（agent 仍 Read 文件拿全文）
  - summary 字段提供"卡片"信息，agent 自决相关性
  - immediate 类靠 `load=full` 标签 + agent_instructions hint 双保险，不靠 inline content（不破坏 bundle 哲学）
  - 等价于把 Option A 的"卡片信息"用 summary 字段实例化，把 Option B 的"强制可见"用 hint 而非 inline 实现
- **Rejected**: B 单独——会破坏 bundle path-only 哲学
- **Rejected**: A 单独——immediate 类无强制保险

## 4. Plan (Contract)

### 4.1 File Changes

- `references/templates/finding-template.md`: frontmatter 加 `summary: ` 占位行 + 注释规则；正文填写指引补"summary 字段写作准则"段
- `references/concepts/findings-ledger.md`:
  - §3 Frontmatter Schema 加 `summary: <120 chars one-liner>` 字段说明
  - §4 visibility/load 映射加表格（visibility → bundle load 标签）
  - §6 Agent 如何消费 Finding 段补充"agent 看 summary 自决 Read 全文"流程
- `scripts/specanchor-finding.sh`:
  - `new` 子命令解析 `--summary=<text>` 必选参数
  - 校验 `${#summary} -ge 1 && ${#summary} -le 120`
  - 校验非占位文本（拒绝以 `<` 开头且以 `>` 结尾的 stub）
  - frontmatter 渲染时把 `summary:` 行写到 `id:` 之后
  - `usage()` 文案更新（含 `--summary` Required 段落）
- `scripts/specanchor-validate.sh`:
  - 新增 finding 校验入口（如已存在则扩展规则）
  - 必填字段加 `summary`
  - 长度校验 ≤ 120
  - 非占位校验
  - status=candidate 时 fail；其他 status warn（不 fail）
- `scripts/specanchor-assemble.sh`:
  - 新增 `discover_findings()` helper：扫 `.specanchor/findings/*.md`，解析 frontmatter 取 `affects` / `visibility` / `summary` / `id` / `type` / `impact`
  - 按 `affects` 与 `FILES_REQUESTED` 做路径前缀匹配（含 module 名 → 路径转换；module path 由 module spec 的 `module_path` 字段定）
  - 按 visibility 过滤：`hidden` 排除
  - 按 visibility 映射 `load` 字段：`immediate→full / sediment_queue→summary / handoff→title`
  - 排序：长前缀匹配优先 → impact desc → created desc
  - cap 默认 50（参数 `--max-findings=N`，可由 `anchor.yaml.context.budget.max_findings` 覆写）
  - 注入 `FILES_TO_READ_PATHS` / `FILES_TO_READ_LOADS` / `FILES_TO_READ_REASONS` 数组
  - bundle JSON 渲染：在 `layers.finding[]` 元素加 `id` / `type` / `impact` / `affects` / `summary` 字段
  - `agent_instructions` 段加 hint：N findings attached, `load=full` MUST read
- `scripts/specanchor-doctor.sh`:
  - 加 finding-without-summary 检查；非 candidate finding 缺 summary 输出 warn（不 fail）
- `scripts/lib/`（如需共享 frontmatter parser）：抽 `parse_finding_frontmatter()` 到共享 lib（仅当 finding.sh / validate.sh / assemble.sh / doctor.sh 出现重复解析逻辑）

### 4.2 Signatures

- `specanchor-finding.sh new --topic=<slug> --summary=<text> [其他原有参数]`
- `specanchor-assemble.sh --files=<paths> --intent=<desc> [--max-findings=<N>] [其他原有参数]`
- `discover_findings()` 内部函数：
  - 输入：`FILES_REQUESTED[]`（绝对/相对路径数组）+ `MAX_FINDINGS`（int）
  - 输出：填充全局数组 `DISCOVERED_FINDING_PATHS[]` / `DISCOVERED_FINDING_LOADS[]` / `DISCOVERED_FINDING_META_*`（每个字段一组并行数组，避免引入关联数组依赖 bash 4）
- finding 默认 frontmatter 新格式：

  ```yaml
  ---
  id: F-YYYYMMDD-NNN
  summary: <120 chars one-liner>           # 新增字段
  type: ...
  status: candidate
  ...
  ---
  ```

### 4.3 Implementation Checklist

- [ ] 1. 写作端：finding-template.md 加 summary 字段占位 + 写作准则注释段
- [ ] 2. 写作端：finding-template.md 文末填写指引补"summary 字段"段
- [ ] 3. 写作端：specanchor-finding.sh 加 `--summary` 解析 / 校验 / 渲染（不 break 老 stdout）
- [ ] 4. 写作端：specanchor-finding.sh `usage()` 更新
- [ ] 5. 写作端：findings-ledger.md §3 frontmatter schema 补 summary 字段
- [ ] 6. 写作端：findings-ledger.md §4 加 visibility→load 映射表
- [ ] 7. 验证端：specanchor-validate.sh 加 finding summary lint（含 status 宽容期）
- [ ] 8. 装配端：specanchor-assemble.sh 抽 frontmatter parser 到 lib（如需要）
- [ ] 9. 装配端：specanchor-assemble.sh 实现 `discover_findings()` 主动扫描
- [ ] 10. 装配端：specanchor-assemble.sh 实现 affects 与 files 的前缀匹配
- [ ] 11. 装配端：specanchor-assemble.sh 实现 visibility → load 映射
- [ ] 12. 装配端：specanchor-assemble.sh 实现 cap + 排序（前缀长度 → impact → created）
- [ ] 13. 装配端：specanchor-assemble.sh bundle 输出 layers.finding[] 加 summary/id/type/impact/affects
- [ ] 14. 装配端：specanchor-assemble.sh agent_instructions hint
- [ ] 15. 文档：findings-ledger.md §6 补"agent 消费 summary 自决"流程
- [ ] 16. 文档：context-utilities.md §2 / §3 加新字段说明 + Q&A
- [ ] 17. 巡检端：specanchor-doctor.sh 加 backfill warn
- [ ] 18. 验证：跑 finding.sh new 创建测试 finding，断言 frontmatter 含 summary
- [ ] 19. 验证：跑 validate.sh 命中 candidate fail / accepted warn
- [ ] 20. 验证：跑 assemble.sh --files 命中 finding，断言 bundle layers.finding[] 含新字段
- [ ] 21. 验证：跑 assemble.sh --files 不命中 hidden finding，断言 bundle 排除
- [ ] 22. 验证：跑 assemble.sh 大量 finding 时 cap 生效

### 4.7 Checkpoints — Contract

#### CP-1 写作端落地（步骤 1-6 完成后）

- Output:
  - `specanchor-finding.sh new --topic=test --summary="dry run"` 输出新 finding 文件路径
  - 新文件 frontmatter 含 `summary: dry run`
  - 不传 `--summary` 时报错退出码 64
- Awaits: pass / clarify / add-spec / redirect

#### CP-2 装配端联通（步骤 8-14 完成后）

- Output:
  - `specanchor-assemble.sh --files=<repo file> --intent=test --bundle-schema=context_bundle.v1` 输出 JSON
  - JSON `layers.finding[]` 至少含一个新字段（id/summary/type/impact/affects）
  - `agent_instructions[]` 含 lazy-load hint 字符串
- Awaits: pass / clarify / add-spec / redirect

#### CP-3 全链路验收（步骤 18-22 完成后）

- Output:
  - 所有验证命令 pass
  - 现有 .specanchor/findings/ 老 finding（如有）在 candidate 状态外不 fail validate
  - `specanchor-doctor.sh` 对老 finding 输出 backfill warn
- Awaits: pass / redirect / rollback

## 5. Execute Log

- [ ] Step 1: （待 Plan Approved 后填）

## 5.2 Checkpoint Decisions Log

### Recent (active, hot)

（待 Execute 阶段填）

### Earlier (audit only)

（待 Execute 阶段填）

## 6. Review Verdict

- Spec coverage: pending
- Behavior check: pending
- Regression risk: Medium（涉及 assemble 主流程；validate.sh 升级可能影响 CI）
- Module Spec 需更新: Yes（references.spec.md 加 finding-template / findings-ledger 行；scripts.spec.md 加 finding.sh / assemble.sh 新签名）
- Spec Sediment:
  - Global Spec 需更新: No
  - 新发现的项目规则: pending
  - 值得记录的反模式: pending
- Follow-ups:
  - `affects: contract:<name>` 类匹配（Q1 留 v0.7）
  - inline-content bundle mode（不在本任务，未来视 agent 行为再评估）

## 6.2 Evidence Ledger

### Evidence Writing Rule

- Contract evidence: 自动化测试覆盖（frontmatter 字段存在 / lint 失败码 / bundle JSON 字段）
- Snapshot evidence: 命令输出 + 时间戳（dogfood 跑现有 findings 库）

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-finding.sh new --topic=lazy-load-smoke --summary="smoke test"` | pending | tbd |
| `bash scripts/specanchor-finding.sh new --topic=lazy-load-smoke` （无 summary）期望失败 | pending | tbd |
| `bash scripts/specanchor-validate.sh` 命中 candidate 缺 summary 期望 fail | pending | tbd |
| `bash scripts/specanchor-assemble.sh --files=scripts/specanchor-assemble.sh --intent=test --bundle-schema=context_bundle.v1 --format=json` | pending | tbd |
| `bash scripts/specanchor-doctor.sh` 期望 warn 不 fail | pending | tbd |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| AC1: finding.sh 必选 `--summary` 且长度 ≤120 | finding.sh smoke + 反例 | pending |
| AC2: validate.sh 在 candidate 缺 summary 时 fail | validate.sh dry-run | pending |
| AC3: assemble 主动扫描并按 affects 命中注入 | assemble JSON layers.finding[] | pending |
| AC4: visibility=hidden finding 不出现在 bundle | assemble 输出对比 | pending |
| AC5: visibility 映射 load 标签正确 | assemble JSON 字段断言 | pending |
| AC6: bundle 含 summary/id/type/impact/affects 元数据 | assemble JSON 字段断言 | pending |
| AC7: agent_instructions 含 lazy-load hint | assemble JSON instructions 段 | pending |
| AC8: 老 finding（无 summary）非 candidate 不 fail validate | validate.sh dogfood | pending |
| AC9: 现有 bundle 消费者（assembly.v1）行为不变 | bundle 默认 schema 输出对比 | pending |
| AC10: cap 默认 50 生效 | 构造 51 个 finding 验证截断 | pending |

### Unverified Risks

- 现有 finding（如有）在 backfill 前的兼容性需要 dogfood
- multi-affects 条目（一个 finding 影响多模块）的去重规则需要在实施时 spike 一次

### Manual / External Checks Needed

- code-reviewer agent / dual-agent-review skill 跑全局静态审查
- 用户 review §0 Open Questions 决策

### Rollback / Follow-up Handle

- 单 PR 改动；rollback 直接 revert commit
- assemble 新增逻辑 gate 在 `--bundle-schema=context_bundle.v1` 下，对 `assembly.v1` 默认输出零影响

## 6.3 Capability Drift Check

- [ ] 本 spec 中描述的「v0.6 现状」是否仍然准确？（执行阶段 re-grep 确认 assemble.sh 状态）
- [ ] 是否有「assemble 不主动扫」/「validate finding 路径未接」等陈述已被后续代码超越？

## 7. Plan-Execution Diff

（待 Execute 阶段填）

## 7.2 Handoff Packet

（auto-generated by `specanchor-assemble.sh --mode=handoff`，不要手写）
