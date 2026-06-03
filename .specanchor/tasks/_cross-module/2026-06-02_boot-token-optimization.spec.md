---
specanchor:
  level: task
  task_name: "Boot Token 消耗优化：分级触发 + hook 精简 + SKILL.md 瘦身 + task compact"
  author: "@方壶"
  created: "2026-06-02"
  status: "draft"
  writing_protocol: "simple"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
    - ".specanchor/global/architecture.spec.md"
---

# Boot Token 消耗优化：分级触发 + hook 精简 + SKILL.md 瘦身 + task compact

> **Intent**：将 spec-anchor 每次 boot 的 token 消耗从 ~5,000（summary 模式）降低 40%，通过四个独立方向并行优化：①只有编码/review 任务才触发 boot；②SessionStart hook 静态载荷精简（保留动态 context 块）；③SKILL.md 拆分为轻量入口 + 按需 detail；④boot 输出中 task spec 新增 compact 模式。
>
> **Review**：经 Claude × Codex 双 agent 5 轮收敛式评审（`agent_review_20260602-211626-pane-p_1-8ac9`）。关键修正：v1→v2 修正 `--tasks` 参数契约冲突 + 放弃 /tmp 缓存方案；v2→v3 补充 review 类工作到触发条件；v3→v4 修正 hook 载荷分析（补充 inline-brief 动态块）。

## 方向四：boot 输出 task compact 模式（最安全）

- **保留现有 `--tasks=open|all|none` 参数及其行为不变**
- 新增 `--tasks=compact` opt-in 模式：输出 `- <task_name> [<status>]`，去掉 phase/schema/路径
- inline-brief 模式的 task 输出调整为 compact 格式
- 更新 `scripts.spec.md` 补充 `--tasks=compact` 签名
- 新增 focused tests

## 方向三：SKILL.md 拆分

将 SKILL.md 从 144 行瘦身至 ~60 行。

保留：`<HARD-GATE>` + 核心说明 + Script Invocation + Boot Requirement + Assembly Trace + Loading Strategy + Post-Coding Chain。

移出：Command Routing 表（boot 输出已包含）、Reference Index（→ `references/reference-index.md` 新建）、Workflow Selection（→ 已有 `references/workflow-gates.md`）。

## 方向一：分级触发

修改触发语义，**所有来源保持一致**（hook、SKILL.md、boot-install 模板、4 个 agent adapter docs）：

```
You MUST use the spec-anchor skill when:
1. Starting a coding task that creates, modifies, or refactors code files
2. Reviewing code, diffs, plans, specs, or findings that require loaded project context
3. The user explicitly mentions spec, context, module, task, finding, alignment, or project conventions
4. The user asks to check alignment, manage specs, handoff, or review findings

You do NOT need spec-anchor for:
- Purely mechanical read-only operations: grep, find, git log, viewing file contents
- Running tests or build commands
- Git operations: commit, push, branch management
- Answering factual questions that don't require evaluating project correctness
```

## 方向二：SessionStart hook 载荷精简

放弃 /tmp 缓存方案。改为静态载荷精简 + 动态块保留。

当前 hook 载荷有两部分（repo HEAD `hooks/session-start`，98 行）：
1. **静态 IMPORTANT 触发块**（~1,400 字节）→ 精简至 ~600 字节（删除"Do NOT skip"段和"Post-Coding Chain"段，SKILL.md 中已有）
2. **动态 `<spec-anchor-context>` 块**（由 `specanchor-boot.sh --format=inline-brief` 生成）→ 保留不变（现有测试依赖）

Token 预算分离：
- 静态触发块：~500 → ~150 token
- 动态 context 块：由 inline-brief 输出决定，通过方向四间接优化

## Affected files

| 文件 | 方向 | 改动类型 |
|------|------|---------|
| `scripts/specanchor-boot.sh` | ④ | 新增 `--tasks=compact` 模式 |
| `.specanchor/modules/scripts.spec.md` | ④ | 补充 `--tasks=compact` 签名 |
| `SKILL.md` | ③① | 拆分内容 + 收窄 HARD-GATE |
| `references/reference-index.md` | ③ | 新建 |
| `hooks/session-start` | ①② | 收窄触发条件 + 精简静态载荷 |
| `scripts/specanchor-boot-install.sh` | ① | 更新注入模板 |
| `references/agents/claude-code.md` | ① | 同步触发条件 |
| `references/agents/codex.md` | ① | 同步触发条件 |
| `references/agents/cursor.md` | ① | 同步触发条件 |
| `references/agents/gemini.md` | ① | 同步触发条件 |

## 硬约束

- boot `--format=json` 输出结构不变
- `--tasks=open|all|none` 行为和默认值不变
- `<spec-anchor-context>` tag 和 inline-brief 调用保留
- scripts.spec.md §4 无持久化状态
- 不改 Global/Module Spec 正文语义

## Verification

- 方向四：`--tasks=compact` 格式正确；`--tasks=open` / `--tasks=all` 不退化；json 完整
- 方向三：SKILL.md ≤ 70 行；boot 正常完成；Available Commands 可见
- 方向一：只读不触发；review 触发；编码触发；五来源一致性；boot-install dry-run diff
- 方向二：静态块 ≤ 600 字节；`<spec-anchor-context>` tag 存在；`/clear` 后仍注入；hook 测试通过
- 全部：`bash tests/run.sh` + `SPECANCHOR_RUN_BATS=1 bash tests/run_all.sh` 无退化
