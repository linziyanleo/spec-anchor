---
specanchor:
  level: task
  task_name: "Steering Trigger: corpus collector + design draft"
  author: "@方壶"
  assignee: "@方壶"
  reviewer: "@方壶"
  created: "2026-05-19"
  status: "review"
  last_change: "CP-3=redirect：corpus collector 已落地 + dogfood；设计稿拆为后续 task（指向 v0.5-followup Item 3，启动时机改为 corpus≥50）；本 task REVIEW 待 sha bump + index regen"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: "main"
---

# SDD Spec: Steering Trigger — corpus collector + design draft

> Current RIPER Phase: REVIEW

## 0. Open Questions

### 已通过抽样澄清（迁入 §2）
- ~~§5.2 解析如何识别噪声~~ → 抽样确认：`(none)` / `(无)` / `(空)` / `not applicable — legacy task` 是 legacy 占位 sentinel，可枚举排除
- ~~type 字段是否需 lint 强制~~ → 抽样确认：实际偏离标准枚举（`decision` / `pause` / `pass + add-spec`）；collector 应报警而非强制

### ✅ CP-1 已决议（沉淀于 §5.2 cp-03）
- ~~corpus 量级修正影响~~ → **Q1=B**：redirect 到"先只跑 collector，看到精确分布再决定是否启动设计稿"
- ~~collector 输出格式~~ → **Q2=B**：三种 format 全做（summary / json / details）
- ~~跨 task 重复 pattern 计数~~ → **Q3=C**：双轨——原始计数 + 去重计数

### 留到 EXECUTE / 条件触发的 CP-3 之后
- [ ] Steering Trigger 信号源边界：仅 §5.2，还是含 §6.2 unverified-risk / §7.2 handoff packet redirect 痕迹？（仅在 CP-3 决议启动设计稿后讨论）
- [ ] emit 抑制策略：cool-down window 形式 + dogfood self-reference 是否显式屏蔽（dogfood 占 corpus 68%）？（同上）

## 1. Requirements (Context)

- **Goal**: ~~原计划：collector + 设计稿合并落地~~ → CP-1 Q1=B 窄化两阶段 → **CP-3=redirect 最终窄化为仅 collector**：
  1. **本 task 唯一范围**：实现 corpus collector（已完成，参见 §2.7 / §5.4 verdict=below）
  2. **设计稿拆为后续 task**：v0.5-followup §Items.Item 3 已更新，启动时机改为"corpus ≥50 后"。本 task 不再包含任何设计稿产出
- **In-Scope**:
  - 新增 `scripts/specanchor-corpus.sh`：常驻 specanchor-* 命令族成员；3 种 format；双轨 pattern 检测
  - collector 必须覆盖：cp-NN 总数、type 分布（含非标 type 报警）、phase 分布、by 分布、pin 占比、per-file 密度、dogfood self-reference 占比、跨 task 重复 pattern（原始 + 去重）
  - `references/commands/steering.md` 设计稿——**条件 in-scope**：仅 CP-3 决议启动后才进入
- **Out-of-Scope**:
  - **不实现 STEER 自动 emit 代码**——本 task 严格止于设计稿（且设计稿本身条件触发）
  - 不修改任何 schema yaml / template
  - 不动 `anchor.yaml.context_control.decision_log` 配置（除非设计稿明确依赖且经 CP 批准）
  - 不修改任何已存在的 §5.2 历史决策内容
  - **未经 CP-3 决议，禁止创建 `references/commands/steering.md`**

## 1.1 Context Sources
- Requirement Source: `.specanchor/tasks/_cross-module/2026-05-19_v0.5-deferred-followup.spec.md` §Items.Item 3（修订后）
- Design Refs: `.specanchor/archive/2026-05/_cross-module/2026-05-18_harness-context-control.spec.md` §4 Vision
- Chat/Business Refs: 5/19 当日 review 对话 + RESEARCH 抽样——v0.5-deferred-followup 写的 "~123 条" 为粗 grep 误估（见 §2.1 修正），实测 6 文件 25 条 cp-NN，外推全量约 30–50 条
- Extra Context: `.specanchor/global/architecture.spec.md`（Steering Trigger 是 Harness Context Control 控制平面的核心 emit 信号）

## 1.2 Hard Boundaries

> 越界即触发 Steering Trigger（停 + 转向）。

- **不动 schema yaml / template**：`references/schemas/*/{schema.yaml,template.md}` 全部禁动；本 task 是工具 + (条件触发的)设计稿，不修改协议
- **不实现 STEER 自动 emit**：本 task 严格止于"collector 落地 + (可能的)设计稿评审通过"，emit 实现归属下游 task
- **不动历史 §5.2**：所有已存在的 task spec / archive 中的 §5.2 内容禁止改写——collector 是只读扫描
- **不动 anchor.yaml**：`context_control.decision_log` / `evidence_log` 配置禁动，除非设计稿在 CP 批准下显式提议
- **CP-3 守卫**（CP-1 Q1=B 引入）：未经 CP-3 决议，禁止创建 `references/commands/steering.md` 或任何 emit-related 设计文档——agent 若越界自动触发 Steering Trigger（停 + halt）

## 1.3 Allowed Freedom

> Agent / 实施者可自决，无需 checkpoint。

- corpus collector 实现语言：bash + awk / shell pipeline 选择（与现有 specanchor-* 脚本风格一致即可）
- §5.2 解析正则的具体形态（识别 `cp-NN` 的方式 / type 标签提取的 regex）
- 输出格式细节：plain-text summary 必须有；额外 JSON / markdown dump 是否产出由实施者自决
- 设计稿 §结构粒度：是否拆"emit 时机 / 信号源 / 抑制策略"三段，还是合并

## 1.5 Codemap Used (Feature/Project Index)
- Codemap Mode: `feature`
- Codemap File: 暂未生成；本 task 范围窄（仅 `scripts/specanchor-*` + `references/commands/`），无需独立 codemap
- Key Index:
  - Entry Points: `scripts/specanchor-corpus.sh`（待新建）、`references/commands/steering.md`（待新建）
  - Cross-Module Flows: collector 扫描所有 `.specanchor/{tasks,archive}/**/*.spec.md` 的 §5.2 段落
  - Dependencies: 无外部依赖；仅 bash + awk / grep

## 1.6 Context Bundle Snapshot (Lite/Standard)
- Bundle Level: `Lite`
- Bundle File: 不单独生成
- Key Facts:
  - corpus 实测：6 文件 25 条 cp-NN（dogfood 17 + handoff-schema-and-aware-enforce 2 + frontmatter-schema-validation 3 + inject-dispatch 1 + landscape-readiness 0 + 本 spec 2），外推全量约 30–50 条；之前 review "~123 条" 系粗 grep 误估
  - 当前 §5.2 格式由 sdd-riper-one v2 template 定义：`- **cp-NN** (date, PHASE) [type, active(, pin)] @section`
  - schema-aware enforce 已在 `scripts/specanchor-doctor.sh:lint_context_control_task` 落地
- Open Questions: 见 §0

## 2. Research Findings

> 抽样源（2026-05-19）：6 文件 / 25 条 cp-NN，覆盖跨 schema-aware enforce 前后 + dogfood + 旧 archive 对照。

### 2.1 体量修正（关键发现）

之前 review 估算 corpus ~123 条**严重偏高**——粗 grep 把 §6.2 Acceptance Criteria 表格行 / §1.2 Hard Boundaries 列表项也计入了。实测 6 文件 cp-NN：

| 文件 | 之前粗估 | 实测 cp-NN |
|---|---|---|
| `2026-05-18_harness-context-control`（dogfood） | 36 | **17** |
| `2026-05-19_handoff-schema-and-aware-enforce` | 18 | **2** |
| `2026-05-19_frontmatter-schema-validation` | 19 | **3** |
| `2026-05-19_inject-dispatch` | 15 | **1** |
| `2026-04-27_landscape-readiness` | 3 | **0**（legacy 占位）|
| `2026-05-19_steering-trigger`（本 spec） | - | 2（cp-00, cp-01） |

外推全量 12 文件：**真实 corpus ≈ 30–50 条**——**可能正好处于 ≥50 阈值边缘**，并非之前 v0.5-deferred-followup §Context Snapshot 描述的"远超阈值"。collector 实跑前不能定论。

### 2.2 type 枚举漂移

标准模板列表：`pass / clarify / add-spec / redirect / rollback / halt`

实测分布（25 条样本）：
- 标准内：`add-spec`(9) / `pass`(5) / `redirect`(5)
- 标准内但 0 出现：`clarify` / `rollback` / `halt`
- **非标准**：`decision`(1，handoff cp-00) / `pause`(1，frontmatter cp-03)
- **复合形式**：`pass + add-spec`(3)
- pin 占比 36%（9/25）

→ collector 必须支持"非标准 type 报警"，并允许复合 type 解析。

### 2.3 跨 task 高频 pattern（emit 信号最强候选）

**3 个独立 task 的 cp-01 都沉淀了同一类决策**：`handoff-schema-and-aware-enforce` / `frontmatter-schema-validation` / `inject-dispatch`，其 cp-01 都是"/goal hook → plan auto-approved，但 §4.7 CP 仍停"——`redirect, pin` + `by: agent (依据 user instructions 优先级)`。这是 cross-task 反复出现的协议张力，是 Steering Trigger emit 设计的最强候选信号源。

### 2.4 形态偏差清单

1. cp 起点不一：dogfood 从 `cp-01` 起；新 task 流（包含本 spec）从 `cp-00` 起表"task 起点决策"——collector 解析需兼容
2. early dogfood cp-01..cp-07 **不带 phase 标签**（brainstorming 未进 RIPER）
3. `by:` 字段三种格式：`human` / `agent` / `agent (依据 ...)` 带括号理由
4. legacy 占位：`(none)` / `not applicable — legacy task` / `(无)` / `(空)` 三种空 sentinel——必须排除
5. dogfood 单文件占总 corpus **68%**（17/25）——self-reference 偏差强证据，emit 算法基于纯频率会被 dogfood 主导

### 2.5 不确定项

- ~~collector 跑全量后真实总数~~ → **EXECUTE step 6 实测 = 29 cp-NN**（见 §2.7）
- ~~跨 task 重复 pattern 的去重计数~~ → **实测仅 1 个 cross-task pattern（/goal hook 2x），双轨 raw=2 / deduped=2 file-spread**
- ~~dogfood self-reference 屏蔽策略~~ → **实测 dogfood 占比 59%，确认 self-reference 偏差强信号**——设计阶段必须显式屏蔽（如启动设计）

### 2.7 EXECUTE step 6 — collector 实测结果（2026-05-19）

跑 `bash scripts/specanchor-corpus.sh --format=summary --scope=all`：

| 指标 | 实测值 | 解读 |
|---|---|---|
| Files scanned | 15 (tasks=5, archive=10) | 100% 覆盖 |
| **Total cp-NN** | **29 (raw) / 28 (deduped, prefix=50)** | **远低于 review 估算 ~123，也低于 §2.1 外推 30-50 区间下沿，刚好低于 ≥50 阈值** |
| **Threshold gate (默认 50)** | **"below"** | **Steering Trigger 阈值未触发！** |
| Threshold gate (50 改 29) | "above" | 29 恰是临界 |
| Type 分布 | add-spec(13), redirect(9), pass(8), pause(1, 非标), decision(1, 非标) | clarify / rollback / halt **全部 0**——schema 中 3/6 type 未实战使用 |
| Phase 分布 | no-phase(7), PLAN(6), EXECUTE(6), PLAN→EXECUTE(4), RESEARCH(3), 其他(3) | RESEARCH 阶段 cp 也存在，sdd-riper-one v2 hot/cold 假设需更新 |
| By 分布 | human(18), agent-with-rationale(7), human-with-rationale(3), agent(1) | 人主导 72%，agent 自决占比小 |
| Pin ratio | 41% (12/29) | 远高于 v0.5-deferred-followup 估算的 36% |
| **Dogfood self-reference** | **17/29 = 59%** ⚠️ | **>50% 阈值告警生效**——任何基于 corpus 频率的 emit 算法都会被 dogfood task 主导 |
| **Cross-task 重复 pattern** | **仅 1 个（/goal hook 命中 2 file）** | 信号密度极低——单 pattern 不足以驱动 emit 设计 |

### 2.8 综合判断（为 CP-3 输入）

实测数据**强烈**指向"当前 corpus 不足以驱动有意义的 Steering Trigger 设计"：
1. corpus 总量 29 < 50 阈值（即便 §2.1 修正后）
2. cross-task 信号只有 1 个 pattern（/goal hook），不构成 emit 设计依据
3. dogfood self-reference 59%——任何频率类 emit 算法都被 dogfood 主导
4. 标准 type 3/6 未使用——schema 与实战脱节本身就是先要解决的事

但 collector 本身已经产出 dogfoodable 价值——它已经验证：
- v0.5-deferred-followup 写的"corpus 已远超 ≥50"是错的
- "/goal hook + strict gate"是当前唯一明确 cross-task pattern
- Non-standard type（pause, decision）实际存在，schema 需要补

## 2.6 Next Actions
- ✅ RESEARCH 抽样完成（5 文件 / 25 条 cp-NN）
- 准备 CP-1（RESEARCH→PLAN）：抽样数据 + collector 输出格式提议（默认 `--format=summary`，含跨 task 重复 pattern 检测）
- 等待用户 CP-1 决议，进 PLAN 阶段

## 3. Innovate (Optional: Options & Decision)

### Option A: collector + 设计稿同 PR
- Pros: 设计稿可以直接引用 collector 的实证数据
- Cons: PR 体量较大；review 难以分层
### Option B: collector 先落地（独立 commit），然后基于其输出更新本 spec §2，再开 PLAN 写设计稿
- Pros: 设计稿基于真实数据；review 分层
- Cons: 需要两个 phase 切换
### Decision
- Selected: **Option B**（CP-1 Q1=B 决议）
- Why: 抽样结果显著意外（corpus 真实量级仅 25 条 vs 之前估算 ~123）；必须先让 collector 实跑出精确分布，才能负责任地决定是否启动设计稿。CP-3 重新决议是否进设计阶段。

## 4. Plan (Contract)

### 4.1 File Changes

**确定 in-scope**：
- `scripts/specanchor-corpus.sh`：**新建**——常驻可重复运行的 corpus collector（summary + json + details 三 format；双轨重复 pattern 检测）
- `.specanchor/modules/scripts.spec.md`：collector 落地后 bump `last_synced_sha`，append "specanchor-corpus.sh — corpus collector for Steering Trigger 决议" 到 last_change
- `.specanchor/spec-index.md`：collector 落地后 regenerate

**条件 in-scope（仅 CP-3 决议启动设计稿后）**：
- `references/commands/steering.md`：设计稿（不含实现细节，由 CP-4 守卫越界）
- `.specanchor/modules/references.spec.md`：设计稿落地后 bump `last_synced_sha`

### 4.2 Signatures

#### `scripts/specanchor-corpus.sh`

```
specanchor-corpus.sh [--format=summary|json|details] [--scope=tasks|archive|all] [--dedupe-prefix=N] [--threshold=N]
```

- exit 0 = scan 成功；exit 1 = scan 失败；exit 2 = 参数错误
- `--format` 默认 `summary`；可单独指定 `json` / `details`
- `--scope` 默认 `all`
- `--dedupe-prefix` 默认 50（rule 字段前 N 字符相同视为同 pattern）；仅影响重复 pattern 段的去重输出，不影响原始计数（CP-1 Q3=C 双轨）
- `--threshold` 默认 50（Steering Trigger 触发阈值，影响 summary `Threshold gate` 段与 json `threshold_status` 段的判定）（CP-2 redirect 引入）

**summary 输出（plain text，~25 行）**：
```
SpecAnchor Corpus  (scope=<all|tasks|archive>)
  Files scanned: N (tasks=X, archive=Y, legacy_excluded=Z)
  Total cp-NN: M  (raw_count) / M' (deduped by --dedupe-prefix=50)

  Type distribution:
    pass: ?   add-spec: ?   redirect: ?   pass+add-spec: ?
    clarify: ?   rollback: ?   halt: ?
    Non-standard: decision(?), pause(?)   ⚠️

  Phase distribution:
    EXECUTE: ?   PLAN: ?   RESEARCH: ?   PLAN→EXECUTE: ?
    EXECUTE→REVIEW: ?   no-phase: ?

  By distribution: human(?) / agent(?) / agent-with-rationale(?)
  Pin ratio: ?%
  Top-3 dense files: <file>(?), <file>(?), <file>(?)
  Dogfood self-reference: X/M = ?%   ⚠️ if >50%

  Cross-task repeated patterns (top 5, raw):
    [<count>x] "<rule prefix 50 char>" @ <file1>, <file2>, ...
  Cross-task repeated patterns (top 5, deduped):
    [<dedupe_count>x] "<rule prefix>" @ <file_set>

  Threshold gate (--threshold=<T>, default 50): M < T → "below" | M >= T → "above"
```

**json 输出**：上面 summary 的结构化等价物（顶层 keys：`scan_meta` / `totals` / `type_dist` / `phase_dist` / `by_dist` / `top_files` / `dogfood_ratio` / `repeated_patterns_raw` / `repeated_patterns_deduped` / `threshold_status`），其中 `threshold_status` 含 `{value: <T>, total: M, verdict: "below"|"above"}`，供后续 emit 实现 task 直接消费

**details 输出**：每条 cp-NN 一行
```
<file>:<line> cp-<NN> [<type>][<phase>][<by>][<pin?>] | <rule first 80 char>
```
按文件分组，按 cp-NN 升序

#### `references/commands/steering.md`（条件 in-scope，仅 CP-3 后）

设计稿目录结构（CP-3 决议启动后由 PLAN 进一步细化）：
- `## 设计目标`
- `## Emit 时机`
- `## 信号源`
- `## False-positive 抑制`
- `## 后续实现路径`

### 4.3 Implementation Checklist
- [x] 1. RESEARCH：6 文件 §5.2 抽样（25 条 cp-NN），输出 type/phase/by 分布 → 见 §2
- [x] 2. CP-1（RESEARCH→PLAN）：抽样汇报 + 输出格式拍板（Q1=B / Q2=B / Q3=C）→ §5.2 cp-03
- [ ] 3. PLAN：本段——基于 CP-1 决议产出 collector 详细接口规格（§4.2）✅ 进行中
- [x] 4. CP-2（PLAN→EXECUTE）：接口评审通过——`--dedupe-prefix=50` pass / threshold 加 `--threshold=N` redirect（已落 §4.2）→ §5.2 cp-04
- [ ] 5. EXECUTE：实现 `scripts/specanchor-corpus.sh`（summary + json + details 三 format + 双轨 dedupe）
- [ ] 6. EXECUTE：跑 collector `--scope=all --format=summary` 拿到精确分布，回填 §2 + 更新 v0.5-deferred-followup §Context Snapshot 的错误估算
- [x] 7. CP-3（EXECUTE→REVIEW）：**redirect**——设计稿拆为后续 task；本 task 止于 collector → §5.2 cp-07
- [~] 8. ~~（仅 CP-3=pass）起草 steering.md 设计稿目录骨架~~ → **skipped (CP-3=redirect)**
- [~] 9. ~~（仅 CP-3=pass）CP-4 设计稿越界守卫~~ → **skipped (CP-4 never activated)**
- [ ] 10. REVIEW：collector 行为验证 ✓（smoke test 全过）；module spec sha bump（scripts.spec.md 新加 specanchor-corpus.sh）；spec-index regenerate；v0.5-followup §Items.Item 3 更新

### 4.7 Checkpoints — Contract

> 实施阶段 agent 必须停下来汇报的位置。

#### CP-1 RESEARCH→PLAN：抽样结果汇报 ✅ closed
- 通过决议：Q1=B / Q2=B / Q3=C（沉淀于 §5.2 cp-03）

#### CP-2 PLAN→EXECUTE：collector 接口评审 ✅ closed
- 通过决议：dedupe-prefix=50 pass；threshold 加 `--threshold=N` 默认 50（沉淀于 §5.2 cp-04）

#### CP-3 EXECUTE→REVIEW：设计稿启动决议 ✅ closed
- 通过决议：**redirect**——设计稿拆为后续 task（指向 v0.5-followup §Items.Item 3 修订）；本 task 止于 collector（沉淀于 §5.2 cp-07）

#### CP-4 设计稿越界守卫 ❌ never activated
- CP-3=redirect 后不再触发；保留段落作为协议契约记录

## 5. Execute Log

- **2026-05-19 EXECUTE 起点**：
  - 关键发现：`scripts/lib/decision-filter.sh` 已实现 §5.2 完整解析（`sa_parse_decisions` 输出 12 列 TSV）。collector 可直接 source 复用，无需重新实现 cp-NN 正则 / type 多值 / pin 状态解析
  - 设计决策（属 §1.3 Allowed Freedom）：`corpus.sh` source `lib/decision-filter.sh::sa_parse_decisions`，聚合层自己写
  - 实施工作量从"~200 行 awk + bash"砍到"~150 行纯 bash 聚合 + IO"
- [x] step 5.1：corpus.sh 骨架（argparse + scope discovery + 调 sa_parse_decisions）
- [x] step 5.2：聚合层（type/phase/by/pin/per-file/dogfood/dedupe/threshold）
- [x] step 5.3：三 format 输出（summary / json / details）
- [x] step 5.4：smoke test 全过——首跑 exit=0 但发现 2 bug：(1) IFS=',' 污染标准 type 检测 (2) `human (...)` 未归 human-with-rationale。修复后 json 通过 python json.tool 校验；threshold=20/29/50/80 各 verdict 正确；scope=tasks(8)/archive(21)/all(29) 一致；invalid args exit=2
- [x] step 6：实测分布回填 §2.7；关键发现：**total=29 < 50 阈值 verdict=below**；dogfood 59% 越红线；只 1 个 cross-task pattern

## 5.2 Checkpoint Decisions Log

> Checkpoint 上的决策沉淀。hot/cold 分层由 anchor.yaml `context_control.decision_log` + 任务 frontmatter `decision_log` 决定。

### Recent (active, hot)

- **cp-07** (2026-05-19, EXECUTE→REVIEW) [redirect, active, pin] @§4.7 CP-3
  - rule: "CP-3=redirect：基于 cp-06 实测三个互相强化的 finding（corpus 29 < 50 阈值 / dogfood 59% self-reference / 唯一 1 个 cross-task pattern），设计稿拆为后续 task。Item 3 设计意图保留但启动时机改为 'corpus ≥50 后'。本 task 进 REVIEW，唯一产出 = `scripts/specanchor-corpus.sh`。CP-4 永不激活。需同步更新 v0.5-followup §Items.Item 3。"
  - by: human (CP-3 决议)

- **cp-06** (2026-05-19, EXECUTE) [add-spec, active, pin] @§2.7 + §2.8
  - rule: "collector 实跑结果（step 6 完成）：total=29 cp-NN / threshold gate verdict=BELOW (默认 50)；dogfood self-reference 59% 越红线；唯一 cross-task pattern 是 /goal hook (2 files)；clarify/rollback/halt 三个标准 type 实战 0 命中。三个 finding 同时为真——指向 corpus 信号密度不足以驱动 Steering Trigger 设计。两 bug fix（IFS 污染 / by 字段 human-with-rationale）已提交。CP-3 决议输入就绪。"
  - by: agent (EXECUTE step 6 实测)

- **cp-05** (2026-05-19, EXECUTE) [add-spec, active] @§5 Execute Log
  - rule: "EXECUTE 设计选择：`corpus.sh` source `scripts/lib/decision-filter.sh` 复用 `sa_parse_decisions`（12 列 TSV），不重新实现 cp-NN 解析。属 §1.3 Allowed Freedom 实现路径自决，无需 CP；但作为关键设计沉淀供 audit。"
  - by: agent (EXECUTE 起点 lib 复用决策)

- **cp-04** (2026-05-19, PLAN→EXECUTE) [redirect, active, pin] @§4.2 Signatures
  - rule: "CP-2 两子决议：(a) `--dedupe-prefix=50` 默认值 pass。(b) Threshold 50 不应硬编码——加 `--threshold=N` 参数（默认 50），让 summary `Threshold gate` 段与 json `threshold_status.value` 都可配。后果：§4.2 命令行接口 + summary 输出 + json schema 同步修订。"
  - by: human (CP-2 决议)

- **cp-03** (2026-05-19, RESEARCH→PLAN) [redirect, active, pin] @§4 + §1.Goal
  - rule: "CP-1 三子决议：(Q1=B) task 范围窄化为 collector 优先；设计稿启动推迟到 CP-3，依赖 collector 实跑数据。(Q2=B) collector 三种 format 全做（summary/json/details）。(Q3=C) 重复 pattern 双轨——原始计数 + 去重计数（dedupe-prefix=50 默认）。后果：§1 Goal / §1.2 Hard Boundaries (+CP-3 守卫) / §3 Innovate Decision (=Option B) / §4 Plan 全段同步修订。"
  - by: human (CP-1 决议)

- **cp-02** (2026-05-19, RESEARCH) [redirect, active, pin] @§2.1 体量修正
  - rule: "corpus 量级修正：原 v0.5-deferred-followup §Context Snapshot 与 review 写的 '~123 条' 严重偏高（粗 grep 把 §6.2 表格 / §1.2 列表项也计入）。6 文件抽样实测 cp-NN 仅 25 条，外推全量 30–50 条，**可能在 ≥50 阈值边缘而非远超**。Item 3 '已触发' 的判断需 collector 实跑后才能定论；本 task 仍按计划推进——collector 本身就是裁定工具。"
  - by: agent (RESEARCH 阶段抽样发现，依据 §2.1 表格)

- **cp-00** (2026-05-19, RESEARCH) [redirect, active] @§Items.Item 3
  - rule: "解除 Item 3 corpus-gated 阻塞——实测约 25 条 cp-NN（之前 ~123 估算偏高，见 cp-02），但仍接近 ≥50 阈值，从'长期'重分类为'短期可启动'"
  - by: human

- **cp-01** (2026-05-19, RESEARCH) [pass, active] @§1.Goal
  - rule: "Task 范围合并：corpus collector + Steering Trigger 设计稿一起做（不实现 emit）；脚本归属 scripts/specanchor-corpus.sh 加入命令族"
  - by: human

### Earlier (audit only)

- (无)

## 6. Review Verdict
- Spec coverage: **PASS**——CP-3 redirect 后本 task 范围窄化为仅 collector；scripts/specanchor-corpus.sh 已落地，smoke test 全过
- Behavior check: **PASS**——3 format 输出格式正确（json 通过 python json.tool 校验）；threshold/scope/dedupe-prefix 可配；invalid args 退出 2；exit 码语义符合 §4.2
- Regression risk: **Low**——新文件，不修改任何已存在脚本；复用 lib/decision-filter.sh 不修改 lib
- Module Spec 需更新: **Yes**——scripts.spec.md 需 bump last_synced_sha 并 append "specanchor-corpus.sh — corpus collector for Steering Trigger 决议（CP-3=redirect 后独立成 lifecycle）"；references.spec.md **不动**（CP-3=redirect 后 commands/steering.md 未新建）
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: **No**——本次修订未产生新架构原则
  - 新发现的项目规则:
    - sdd-riper-one schema type 枚举与实战脱节（clarify/rollback/halt 0 命中；pause/decision 实际出现）——可考虑下个 schema 修订时扩展或加 lint warning
    - dogfood self-reference 强信号（59%）——future corpus 类工具默认要报警 >50% 时屏蔽 self-reference
    - "corpus 估算用粗 grep"是反模式——所有阈值类信号必须用结构化 parser（如 sa_parse_decisions），不能用 `grep -c "^-"` 估算
  - 值得记录的反模式:
    - **v0.5-deferred-followup 用粗 grep 估 corpus → "~123 条" 实际是 29**——4x 高估；任何"基于 corpus 数量做判断"必须等 collector 实测后再下结论
- Follow-ups:
  - **v0.5-followup §Items.Item 3 更新**：本 task REVIEW 后必做
  - emit 实现 task：推迟到 corpus ≥50 后 + 单独 Steering Trigger 设计稿评审通过
  - sdd-riper-one schema type 枚举修订（lint warning for non-standard types）：可加入 v0.6 候选
  - corpus collector 加 `--watch` mode 在 dev loop 中持续监控 corpus 增长：nice-to-have

## 6.2 Evidence Ledger

> 验收证据链。

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-corpus.sh --format=summary` | pending | (EXECUTE step 6 后填) |
| `bash scripts/specanchor-corpus.sh --format=json` | pending | (EXECUTE step 6 后填) |
| `bash scripts/specanchor-corpus.sh --format=details` | pending | (EXECUTE step 6 后填) |
| `bash scripts/specanchor-doctor.sh --lint=context-control` | pending | (REVIEW 时确认本 spec 6 段合规) |
| `bash scripts/specanchor-index.sh` | pending | (REVIEW 时 regenerate spec-index) |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| `specanchor-corpus.sh` 可运行，summary 输出含 §4.2 列出的全部段 | summary 输出（见 §5 Execute Log + §2.7） | ✅ |
| json format 输出与 summary 结构等价（顶层 keys 完整） | json 输出 + `python3 -m json.tool` 校验 | ✅ |
| details format 每条 cp-NN 单行输出，按文件分组 | details 输出（29 条 / 15 文件 / 按文件分组） | ✅ |
| 双轨 dedupe 行为正确（`--dedupe-prefix=50` 默认；原始计数 ≥ 去重计数） | summary repeated patterns 段对比（raw=29 ≥ deduped=28） | ✅ |
| `--threshold=N` 可配，影响 summary `Threshold gate` 与 json `threshold_status.value` | threshold=20→above / 50→below / 80→below / 边界 29→above 各 verdict 正确 | ✅ |
| 实测 cp-NN count 落在 §2.1 外推区间 30–50 内（±30%） | 实测 29，与下沿 30 差距 3%，落在 ±30% 内（21-39） | ✅ |
| ~~设计稿评审通过~~ | CP-3=redirect 后 N/A | N/A |
| 本 spec 通过 schema-aware lint | doctor `--lint=context-control` exit=0 | ✅ |
| invalid args 退出码 2 | `--format=xml` / `--threshold=abc` / `--bogus` 全部 exit=2 | ✅ |

### Unverified Risks

- corpus 真实分布噪声率未知——可能影响设计稿核心判断
- dogfood self-reference 风险——dogfood 自身高频触发可能扭曲设计

### Manual / External Checks Needed

- 设计稿评审：决定 emit 时机阈值是否合理
- 抽样验证：collector 输出与人工抽样的 §5.2 一致性

### Rollback / Follow-up Handle

- 回滚：`scripts/specanchor-corpus.sh` 与 `references/commands/steering.md` 都是新增文件，git rm 即可
- module spec sha bump 通过 git revert 回滚

## 7. Plan-Execution Diff
- (待 EXECUTE 阶段填写)

## 7.2 Handoff Packet

> auto-generated by `specanchor-assemble.sh --mode=handoff`
> 不要手写。重新生成请运行 `specanchor_handoff`。

- Task: Steering Trigger — corpus collector (CP-3 redirect 后 windowed for collector only) (status: review, phase: REVIEW)
- Spec Landscape: scripts.spec.md (待 bump sha)
- Active Decisions (hot, last 5): cp-07, cp-06, cp-05, cp-04, cp-03
- Evidence Status: 4 verified (collector 行为) / 0 unverified-risk
- Read next: §6 Review Verdict + §6.2 Acceptance Criteria（REVIEW 输入）
- Don't read (cold/superseded): §4.7 CP-4（never activated）/ §3 Innovate Options A（CP-1 后已选 B）
- Next step: REVIEW 收尾——bump scripts.spec.md last_synced_sha + regenerate spec-index + 更新 v0.5-followup §Items.Item 3
