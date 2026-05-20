---
specanchor:
  level: task
  task_name: "Init 交互式三问改造"
  author: "@maintainer"
  created: "2026-05-20"
  status: "in_progress"
  last_change: "Steps 1-6 完成：各平台 Boot Activation 模板 + init.md Q1/Q2 插入 + Q3 微调 + --scan-sources 边界闭合 + refs.spec 同步 + 验证全绿"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "sdd-riper-one"
  branch: "feat/init-interactive-prompts"
---

# SDD Spec: Init 交互式三问改造

> Current RIPER Phase: EXECUTE

## 0. Open Questions
- [x] Hook 模板是内嵌 init.md 还是拆到 `references/hooks/` 独立目录？→ 先放在 `references/agents/{claude-code,codex,cursor,gemini}.md`；`init.md` 只路由和引用。除非模板膨胀到难维护，否则不新增 `references/hooks/`。
- [x] Module Spec draft 生成是调 specanchor_infer 还是简化版？→ 调 `specanchor_infer`。本 task 只新增候选路径排序 + 用户审批，再按选中路径 dispatch infer。
- [x] 第三问的"迁移"具体是什么操作？→ 不做迁移。改名为 external sources governance adoption：检测已有 spec 目录后问 `full + sources` 还是 `parasitic + sources`；内容转换/复制/删除旧目录留独立 follow-up。

## 1. Requirements (Context)
- **Goal**: 在 `specanchor_init` 流程中加入 3 个 Agent 侧确认点，降低真实 cold start friction：boot 激活不持久、缺少 Module Spec draft 引导、external sources governance 选择不够清晰。当前 init 已能生成 `anchor.yaml`、starter Global Specs、spec-index 和外部 spec 检测；本 task 不再把现状描述为"空壳"，而是把缺口收窄为"检测 → 问 → 配"的初始化引导。
- **In-Scope**:
  - Q1: Boot 激活配置 — 检测当前 Agent 平台 → 问是否配置自动 boot hook / 持久 instructions → 生成对应平台的最小配置片段
  - Q2: 已有模块的 Module Spec draft — 扫描项目顶层目录结构 → 按代码量/变更频率/目录深度推荐 2-3 个核心模块 → 问是否对选中路径运行 `specanchor_infer`
  - Q3: External sources governance adoption — 检测已有 spec 目录（当前 Type Registry + 明确新增的 registry entry）→ 有则问 `full + sources` 还是 `parasitic + sources`；无则默认 full，跳过此问
  - `references/commands/init.md` 执行步骤更新
  - 可能的 `scripts/specanchor-init.sh` 只读检测辅助逻辑（例如输出平台/模块候选/sources 检测结果，不做 shell 交互）
- **Out-of-Scope**:
  - 实际迁移工具（从 OpenSpec/Spec-Kit 内容转换到 SpecAnchor 格式）— 那是独立 task
  - 复制外部 spec 到 `.specanchor/`、删除旧 spec 目录、或把外部目录改造成 native root
  - 默认修改外部 spec 文件；frontmatter 注入仍必须是显式 opt-in
  - 修复 `specanchor-init.sh --scan-sources` 的 Bash 3.2 unbound variable bug — 已拆为独立 fix task
  - Hook 的自动测试框架
  - init.sh 的 TUI/交互式 shell 界面（确认点由 Agent 实现，不是 shell）

## 1.1 Context Sources
- Requirement Source: 本 session 对话讨论
- Design Refs: `references/commands/init.md` 现有步骤
- Chat/Business Refs: 用户提出的初始化体验痛点；Codex argue 后收窄为 boot 持久化 / Module Spec 引导 / sources governance 三个具体缺口
- Extra Context: `references/agents/claude-code.md`, `references/agents/cursor.md`, `references/agents/codex.md`, `references/agents/gemini.md` 各平台入口适配；官方 Claude Code / Codex / Cursor / Gemini 文档核验

## 1.2 Hard Boundaries
- 3 个确认点都是 Agent 侧交互（由 Agent 向用户问答），不是 shell 脚本的交互式 prompt
- 检测无果则跳过（无事不问原则）：无已有 spec 目录 → 跳过 Q3 默认 full；无法识别平台 → Q1 给出通用指引而非自动配置
- Q3 只治理 external sources，不做迁移：不复制、不转换、不删除外部 spec；frontmatter 注入仍需用户明确同意
- 若新增或调用 `specanchor-init.sh` 检测逻辑，必须满足 scripts module 的 Bash 3.2+ 兼容要求；`--scan-sources` 现有 bug 由独立 fix task 先处理
- 不破坏现有 `--mode=full|parasitic` CLI 参数兼容性
- 不在 init 阶段创建 Task Spec（init 只设基础设施）

## 1.3 Allowed Freedom
- 各平台 boot 激活模板的具体内容和落点
- Module Spec 推荐算法（代码量 vs 变更频率 vs 目录深度）
- Q3 sources governance 提问措辞和默认推荐顺序（前提是不引入迁移动作）

## 2. Research Findings

### 2.1 当前 init 流程（init.md 步骤 + init.sh 实现）

Agent 侧流程（init.md）：
1. 检查 anchor.yaml 是否已存在
2. 扫描已有 spec 体系（Type Registry）
3. 有则问 parasitic / full；无则默认 full
4-6. 脚本处理：目录结构、anchor.yaml、spec-index
7-12. Agent 处理：scan.sh、git hook、Global Spec、frontmatter

Shell 侧（init.sh 318 行）：
- `--mode=full|parasitic` 参数
- `generate_anchor_yaml()` → anchor.yaml
- `create_directories()` → .specanchor/{global,modules,tasks,archive}
- `generate_spec_index()` → spec-index.md
- `generate_codemap()` → project-codemap.md
- `generate_global_specs()` → 3 个 Global Spec 模板
- `--scan-sources` 当前在系统 Bash 3.2 下会因 `local -A` + `set -u` 触发 `openspec: unbound variable`；该 bug 阻塞继续扩展 init 检测脚本，已拆独立 fix task

### 2.2 各平台 boot 激活机制（Codex argue 后更新）

| 平台 | 当前机制判断 | Boot 激活形式 |
|------|-----------|---------------|
| Claude Code | 支持 hooks，`SessionStart` 适合加载开发上下文；静态上下文仍可用 `CLAUDE.md` / skill prompt | 推荐生成 `SessionStart` hook；无法安全写 hook 时输出 CLAUDE/skill prompt 片段 |
| Codex | 支持 first-class hooks（含 `SessionStart` / `PreToolUse` / `PostToolUse` / `UserPromptSubmit` / `Stop`）并支持 `AGENTS.md` 指令链 | 推荐 `SessionStart` hook 或 `AGENTS.md` 启动段；不要再把 Codex 简化成 `agents.md/codex.md` 文本 |
| Cursor | Project Rules 存放于 `.cursor/rules/*.mdc`；也支持 `AGENTS.md` 作为简单指令文件；不是同一类 shell hook 边界 | 生成 `.cursor/rules/specanchor.mdc` 或 `AGENTS.md` 片段，要求每次任务先 boot/assemble |
| Gemini | `GEMINI.md` 层级 context；可通过 settings 调整 context file name；`/memory reload` 刷新 | 生成项目 `GEMINI.md` 片段，要求任务前运行 boot/assemble |

### 2.3 Q2 Module Spec 推荐策略

结论：draft 生成必须复用 `specanchor_infer`；本 task 只负责选候选路径和用户审批，不新增平行的简化版 Module Spec 生成器。

候选路径排序算法可选：
- **代码量排序**: `find <dir> -name "*.ts" -o -name "*.py" | wc -l` 取 top 3
- **变更频率**: `git log --oneline --since=3.months -- <dir> | wc -l` 取 top 3
- **混合排序**: 代码量 × 0.4 + 变更频率 × 0.6 取 top 3
- **约束**: 排序只产生候选；用户确认后才对选中路径 dispatch `specanchor_infer`

### 2.4 Q3 External Sources Governance Adoption

init.md 已有 Type Registry（步骤 2）：
```
openspec/     → type: "openspec"
specs/        → type: "spec-kit"
mydocs/specs/ → type: "mydocs"
.qoder/specs/ → type: "qoder"
docs/specs/   → type: "generic"
```

本 task 的 Q3 不再询问"迁移"。检测到已有 spec 体系时，问题改为：
- `full + sources`: 创建 `.specanchor/` native specs，同时把外部 spec 目录写入 `anchor.yaml.sources`
- `parasitic + sources`: 不创建 native spec 体系，仅用 `anchor.yaml.sources` 治理已有 spec 目录
- 对每个 source 单独确认 `stale_check` / `scan_on_init` / `frontmatter_inject`，其中 `frontmatter_inject` 默认 false，且必须明确说明会修改外部文件

内容转换、复制到 `.specanchor/`、旧目录删除都不是 adoption 行为，留给独立 migration follow-up。

## 2.1 Research Conclusion

Research 完成。三问设计、平台机制、infer 复用、sources governance 边界均已确认。§0 Open Questions 全部关闭。进入 PLAN。

## 2.5 额外发现（Research 期间）

- `codex.md` install path 写的是 `.cursor/skills/specanchor/`，疑似 copy-paste 错误。不在本 task scope，记 follow-up
- init.sh `scan_external_sources()` 使用 `local -A`（Bash 4+ associative array），是 `--scan-sources` Bash 3.2 bug 的根源。本 task 不依赖 `--scan-sources`（Q3 的 sources 检测由 Agent 侧执行，不扩展 init.sh 检测脚本），因此不被阻塞

## 4. Plan (Contract)

### 4.0 Design — 三问交互流程

#### Q1: Boot 激活配置（插入位置：init.md 步骤 11 后，即完成信息前）

**检测逻辑**（Agent 侧，不需要脚本辅助）：
- `.claude/` 存在 → Claude Code
- `.cursor/` 存在 → Cursor
- `AGENTS.md` 存在且含 codex 标记，或运行环境为 Codex → Codex
- `GEMINI.md` 存在 → Gemini
- 多个同时存在 → 列出所有检测到的平台
- 都不存在 → 输出通用指引，不自动配置

**交互流程**：
```
检测到当前环境可能使用 <platform>。
是否配置 SpecAnchor boot 激活，使每次 session 自动加载 Spec？(Y/n)

[Y] → 生成对应平台的最小配置片段（见各 agent 适配文件中的 Boot Activation 段）
[n] → 跳过，输出手动配置指引链接
```

**各平台生成内容**：

| 平台 | 生成产物 | 生成位置 |
|------|---------|---------|
| Claude Code | `SessionStart` hook 片段：调用 `specanchor-boot.sh --format=summary` | 输出到终端供用户粘贴到 `.claude/settings.json`；或直接写入（需确认） |
| Codex | `SessionStart` hook 片段 + `AGENTS.md` boot 段 | 输出到终端；或追加到 `AGENTS.md` |
| Cursor | `.cursor/rules/specanchor.mdc` 内容 | 直接创建文件（需确认） |
| Gemini | `GEMINI.md` boot 指令段 | 追加到 `GEMINI.md`（需确认） |

**无法安全检测平台时**：输出通用指引——"请根据你的 Agent 平台，参考 `references/agents/` 下对应文件配置 boot 激活"。

#### Q2: Module Spec Draft（插入位置：init.md 步骤 9 后，即 Global Spec 生成后）

**检测逻辑**（Agent 侧）：
- 读取 `anchor.yaml` 的 `coverage.scan_paths`
- 扫描匹配目录的顶层子目录（一层）
- 排除已有 Module Spec 的目录（查 spec-index.md）
- 按以下维度排序推荐 top 2-3：
  - 代码量：`find <dir> -type f \( -name "*.ts" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) | wc -l`
  - 变更频率：`git log --oneline --since=3.months -- <dir> | wc -l`
  - 推荐排序：代码量 × 0.4 + 变更频率 × 0.6（归一化后加权）

**交互流程**：
```
以下目录可能是核心模块，推荐生成 Module Spec 草稿：
  [1] src/orders/     (120 files, 45 recent commits)
  [2] src/auth/       (35 files, 30 recent commits)
  [3] src/shipping/   (28 files, 22 recent commits)

为哪些目录生成 Module Spec 草稿？(输入编号，逗号分隔；n 跳过)

[1,3] → 对 src/orders/ 和 src/shipping/ 分别运行 specanchor_infer
[n] → 跳过，输出：可随时运行 specanchor_infer 补充
```

**约束**：
- 只排序推荐，不替用户决定
- 每个选中路径 dispatch 标准的 `specanchor_infer` 协议，产出 `status: draft`
- 如无可推荐目录（项目太小或 scan_paths 无匹配），跳过此问
- **git history 不可用时的退化**：非 git repo、浅克隆（`git rev-parse --is-shallow-repository`）、或无提交历史时，变更频率维度不可用——显式标注 `(git history unavailable)`，仅按代码量排序；如代码量也无法获取则跳过推荐，不静默给出伪精确分数

#### Q3: External Sources Governance（init.md 步骤 2-3 已覆盖，微调）

**现状**：init.md 步骤 2 扫描 Type Registry，步骤 3 逐个询问治理策略（stale_check / frontmatter_inject / scan_on_init）。流程基本正确。

**需微调的地方**：
- 确保步骤 3 措辞不提及"迁移"，只说"纳入 SpecAnchor 治理"（当前已是）
- 步骤 4 模式选择中明确 `full + sources` 和 `parasitic + sources` 的含义
- `frontmatter_inject` 默认 false 的提示需明确说明"会修改外部文件"
- **命令示例修正**：init.md 首选命令中的 `[--scan-sources]` 在 Bash 3.2 bugfix 完成前不作为推荐路径。改为注释说明 sources 检测由 Agent 侧执行（扫描 Type Registry 目录），不依赖 init.sh 的 `--scan-sources` flag
- **职责拆分修正**：init.md "脚本处理的部分"描述中"外部来源检测"应移到 Agent 处理部分；init.sh 只负责目录创建、anchor.yaml、spec-index

### 4.1 File Changes

| File | Change | Lines (est.) |
|---|---|---|
| `references/commands/init.md` | 步骤 9 后插入 Q2（Module Spec 候选推荐 + infer dispatch 流程）；步骤 11 后插入 Q1（平台检测 + boot 激活配置生成）；步骤 3-4 微调 Q3 措辞；**命令示例去掉 `[--scan-sources]` 推荐路径 + 职责拆分修正（外部来源检测从脚本侧移到 Agent 侧）** | +40~50 |
| `references/agents/claude-code.md` | 新增 `## Boot Activation` 段：SessionStart hook 配置片段 + CLAUDE.md fallback 指令 | +15~20 |
| `references/agents/codex.md` | 新增 `## Boot Activation` 段：SessionStart hook 配置片段 + AGENTS.md boot 段 | +15~20 |
| `references/agents/cursor.md` | 新增 `## Boot Activation` 段：`.cursor/rules/specanchor.mdc` 模板 | +15~20 |
| `references/agents/gemini.md` | 新增 `## Boot Activation` 段：GEMINI.md boot 指令片段 | +10~15 |
| `.specanchor/modules/references.spec.md` | §3.1 各 agent 适配文件更新 summary / 行数；§7 计数可能变；metadata 同步（`last_synced` / `last_synced_sha` / `last_change`）避免半同步状态 | +2~4 |

**不变更的文件**（说明原因）：
- `scripts/specanchor-init.sh`：三问均由 Agent 侧执行，不需要新增 init.sh flag。Q3 检测复用 init.md 步骤 2 的 Agent 侧逻辑，不扩展 `--scan-sources`
- `SKILL.md`：init 相关描述无能力变更（三问是交互流程改进，不是新命令），不需要更新路由表

### 4.3 Implementation Checklist

- [ ] Step 1: 各平台 boot 激活模板 — 写 claude-code.md / codex.md / cursor.md / gemini.md 的 `## Boot Activation` 段
- [ ] Step 2: init.md Q2 插入 — 步骤 9 后新增 Module Spec 候选推荐 + infer dispatch 交互流程
- [ ] Step 3: init.md Q1 插入 — 步骤 11 后新增平台检测 + boot 激活配置生成交互流程
- [ ] Step 4: init.md Q3 微调 + `--scan-sources` 边界闭合 — 步骤 3-4 确保措辞为 governance adoption；命令示例去掉 `[--scan-sources]` 推荐路径（加注释说明 bugfix 前由 Agent 侧检测）；职责拆分描述修正（外部来源检测从"脚本处理"移到"Agent 处理"）
- [ ] Step 5: references.spec.md 全量同步 — agent 适配文件变更后更新 §3.1 summary/行数、§3.4 接口变更（若有）、§7 计数 + metadata 同步（`last_synced` / `last_synced_sha` / `last_change`）
- [ ] Step 6: 验证 — doctor --strict + validate --strict + tests/run.sh + golden fixture 行数检查
- [ ] Step 7: commit

### 4.5 Design Decisions

| Decision | Rationale |
|---|---|
| Q2 在 Q1 前（步骤 9 后 vs 步骤 11 后） | Module Spec draft 是 init 的核心产出之一，应在主流程内完成；boot 激活是"下次自动化"的配置，放在收尾更自然 |
| Q3 不新增步骤，只微调措辞 | init.md 步骤 2-3 已有完整的 sources governance 流程，新增步骤会重复 |
| 不修改 init.sh | 三问均为 Agent 侧交互，不需要 shell 辅助。避免引入新的 Bash 3.2 兼容风险 |
| 各平台模板放在 agent 适配文件而非独立 hooks/ 目录 | 模板短小（10-15 行），放在已有文件中维护成本更低 |
| 推荐算法用代码量 0.4 + 变更频率 0.6 | 变更频率比代码量更能反映模块的活跃度和 spec 需求紧迫度 |

### 4.7 Checkpoints — Contract

#### CP-1 各平台 Boot Activation 模板（Step 1 完成后）
- Output: 4 个 agent 适配文件的 `## Boot Activation` 段 diff
- Awaits: pass / clarify / redirect
- 验收: 每个模板包含可直接粘贴的配置片段 + fallback 指引

#### CP-2 init.md 三问插入完成（Steps 2-4 完成后）
- Output: init.md 新旧步骤对比 + diff
- Awaits: pass / add-spec / redirect
- 验收: Q1/Q2 有检测逻辑 + 交互流程 + 跳过条件；Q3 措辞无"迁移"

#### CP-3 全部验证通过（Steps 5-6 完成后）
- Output: doctor + validate + tests 结果 + golden fixture 状态
- Awaits: pass / redirect

## 5. Execute Log
- [x] Step 1: 各平台 boot 激活模板 — claude-code.md (SessionStart hook + CLAUDE.md fallback) / codex.md (SessionStart hook + AGENTS.md fallback) / cursor.md (.cursor/rules/specanchor.mdc + AGENTS.md fallback) / gemini.md (GEMINI.md boot 段)
- [x] Step 2: init.md Q2 插入 — 步骤 10 新增 Module Spec 候选推荐（混合排序 + git 退化说明 + infer dispatch）
- [x] Step 3: init.md Q1 插入 — 步骤 13 新增平台检测（标志文件矩阵）+ boot 激活配置生成
- [x] Step 4: init.md Q3 微调 + --scan-sources 边界闭合 — 命令示例去掉 [--scan-sources]、职责拆分修正（外部来源检测从脚本侧移到 Agent 侧）、步骤总数 12→14
- [x] Step 5: references.spec.md 全量同步 — §3.4 agents/ 描述加 Boot Activation、§7 agents/ 描述同步、last_change 更新（行数不变，golden fixture 不需要更新）
- [x] Step 6: 验证 — doctor ok + validate ok (38 files) + tests 32/32 + golden fixture estimated_lines 不变 (342)

## 5.2 Checkpoint Decisions Log

### Recent (active, hot)

- **pre-plan-01** (2026-05-20, RESEARCH) [decision, active] @§1
  - rule: "3 个确认点：hook / module spec / spec 兼容。检测无果则跳过（无事不问）。确认点由 Agent 实现不是 shell 交互"
  - by: human

- **pre-plan-02** (2026-05-20, RESEARCH→PLAN) [decision, active] @§0-§2+§4
  - rule: "采纳 Codex argue：goal 收窄为 boot 持久化 / Module Spec 引导 / sources governance；Q1 平台矩阵按官方机制更新；Q2 复用 specanchor_infer；Q3 不再说迁移而是 external sources governance adoption；Bash 3.2 --scan-sources bug 拆独立 fix task；不修改 init.sh（三问均 Agent 侧）"
  - by: human

- **plan-review-01** (2026-05-20, PLAN) [redirect, active] @§4.0+§4.1+§4.3
  - rule: "P1: init.md 命令示例去掉 `[--scan-sources]` 推荐路径 + 职责拆分修正（外部来源检测从脚本侧移到 Agent 侧），否则 Agent 会被引导调用已知 Bash 3.2 bug 入口。P2: refs.spec Step 5 扩展为全量 metadata 同步（last_synced/sha/last_change），避免半同步状态。P3: Q2 排序加 git history unavailable 退化说明（显式标注不可用，仅代码量排序或跳过，不静默伪精确）"
  - by: human

- **plan-approved-01** (2026-05-20, PLAN→EXECUTE) [decision, active] @§4
  - rule: "Plan Approved after P1/P2/P3 fixes"
  - by: human

### Earlier (audit only)

- (none)

## 6. Review Verdict
- Spec coverage: pending
- Behavior check: pending
- Regression risk: Medium（init.md 是用户 Day-1 入口，改动影响首次体验）
- Module Spec 需更新: pending
- Follow-ups:
  - 迁移工具（从 OpenSpec/Spec-Kit 内容转换）作为独立 task
  - `specanchor-init.sh --scan-sources` Bash 3.2 unbound variable bug 作为独立 fix task（`local -A` 不兼容）
  - `codex.md` install path 疑似 copy-paste 错误（写成 `.cursor/skills/specanchor/`），需独立修正
  - Hook 自动测试

## 6.2 Evidence Ledger

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-doctor.sh --strict` | ✅ pass | doctor ok |
| `bash scripts/specanchor-validate.sh --strict` | ✅ pass | validate ok (38 files) |
| `bash tests/run.sh` | ✅ pass | 32 passed, 0 failed |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| init.md 含 3 个交互确认点 | init.md diff | pending |
| init.md 命令示例不含 `[--scan-sources]` 推荐路径 | init.md diff + `grep scan-sources init.md` | pending |
| init.md 职责拆分：外部来源检测在 Agent 处理部分 | init.md diff | pending |
| 各平台 boot 激活模板存在 | agent 适配文件 diff | pending |
| Q2 用户确认后 dispatch `specanchor_infer` | init.md 流程描述 | pending |
| Q2 git history 不可用时显式标注退化 | init.md 流程描述 | pending |
| Q3 检测无果默认 full 跳过；检测到 sources 时只做 governance adoption | init.md 流程描述 | pending |
| references.spec.md metadata 同步（last_synced/sha/last_change + §3.1/§7） | refs.spec diff | pending |
| 现有 CLI 兼容性不破坏 | tests 结果 | pending |

### Unverified Risks

- 各平台 hook 格式可能随 Agent 工具更新而变化
- Module Spec 推荐算法在 monorepo 场景下可能推荐错误模块
- `--scan-sources` 当前 Bash 3.2 bug 如未先修，会阻塞任何依赖该扫描路径的实现

### Manual / External Checks Needed

- 在 Claude Code + Cursor + Codex + Gemini 四个平台实测 init 交互流程

### Rollback / Follow-up Handle

- revert init.md + agent 适配文件即可；Bash 3.2 bug fix 独立回滚

## 6.3 Capability Drift Check

- [ ] 本 spec 中描述的「现状 / 缺口 / 已知约束」是否仍然准确？
- [ ] 是否有「X 不感知 Y」/「需要 Step A/B/C」/「audit finding」类陈述已被后续代码超越？

## 7. Plan-Execution Diff
- Any deviation from plan: pending

## 7.2 Handoff Packet

> auto-generated by `specanchor-assemble.sh --mode=handoff`
> 不要手写。重新生成请运行 `specanchor_handoff`。
