---
specanchor:
  level: task
  task_name: "Init 交互式三问改造"
  author: "@maintainer"
  created: "2026-05-20"
  status: "draft"
  last_change: "初始 draft：3 个交互式确认点设计"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "sdd-riper-one"
  branch: "feat/init-interactive-prompts"
---

# SDD Spec: Init 交互式三问改造

> Current RIPER Phase: RESEARCH

## 0. Open Questions
- [ ] Hook 模板是内嵌 init.md 还是拆到 `references/hooks/` 独立目录？
- [ ] Module Spec draft 生成是调 specanchor_infer 还是简化版？
- [ ] 第三问的"迁移"具体是什么操作？（复制内容到 .specanchor/ → 删旧目录？还是只标注来源？）

## 1. Requirements (Context)
- **Goal**: 在 `specanchor_init` 流程中加入 3 个交互式确认点，降低 cold start friction，让用户在初始化时就配好关键基础设施。当前 init 是 "跑完脚本 → 空壳等用户填" 的模式，改为 "检测 → 问 → 配" 的引导式 init
- **In-Scope**:
  - Q1: Hook 配置 — 检测当前 Agent 平台 → 问是否配置自动 boot hook → 生成对应 hook 配置
  - Q2: 已有模块的 Module Spec — 扫描项目顶层目录结构 → 按代码量/变更频率推荐 2-3 个核心模块 → 问是否生成 draft Module Spec
  - Q3: 其他 spec 体系兼容 — 检测已有 spec 目录（openspec/, .specify/, specs/ 等）→ 有则问迁移（推荐）还是 parasitic 套壳；无则默认 full，跳过此问
  - `references/commands/init.md` 执行步骤更新
  - 可能的 `scripts/specanchor-init.sh` 辅助逻辑
- **Out-of-Scope**:
  - 实际迁移工具（从 OpenSpec/Spec-Kit 内容转换到 SpecAnchor 格式）— 那是独立 task
  - Hook 的自动测试框架
  - init.sh 的 TUI/交互式 shell 界面（确认点由 Agent 实现，不是 shell）

## 1.1 Context Sources
- Requirement Source: 本 session 对话讨论
- Design Refs: `references/commands/init.md` 现有步骤
- Chat/Business Refs: 用户提出的初始化体验痛点——"装完是空壳"
- Extra Context: `references/agents/claude-code.md`, `references/agents/cursor.md`, `references/agents/codex.md`, `references/agents/gemini.md` 各平台 hook 机制

## 1.2 Hard Boundaries
- 3 个确认点都是 Agent 侧交互（由 Agent 向用户问答），不是 shell 脚本的交互式 prompt
- 检测无果则跳过（无事不问原则）：无已有 spec 目录 → 跳过 Q3 默认 full；无法识别平台 → Q1 给出通用指引而非自动配置
- 不破坏现有 `--mode=full|parasitic` CLI 参数兼容性
- 不在 init 阶段创建 Task Spec（init 只设基础设施）

## 1.3 Allowed Freedom
- 各平台 hook 配置的具体模板内容
- Module Spec 推荐算法（代码量 vs 变更频率 vs 目录深度）
- Q3 迁移操作的具体实现细节

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

### 2.2 各平台 hook 机制（待深入研究）

| 平台 | Hook 机制 | Boot hook 形式 |
|------|-----------|---------------|
| Claude Code | `settings.json` hooks: `PreToolUse`, `PostToolUse`, `Notification` | SessionStart hook 或 `PreToolUse` 注入 boot |
| Cursor | `.cursor/rules/` + hooks | 待研究 |
| Codex | `agents.md` / `codex.md` 启动指令 | 写入 agents.md 的启动段 |
| Gemini | `GEMINI.md` + settings | 写入 GEMINI.md 的 boot 指令 |

### 2.3 Q2 Module Spec 推荐策略

候选算法：
- **代码量排序**: `find <dir> -name "*.ts" -o -name "*.py" | wc -l` 取 top 3
- **变更频率**: `git log --oneline --since=3.months -- <dir> | wc -l` 取 top 3
- **混合排序**: 代码量 × 0.4 + 变更频率 × 0.6 取 top 3

### 2.4 Q3 已有 spec 体系检测

init.md 已有 Type Registry（步骤 2）：
```
openspec/     → type: "openspec"
specs/        → type: "spec-kit"
mydocs/specs/ → type: "mydocs"
.qoder/specs/ → type: "qoder"
docs/specs/   → type: "generic"
```

用户选择迁移时的操作路径（待设计）：
- 读取已有 spec 内容 → 转换为 SpecAnchor 格式 → 写入 .specanchor/ → 建议用户确认后删旧目录
- 或简化版：只在 anchor.yaml 记录来源路径，后续手动迁移

## 2.1 Next Actions
- 深入研究各平台 hook 配置的具体 API/格式
- 确认 Q2 的 Module Spec 推荐算法选择
- 设计 Q3 迁移操作的边界（本 task 做到哪，独立 task 做到哪）

## 4. Plan (Contract)

> 待 Research 完成后填充

### 4.1 File Changes

| File | Change |
|---|---|
| `references/commands/init.md` | 重构执行步骤：在步骤 2-3 之间插入 Q1/Q2/Q3 交互点 |
| `scripts/specanchor-init.sh` | 可能加 `--detect-hooks` / `--scan-modules` 辅助 flag |
| `references/agents/claude-code.md` | 加 hook 配置模板 |
| `references/agents/cursor.md` | 加 hook 配置模板 |
| `references/agents/codex.md` | 加 hook 配置模板 |
| `references/agents/gemini.md` | 加 hook 配置模板 |
| `SKILL.md` | 可能更新 init 相关描述 |

### 4.3 Implementation Checklist

- [ ] Step 1: 研究各平台 hook 具体格式并写模板
- [ ] Step 2: 设计 Q2 Module Spec 推荐算法 + init.sh 扫描辅助
- [ ] Step 3: 设计 Q3 迁移边界（本 task vs follow-up）
- [ ] Step 4: 重写 init.md 执行步骤（插入 3 个交互点）
- [ ] Step 5: 更新 init.sh（若需辅助 flag）
- [ ] Step 6: 各 agent 适配文件加 hook 模板
- [ ] Step 7: 验证 — doctor + validate + tests
- [ ] Step 8: commit

### 4.7 Checkpoints — Contract

#### CP-1 三问设计确认
- Output: 3 个问题的交互流程描述 + 各平台 hook 模板 + 推荐算法选择
- Awaits: pass / clarify / redirect

#### CP-2 init.md 重写完成
- Output: 新旧步骤对比 + diff
- Awaits: pass / add-spec / redirect

## 5. Execute Log
- [ ] Step 1: ...

## 5.2 Checkpoint Decisions Log

### Recent (active, hot)

- **pre-plan-01** (2026-05-20, RESEARCH) [decision, active] @§1
  - rule: "3 个确认点：hook / module spec / spec 兼容。检测无果则跳过（无事不问）。确认点由 Agent 实现不是 shell 交互"
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
  - Hook 自动测试

## 6.2 Evidence Ledger

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-doctor.sh --strict` | pending | |
| `bash scripts/specanchor-validate.sh --strict` | pending | |
| `bash tests/run.sh` | pending | |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| init.md 含 3 个交互确认点 | init.md diff | pending |
| 各平台 hook 模板存在 | agent 适配文件 diff | pending |
| Q3 检测无果默认 full 跳过 | init.md 流程描述 | pending |
| 现有 CLI 兼容性不破坏 | tests 结果 | pending |

### Unverified Risks

- 各平台 hook 格式可能随 Agent 工具更新而变化
- Module Spec 推荐算法在 monorepo 场景下可能推荐错误模块

### Manual / External Checks Needed

- 在 Claude Code + Cursor + Codex 三个平台实测 init 交互流程

### Rollback / Follow-up Handle

- revert init.md + agent 适配文件即可

## 6.3 Capability Drift Check

- [ ] 本 spec 中描述的「现状 / 缺口 / 已知约束」是否仍然准确？
- [ ] 是否有「X 不感知 Y」/「需要 Step A/B/C」/「audit finding」类陈述已被后续代码超越？

## 7. Plan-Execution Diff
- Any deviation from plan: pending

## 7.2 Handoff Packet

> auto-generated by `specanchor-assemble.sh --mode=handoff`
> 不要手写。重新生成请运行 `specanchor_handoff`。
