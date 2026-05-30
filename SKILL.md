---
name: spec-anchor
description: "MUST invoke in projects with anchor.yaml or .specanchor/ — before code changes, spec/context management, alignment checks, handoff, findings, or sediment work. Loads coding standards, module contracts, and active tasks."
---

<HARD-GATE>
If this project has `anchor.yaml` or `.specanchor/`, load SpecAnchor context before code changes.
Specs contain constraints not visible in code alone — even for small edits, assemble context first.
</HARD-GATE>

# SpecAnchor

> SpecAnchor compiles bounded, auditable, sedimentable engineering context for coding agents. It does not own the agent loop.
>
> SpecAnchor 为 AI coding agent 编译有边界、可审计、可沉淀的工程上下文。它不拥有 agent 执行循环。

Spec 是 cold context 来源之一，代码是船，**Context Bundle 是 SpecAnchor 的核心交付物**。SpecAnchor 把工作记忆显式分为四类产物——Spec / Decision / Evidence / Finding——按 inclusion / budget / freshness / staleness 装配成 Bundle 交给 agent。Agent 在执行中产生的新发现回写为 Finding，经 Sediment Proposal 由人 batch review 后才进入长期 Spec。跨 session 通过 `specanchor_handoff` 导出 handoff packet 重启。

主 `SKILL.md` 只负责入口、路由和工作流选择；详细协议下沉到 `references/`：

- Context utilities（SpecAnchor 真正提供的能力）：`references/agents/context-utilities.md`
- Optional workflow integration（如 sdd-riper-one）：`references/integrations/sdd-riper-one-flow.md`

**Workflow 不属于 SpecAnchor 核心**——sdd-riper-one 等 schema 是 opt-in integration，新项目默认 `workflow.default: context-only`，不再默认强绑 7 步 deterministic loop。老项目（`writing_protocol.schema: sdd-riper-one`）继续兼容工作。

## Script Invocation

Skill 脚本位于 Skill 根目录的 `scripts/` 下，运行时必须站在用户项目根目录。

```bash
# $SA_SKILL_DIR = SKILL.md 所在目录
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/<script-name>.sh" [args]
```

Keep long options as a single shell argument: use `--format=summary`, never `-- format=summary`.

Shell 脚本是实现辅助工具，不是用户主交互语言。

## Boot Requirement

激活后先运行：

```bash
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-boot.sh"
```

- `--format=summary`：人类可读摘要
- `--format=full`：额外附带 Global Spec 正文
- `--format=json`：机器可读 JSON

如果 `anchor.yaml` 缺失，或 `mode=full` 但 `.specanchor/` 缺失，先修配置再继续。

**Boot 是 session-start / preflight，同一 session 原则上只运行一次。** 同 session 内后续的上下文需求不要重复 boot——改用 targeted `specanchor-assemble.sh --files=...`（见 Loading Strategy）。已经以 `full` 加载过的 Spec 正文不要重复打印，除非目标文件集合或 freshness 发生变化；后续轮次只在 Assembly Trace 里声明相对上一条 Trace 的 delta（见 `references/assembly-trace.md`）。这是 advisory 约束，保留 fail-fast 与每次调用 bounded 输出；脚本本身无持久化状态，"已加载" 账本由对话内的 Assembly Trace 维护。

## Assembly Trace

每轮都要显式输出一次 Assembly Trace，说明本轮到底加载了哪些 Spec、是摘要还是全文：

```text
Assembly Trace:
  - Global: summary|full|none|skipped -> <files or reason>
  - Module: full|deferred|sources-only|none -> <files or reason>
```

完整规则见 `references/assembly-trace.md`。

## Loading Strategy

Spec Landscape 的组装策略——决定 Agent 进入项目时看到的规格地形。

- `full`：始终加载 `anchor.yaml` + 全部 Global Spec；Module Spec 按需加载；`project-codemap.md` 按需加载。
- `parasitic`：只加载 `anchor.yaml` 与外部 `sources`；不创建 full-only Spec。
- 需要判断该读哪些模块时，优先看 boot 输出的 `Available Commands:` / `Available Modules:` 段；boot 不可用时 fallback 到 `references/commands-quickref.md` / `.specanchor/spec-index.md`。
- 当文件路径和任务意图已经明确时，复杂编码任务应在 boot 之后运行 `bash scripts/specanchor-assemble.sh --files=... --intent=...`，先拿到 bounded read plan，再进入编辑。

## Command Routing

自然语言是主用户接口。

- `specanchor_*` 是 Skill 内部命令 ID，用于把用户意图路由到对应协议文件。
- `SA:` 是可选的高级 shorthand，不是单独的 CLI 契约。
- `scripts/*.sh` 是实现层入口，不替代用户侧命令语言。

boot 输出已嵌入紧凑意图映射；命中后直接读对应命令定义文件。仅在 boot 输出缺失时回落到 `references/commands-quickref.md`。

| Internal ID | Purpose | Definition |
| --- | --- | --- |
| `specanchor_init` | 初始化配置与目录 | `references/commands/init.md` |
| `specanchor_global` | 创建或更新 Global Spec | `references/commands/global.md` |
| `specanchor_module` | 创建或更新 Module Spec | `references/commands/module.md` |
| `specanchor_infer` | 从代码逆推 Module Spec 草稿 | `references/commands/infer.md` |
| `specanchor_task` | 创建 Task Spec | `references/commands/task.md` |
| `specanchor_load` | 手动加载 Spec | `references/commands/load.md` |
| `specanchor_status` | 查看状态与覆盖率 | `references/commands/status.md` |
| `specanchor_check` | 运行对齐检测 | `references/commands/check.md` |
| `specanchor_index` | 更新 spec-index | `references/commands/index.md` |
| `specanchor_import` | 导入外部 SDD 配置 | `references/commands/import.md` |
| `specanchor_handoff` | 跨 session 导出 handoff packet | `references/commands/handoff.md` |

## Workflow Selection

SpecAnchor v0.6 默认是 **context-only workflow**——assemble context bundle、记录 finding、产生 sediment proposal；不强制阶段门禁。

- `⚡ lightweight`：单文件或小范围修复，直接执行，无需 Task Spec。
- `📋 context-only`（v0.6 新默认）：装配 context bundle，按需创建 Task Spec 跟踪复杂任务，不强制 Schema Gate。
- `🔒 schema-driven`（opt-in）：选择 sdd-riper-one / handoff / bug-fix 等具体 schema，启用相应 phase gate。
- 严格门禁（Schema Gate）仅在用户显式选择 strict schema 时生效，规则见 `references/workflow-gates.md`。
- `docs/superpowers/` 存在时，Task Spec 创建门禁降级为建议；见 `references/integrations/superpowers.md`。
- 无论哪种工作流：
  - 执行中发现新事实 → 写入 `.specanchor/findings/` 而非散落在聊天里
  - 编辑完成后 → 执行 Alignment Check + 评估 Sediment Proposal
  - Context utility 步骤见 `references/agents/context-utilities.md`
  - 可选 sdd-riper-one 7 步流程见 `references/integrations/sdd-riper-one-flow.md`

## Reference Index

- `references/commands-quickref.md`：自然语言意图 → 内部命令 ID（boot routing 缺失时的 fallback）
- `references/specanchor-protocol.md`：核心协议总览
- `references/script-contract.md`：脚本清单、调用契约、输出边界
- `references/assembly-trace.md`：Assembly Trace 格式与刷新时机
- `references/agents/context-utilities.md`：SpecAnchor 提供给 agent 的 context 装配/记录能力（v0.6 主入口）
- `references/agents/agent-contract.md`：**deprecated alias** → 指向 context-utilities.md + integrations/sdd-riper-one-flow.md
- `references/agents/claude-code.md` / `codex.md` / `cursor.md` / `gemini.md`：常见代理入口的使用说明
- `references/workflow-gates.md`：workflow 选择（context-only / lightweight / schema-driven）与严格门禁规则
- `references/external-sources-protocol.md`：外部 sources 治理与 frontmatter 注入
- `references/integrations/sdd-riper-one-flow.md`：sdd-riper-one 7 步 workflow 流程（opt-in）
- `references/integrations/sdd-riper-one.md`：sdd-riper-one schema 接入方式
- `references/integrations/superpowers.md`：与 superpowers 的协作和降级规则
- `references/integrations/goal-hook.md`：goal-hook 与 Schema Gate 的交互
- `references/concepts/capability-drift.md`：Capability Drift 概念定义（spec 描述被后续代码超越）
- `references/concepts/findings-ledger.md`：v0.6 新增——Findings 独立 artifact 协议
- `references/concepts/sediment-proposal.md`：v0.6 新增——Sediment Proposal hot→cold 回流协议
- `references/templates/finding-template.md` / `sediment-proposal-template.md`：v0.6 新增——模板
- `references/skills/spec-anchor-prelude/SKILL.md`：superpowers 流程的 Spec Landscape 预加载 skill

Additional draft command protocols may exist under `references/commands/` (e.g. `codemap.md`); these are not yet routable and are excluded from the Command Routing table above.

## Post-Coding Chain

After completing a coding task, run through this chain:

1. **Alignment Check** — compare changes against loaded specs. Run `specanchor_check` or manually verify that modified files still conform to their Module Spec contracts.
2. **Record Findings** — if new facts, contradictions, risks, or drift were discovered, record via: `SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-finding.sh" new --topic=<slug> --summary=<single-line summary>`.
3. **Evaluate Sediment** — if findings reveal spec drift or missing constraints, draft a Sediment Proposal (`references/concepts/sediment-proposal.md`) to flow hot context back into cold specs.

Always run Alignment Check. Record Findings and Evaluate Sediment can be skipped when no new facts, risks, or drift were discovered.
