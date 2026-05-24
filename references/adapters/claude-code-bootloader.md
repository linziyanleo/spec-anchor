# Claude Code Bootloader

最小 `CLAUDE.md` 引导片段。让 Claude Code 在每个新 session 里自动调用 SpecAnchor 装配 context bundle。

> 关联：`references/agents/claude-code.md`（详细 install）/ `references/agents/context-utilities.md`（utility 集合）
>
> 设计原则：**CLAUDE.md 只放 bootloader，不复制 SpecAnchor 全文规则**。Anthropic 官方建议 CLAUDE.md 短小、广泛适用；细分知识由 SpecAnchor 按需 assemble 注入。

---

## 推荐 CLAUDE.md 片段

复制以下内容到项目根的 `CLAUDE.md`（或追加到现有 CLAUDE.md）：

```markdown
## SpecAnchor Context Bootloader

This project uses [SpecAnchor](https://github.com/aone-open-skill/spec-anchor) as
its context construction system. SpecAnchor compiles bounded, auditable
engineering context bundles for coding agents. It does not own the agent loop.

### Session startup

For any non-trivial coding task, before editing code run:

```bash
SPECANCHOR_SKILL_DIR=.claude/skills/specanchor \
  bash .claude/skills/specanchor/scripts/specanchor-boot.sh --agent --intent="<one-line task description>"
```

This outputs a `specanchor.context_bundle.v1` JSON. Read every file listed in
`files_to_read` (respecting `load: summary|full`) before editing.

### Recording new findings

When you discover a non-obvious fact / contradiction / stale spec during
execution, do not let it disappear into chat history. Record it:

```bash
bash .claude/skills/specanchor/scripts/specanchor-finding.sh new \
  --topic="<short-kebab>" --type=fact --confidence=medium --impact=medium
```

Edit the generated file's frontmatter (visibility auto-derives, override if
needed) and fill in Observation / Evidence / Implications.

### Stop trigger check

Before declaring work done, run:

```bash
bash .claude/skills/specanchor/scripts/specanchor-stop-triggers.sh --staged --format=text
```

If any advisory trigger fires (api / schema / dependency / security path), do
not silently merge—surface the warning in your handoff summary.

### What SpecAnchor does NOT do

- Does not enforce hard runtime boundaries (use git hooks / CI for that)
- Does not own workflow phase gates (those are opt-in via sdd-riper-one schema)
- Does not auto-apply findings to specs (sediment proposals require human review)
```

---

## 设计说明（不要复制到 CLAUDE.md）

### 为什么这么短

Anthropic 文档明确：`CLAUDE.md` 应该短小，只放每次会话都需要的广泛适用事实；流程化、细分知识应该用 skills / hooks / subagents 按需加载。

SpecAnchor 作为 skill 已经在 `.claude/skills/specanchor/` 安装时完成详细协议加载。CLAUDE.md 只需要告诉 Claude Code：

1. 这个项目有 SpecAnchor
2. 入口在哪里（boot --agent --intent）
3. 关键工具的最小命令（finding new、stop-triggers）
4. 边界声明（SpecAnchor 不做什么）

不需要复制 frontmatter schema、不需要复制 7 步循环、不需要复制 sdd-riper-one 流程——这些都已经在 skill 自身的 references/ 下。

### 何时不放这份 bootloader

- 项目用 `parasitic` 模式 + 只治理外部 sources：CLAUDE.md 只放 `references/agents/claude-code.md` 的精简版即可
- 项目用 `sdd-riper-one` 严格 workflow：bootloader 可以追加一句 "Use sdd-riper-one schema for high-risk tasks; otherwise default to context-only flow"
- 团队已有自家 CLAUDE.md 风格：把上面片段缩短到只保留 `Session startup` + `Recording new findings` 两节

### 升级路径

- v0.7 提供本 bootloader（手动复制）
- v0.8 候选：`specanchor-init.sh --emit-claude-md` 自动生成 + 注入

### 关联适配器

| Adapter | 状态 |
|---|---|
| Claude Code | **v0.7 本文档** |
| Codex AGENTS.md | v0.7 候选（同结构，换路径与命令） |
| Cursor `.cursor/rules` | v1.0+ |
| Kiro Steering | v1.0+ |
| Gemini CLI | v1.0+ |
