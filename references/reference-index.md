# Reference Index

SpecAnchor 协议文档索引。按需查阅，不在 boot 时加载。

## Commands

- `references/commands-quickref.md`：自然语言意图 → 内部命令 ID（boot routing 缺失时的 fallback）

## Protocol & Contract

- `references/specanchor-protocol.md`：核心协议总览
- `references/script-contract.md`：脚本清单、调用契约、输出边界
- `references/assembly-trace.md`：Assembly Trace 格式与刷新时机
- `references/workflow-gates.md`：workflow 选择（context-only / lightweight / schema-driven）与严格门禁规则
- `references/external-sources-protocol.md`：外部 sources 治理与 frontmatter 注入

## Agent Adapters

- `references/agents/context-utilities.md`：SpecAnchor 提供给 agent 的 context 装配/记录能力（v0.6 主入口）
- `references/agents/agent-contract.md`：**deprecated alias** → 指向 context-utilities.md + integrations/sdd-riper-one-flow.md
- `references/agents/claude-code.md` / `codex.md` / `cursor.md` / `gemini.md`：常见代理入口的使用说明

## Integrations

- `references/integrations/sdd-riper-one-flow.md`：sdd-riper-one 7 步 workflow 流程（opt-in）
- `references/integrations/sdd-riper-one.md`：sdd-riper-one schema 接入方式
- `references/integrations/superpowers.md`：与 superpowers 的协作和降级规则
- `references/integrations/goal-hook.md`：goal-hook 与 Schema Gate 的交互

## Concepts

- `references/concepts/capability-drift.md`：Capability Drift 概念定义（spec 描述被后续代码超越）
- `references/concepts/findings-ledger.md`：v0.6 新增——Findings 独立 artifact 协议
- `references/concepts/sediment-proposal.md`：v0.6 新增——Sediment Proposal hot→cold 回流协议

## Templates

- `references/templates/finding-template.md` / `sediment-proposal-template.md`：v0.6 新增——模板

## Skills

- `references/skills/spec-anchor-prelude/SKILL.md`：superpowers 流程的 Spec Landscape 预加载 skill

Additional draft command protocols may exist under `references/commands/` (e.g. `codemap.md`); these are not yet routable.
