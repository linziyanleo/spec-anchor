---
name: spec-anchor
description: "MUST invoke in projects with anchor.yaml or .specanchor/ — before code changes, reviews, spec/context management, alignment checks, handoff, findings, or sediment work. Loads coding standards, module contracts, and active tasks."
---

<HARD-GATE>
If this project has `anchor.yaml` or `.specanchor/`, load SpecAnchor context before code changes or reviews.
Specs contain constraints not visible in code alone — even for small edits, assemble context first.
Read-only mechanical operations (grep, find, git log, running tests) do not require SpecAnchor boot.
</HARD-GATE>

# SpecAnchor

> SpecAnchor compiles bounded, auditable, sedimentable engineering context for coding agents. It does not own the agent loop.
>
> SpecAnchor 为 AI coding agent 编译有边界、可审计、可沉淀的工程上下文。它不拥有 agent 执行循环。

Spec 是 cold context 来源之一，代码是船，**Context Bundle 是 SpecAnchor 的核心交付物**。SpecAnchor 把工作记忆显式分为四类产物——Spec / Decision / Evidence / Finding——按 inclusion / budget / freshness / staleness 装配成 Bundle 交给 agent。Agent 在执行中产生的新发现回写为 Finding，经 Sediment Proposal 由人 batch review 后才进入长期 Spec。跨 session 通过 `specanchor_handoff` 导出 handoff packet 重启。

主 `SKILL.md` 只负责入口和 boot；详细协议下沉到 `references/`：

- Context utilities：`references/agents/context-utilities.md`
- Workflow gates：`references/workflow-gates.md`
- Command quickref：`references/commands-quickref.md`
- Reference index：`references/reference-index.md`

## Script Invocation

Skill 脚本位于 Skill 根目录的 `scripts/` 下，运行时必须站在用户项目根目录。

```bash
# $SA_SKILL_DIR = SKILL.md 所在目录
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/<script-name>.sh" [args]
```

Keep long options as a single shell argument: use `--format=summary`, never `-- format=summary`.

## Boot Requirement

激活后先运行：

```bash
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-boot.sh"
```

- `--format=summary`：人类可读摘要
- `--format=full`：额外附带 Global Spec 正文
- `--format=json`：机器可读 JSON

**Boot 是 session-start / preflight，同一 session 原则上只运行一次。** 同 session 内后续的上下文需求不要重复 boot——改用 targeted `specanchor-assemble.sh --files=...`（见 Loading Strategy）。

## Assembly Trace

每轮都要显式输出一次 Assembly Trace：

```text
Assembly Trace:
  - Global: summary|full|none|skipped -> <files or reason>
  - Module: full|deferred|sources-only|none -> <files or reason>
```

完整规则见 `references/assembly-trace.md`。

## Loading Strategy

- `full`：始终加载 `anchor.yaml` + 全部 Global Spec；Module Spec 按需加载。
- `parasitic`：只加载 `anchor.yaml` 与外部 `sources`；不创建 full-only Spec。
- 需要判断该读哪些模块时，优先看 boot 输出的 `Available Commands:` / `Available Modules:` 段；boot 不可用时 fallback 到 `references/commands-quickref.md`。
- 复杂编码任务应在 boot 之后运行 `specanchor-assemble.sh --files=... --intent=...`，先拿到 bounded read plan，再进入编辑。

## Post-Coding Chain

After completing a coding task, run through this chain:

1. **Alignment Check** — compare changes against loaded specs. Run `specanchor_check` or manually verify that modified files still conform to their Module Spec contracts.
2. **Record Findings** — if new facts, contradictions, risks, or drift were discovered, record via: `SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-finding.sh" new --topic=<slug> --summary=<single-line summary>`.
3. **Evaluate Sediment** — if findings reveal spec drift or missing constraints, draft a Sediment Proposal (`references/concepts/sediment-proposal.md`) to flow hot context back into cold specs.

Always run Alignment Check. Record Findings and Evaluate Sediment can be skipped when no new facts, risks, or drift were discovered.
