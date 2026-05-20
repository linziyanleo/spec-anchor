---
name: spec-anchor-prelude
description: "Use BEFORE invoking any superpowers process skill (brainstorming, writing-plans, executing-plans, systematic-debugging) in a project that contains anchor.yaml or .specanchor/. Loads the project's Spec Landscape (Global/Module Spec + Available Commands + Active Tasks) into context so subsequent design/plan work stays anchored. Skip ONLY when the working directory has no anchor.yaml and no .specanchor/ subdir."
---

# Spec Anchor Prelude

**One purpose:** Before any creative or planning skill runs, materialize the project's Spec Landscape so design/plan decisions are made *inside* the team's pre-compiled spec context, not in the void.

This skill is the bridge between the **superpowers process layer** (brainstorming → writing-plans → executing-plans) and the **spec-anchor context control plane** (Spec / Decision / Evidence).

## When to invoke

Invoke this skill **before** any of these:

- `superpowers:brainstorming`
- `superpowers:writing-plans`
- `superpowers:executing-plans`
- `superpowers:subagent-driven-development`
- `superpowers:systematic-debugging` (when the bug touches multiple modules)

**Skip** only when:

- Working directory has **no** `anchor.yaml` and **no** `.specanchor/` subdir
- Task is a pure non-coding chat (e.g., "explain regex")

## What this skill does

A single, deterministic 4-step prelude. No interactive questions.

### Step 1 — Locate spec-anchor

```bash
# Locate the spec-anchor skill installation. Two common patterns:
# (a) Repo-vendored: $REPO/scripts/specanchor-boot.sh
# (b) Plugin install: ~/.claude/plugins/cache/.../spec-anchor/scripts/specanchor-boot.sh
SA_DIR=""
if [[ -f scripts/specanchor-boot.sh ]]; then
  SA_DIR="$PWD"
elif [[ -d "$HOME/.claude/plugins/cache" ]]; then
  SA_DIR=$(find "$HOME/.claude/plugins/cache" -name "specanchor-boot.sh" -path "*spec-anchor*" 2>/dev/null | head -1 | xargs dirname | xargs dirname)
fi
[[ -z "$SA_DIR" ]] && { echo "spec-anchor not installed — Skill prelude SKIPPED"; exit 0; }
```

### Step 2 — Run boot, capture Spec Landscape

```bash
SPECANCHOR_SKILL_DIR="$SA_DIR" bash "$SA_DIR/scripts/specanchor-boot.sh" --format=summary
```

Read the output for:
- **Landscape Readiness** — 🟢/🟡/🔴 status
- **Global Specs** — files and line counts
- **Active Tasks** — task_name + status + RIPER phase + writing_protocol (schema-aware：fluid schema 不显示 phase)
- **Available Commands** — internal IDs for routing
- **Available Modules** — what modules already have specs

### Step 3 — Decide workflow intensity

> **Status 语义**：Active Tasks 段会列出所有未归档 task。本表中 "in-progress" 严格指 `status: in_progress`（不含 review / draft / done 未归档）。其他状态作为信号但不阻断。

| Landscape Readiness | status == in_progress | Recommendation |
|---|---|---|
| 🟢 READY | 0 | Proceed to superpowers skill with full context；如有 review / draft 状态 task 仅向用户报告其存在 |
| 🟢 READY | ≥1 | **Stop.** Read the in-progress task spec(s) first. Confirm with user whether to continue existing work or start new. |
| 🟡 ATTENTION | any | Surface attention reasons to user. Proceed only after acknowledgement. |
| 🔴 NOT_READY | any | **Block.** Run `specanchor_init` / `specanchor_global` first. Do NOT invoke any process skill. |

**Implementation hint**：用 `--format=json` 取 `active_tasks[]` 然后 `filter(t.status=="in_progress")` 比解析 text 输出更可靠。

### Step 4 — Hand off with explicit context

Before invoking the chosen superpowers skill, announce in one sentence:

> Spec Landscape: 🟢 READY · 3 globals · N modules fresh · M in-progress task(s) · Available commands loaded.

Then invoke `superpowers:brainstorming` (or whichever was requested).

## Hard rules

- **Never skip step 3 reading active task specs** when Landscape Readiness shows them.
- **Never propose architectural decisions** without referencing at least one of: Global Spec, Module Spec, or related Task Spec.
- **Never invent business rules** that aren't in the loaded specs — instead, ask the user or create a new Task Spec via `specanchor_task`.

## Why this exists (rationale)

superpowers process skills (brainstorming, writing-plans, etc.) are project-agnostic — they ask great questions but don't know your team's conventions, in-progress work, or already-decided trade-offs. Without spec-anchor in the loop, agents repeatedly re-derive context from scratch.

spec-anchor compiles that knowledge into `.specanchor/` ahead of time. This prelude skill makes sure the superpowers process always **starts** with that compiled context loaded — turning "vibe coding from prompt" into "spec-anchored design".

## Anti-patterns

| Anti-pattern | Why it's wrong |
|---|---|
| "Just brainstorm first, we'll check spec later" | Late-bound spec check produces re-work; superpowers skills make decisions *during* brainstorm |
| "The project is too small to need spec-anchor" | If anchor.yaml exists, the team has decided to use it — respect that |
| Calling `specanchor-boot.sh` manually without reading the output | Loading bytes ≠ loading context. Read and reason about Active Tasks, Available Modules. |
| Skipping when `.specanchor/` exists but `anchor.yaml` doesn't | `.specanchor/` alone is a valid spec-anchor configuration (legacy compat) |

## Composability

This skill outputs `Spec Landscape Loaded: <summary>` and then chains into the requested process skill. It is intentionally short (≤200 lines) and side-effect-free except for reading files and one boot script invocation.

## Reference

- spec-anchor full agent contract: `references/agents/agent-contract.md` (7 steps; this skill executes step 1)
- spec-anchor command quickref: `references/commands-quickref.md`
- Why three context categories: spec-anchor `WHY.md` §"三类 Context"
- Dogfood validation (2026-05-20 11:05 CST): 在 spec-anchor 自身仓库实测——`boot --format=json` snapshot 返回 9 active tasks，其中 1 个 `status: in_progress` → 触发 STOP 判定正确；fluid schema task 在 text 模式不显示 phase，JSON 模式保留 `phase` 字段且值为空字符串。
- Status 语义辨析背景：详见 `references/concepts/capability-drift.md` Capability Drift 概念，以及 `references/schemas/sdd-riper-one/template.md §6.3` 落地点。
