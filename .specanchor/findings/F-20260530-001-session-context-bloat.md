---
id: F-20260530-001
summary: same-session boot/assemble re-emits anchors; no cross-call de-dupe in scripts
type: risk
status: superseded
confidence: high
impact: medium
visibility: sediment_queue
affects:
  - module: scripts
  - module: 协议层
evidence_ref:
  - type: command
    ref: "specanchor-boot.sh --format=summary"
  - type: command
    ref: "specanchor-assemble.sh --files=SKILL.md,scripts/specanchor-boot.sh,scripts/specanchor-assemble.sh,references/assembly-trace.md,references/agents/context-utilities.md --format=text"
suggested_target: module
created: 2026-05-30
updated: 2026-05-31
source_task: null
---

# Finding: session-context-bloat

## Observation

`specanchor-boot.sh --format=summary` 每次调用都会重新输出 Global summary、active tasks、available modules/commands 等启动摘要；`specanchor-assemble.sh` 单次调用内会按 path 去重，但没有跨调用或跨 session 状态。针对本次 dogfood 的多文件 assemble 输出仍要求读取 3 个 Global summary、`scripts.spec.md` summary、`project-codemap.md` summary、`references.spec.md` full。本机还同时暴露 root skill 与 plugin-local wrapper skill；Codex/Claude skill symlink 均指向 `~/.skills-manager/skills/spec-anchor`。

## Why It Matters

如果同一 agent session 内多次触发 SpecAnchor skill/boot/assemble，历史消息里会保留重复的 Global summary、Module spec/codemap 锚点和 active task 摘要。单次 bundle 是 bounded 的，但同一 session 多轮重复激活仍会线性增加对话上下文。

## Evidence

- Boot dogfood: `SpecAnchor Boot [full]` reported `Global: summary` for 3 global specs, `Module: deferred`, 17 active tasks, and available commands/modules.
- Assemble dogfood: output reported `Budget: normal, 6 files / 408 estimated lines`, with Global summaries repeated and `references.spec.md` loaded as full.
- Source check: `scripts/specanchor-assemble.sh` deduplicates only within `FILES_TO_READ_PATHS`; no persisted session cache or "already loaded" marker exists across script invocations.
- Machine-local check: `~/.codex/skills/spec-anchor` and `~/.claude/skills/spec-anchor` both symlink to `~/.skills-manager/skills/spec-anchor`; that install contains both `SKILL.md` and `skills/spec-anchor/SKILL.md` wrapper.
- Hook check: Codex `~/.codex/hooks.json` has no SpecAnchor SessionStart hook; Claude has spec-anchor plugin enabled and the plugin hook injects a mandatory "use spec-anchor" prompt for projects with `anchor.yaml`/`.specanchor`.
- Repo/source drift check: the working repo's `hooks/session-start` can call `boot --format=inline-brief`, but the installed skill's active hook does not inject inline summaries and its boot script does not accept `--format=inline-brief`.

## Implications

Accepting this finding should affect the boot/assemble loading contract, not the Global/Module specs directly. A future change could add an agent-side guidance rule, trace cache, or "delta since last trace" mode, but it should preserve fail-fast behavior and bounded per-call output.

## Proposed Action

Create a sediment proposal or task for same-session context control before changing scripts. The minimal direction is to document that boot is session-start/preflight, while repeated module/context refreshes should prefer targeted assemble output and should not reprint already loaded full spec bodies unless the target set or freshness changed.
