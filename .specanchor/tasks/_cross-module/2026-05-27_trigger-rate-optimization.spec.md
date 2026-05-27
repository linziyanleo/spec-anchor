---
title: "SpecAnchor 触发率优化：五层触发体系实现"
status: done
created: 2026-05-27
intent: >
  将 spec-anchor 从被动等待调用的 skill 升级为主动触发的 plugin+skill 混合体，
  通过 SessionStart hook 注入 + 命令式短 description + 宽触发面积 + 防跳过对策 +
  链式调用 五个层面全面提升触发率，对标 superpowers 的触发机制设计。
scope:
  - SKILL.md (description 重写)
  - hooks/ (新建目录 + SessionStart 脚本)
  - package.json (新建，插件化)
  - scripts/specanchor-boot-install.sh (增强 hook 注入)
  - references/skills/spec-anchor-prelude/SKILL.md (链式调用增强)
specanchor:
  writing_protocol: simple
---

# SpecAnchor 触发率优化：五层触发体系实现

## 问题分析

### 现状

spec-anchor 在技能列表中的触发率远低于 superpowers，核心原因是**触发机制设计**而非技能质量。
通过对 superpowers v5.0.7 的逆向分析，识别出 5 个关键差距：

| 层面 | superpowers 做法 | spec-anchor 现状 | 差距 |
|------|-----------------|-----------------|------|
| **SessionStart Hook** | `hooks/hooks.json` 注册 SessionStart，脚本将 `using-superpowers` 全文注入 `<EXTREMELY_IMPORTANT>` 标签的 additionalContext | 依赖 CLAUDE.md 注入（boot-install），不在 additionalContext 层级 | 结构性缺失 |
| **Description 写法** | 命令式，~15-30 字，前置触发条件（"You MUST use this before..."） | 解释性，~200 字，概念在前触发条件在后 | 信噪比过低 |
| **触发面积** | 覆盖 ~95% 编程场景（brainstorming=新功能, debugging=bug, verification=完成） | 限定"有 anchor.yaml 的项目"+ 特定关键词 | 面积过窄 |
| **防跳过对策** | Red Flags 表（12 条）+ "1% chance = MUST" + rationalization prevention | 无 | 完全缺失 |
| **链式调用** | brainstorming→writing-plans→executing-plans→verification 闭环 | spec-anchor-prelude 存在但未被系统性连接 | 雏形未成链 |

### 根因

spec-anchor 是作为 `~/.claude/skills/` 下的独立 skill 分发的，没有利用 Claude Code 的 plugin 能力（hooks, agents, commands）。
superpowers 是一个完整的 plugin（`superpowers@claude-plugins-official`），享受了 plugin 系统的全部能力。

## 实现方案

### 总体架构

```
spec-anchor/                          # 同时是 skill + plugin
├── package.json                      # [新建] 插件元数据
├── hooks/
│   ├── hooks.json                    # [新建] SessionStart hook 定义
│   ├── run-hook.cmd                  # [新建] 跨平台 hook 入口（polyglot）
│   └── session-start                 # [新建] SessionStart 脚本
├── skills/
│   └── spec-anchor/
│       └── SKILL.md                  # [原有] 移入 skills/ 子目录（插件 skill 约定）
├── scripts/                          # [原有] 保持不变
├── references/                       # [原有] 保持不变
└── ...
```

**关键决策：plugin + skill 双重身份**

- 作为 plugin 提供 SessionStart hook（`hooks/hooks.json`）
- 作为 plugin 内嵌 skill（`skills/spec-anchor/SKILL.md`）——这是 superpowers 的做法：plugin 根目录下有 `skills/` 子目录，每个 skill 有自己的 `SKILL.md`
- plugin 安装后，skill 自动通过 `<plugin-name>:spec-anchor` 命名空间被发现

---

### 第一层：SessionStart Hook 注入

**目标**：在每次会话开始时，如果当前目录存在 `anchor.yaml` 或 `.specanchor/`，自动注入 additionalContext，强制 agent 调用 spec-anchor skill。

#### 1.1 `hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

与 superpowers 完全一致的结构。`async: false` 确保 hook 在 agent 收到第一条消息之前完成。

#### 1.2 `hooks/session-start` 脚本

```bash
#!/usr/bin/env bash
# SessionStart hook for spec-anchor plugin
#
# 检测当前目录是否为 SpecAnchor 项目（anchor.yaml 或 .specanchor/），
# 如果是，注入 additionalContext 强制 agent 在编码前调用 spec-anchor skill。
# 如果不是，静默退出（零副作用）。

set -euo pipefail

# ── 检测项目 ──
if [[ ! -f "anchor.yaml" ]] && [[ ! -d ".specanchor" ]]; then
  # 不是 SpecAnchor 项目，静默退出
  printf '{}\n'
  exit 0
fi

# ── 构建注入内容 ──
# 设计原则：
# 1. 短——比 CLAUDE.md 中的触发块更强（additionalContext 优先级更高）
# 2. 命令式——直接告诉 agent 必须做什么
# 3. 包含防跳过对策——预判 agent 可能的跳过理由
# 4. 引导链式调用——在 superpowers 技能之前先加载 spec context

escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# 检查项目名
project_name=""
if [[ -f "anchor.yaml" ]]; then
  project_name=$(grep -E '^[[:space:]]*project_name:' anchor.yaml 2>/dev/null \
    | head -1 | sed 's/.*project_name:[[:space:]]*//' | tr -d '"'"'" || true)
fi
[[ -z "$project_name" ]] && project_name="this project"

# 构建 context 内容（纯文本，非 markdown）
read -r -d '' CONTEXT_BODY <<'CONTEXT_EOF' || true
This project uses SpecAnchor for spec-anchored development.

MANDATORY: Before writing, editing, or reviewing ANY code in this project, you MUST invoke the `spec-anchor` skill to load the project's Spec Landscape (coding standards, module contracts, active tasks). This applies to EVERY coding action — bug fixes, features, refactors, reviews.

MANDATORY: Before invoking any superpowers process skill (brainstorming, writing-plans, executing-plans, systematic-debugging), you MUST first invoke `spec-anchor` (or `spec-anchor-prelude`) to load spec context. Design decisions made without spec context produce re-work.

DO NOT RATIONALIZE SKIPPING:
| "The task is too simple" → Simple tasks still must follow project conventions loaded by spec-anchor. |
| "I already know the codebase" → Conventions change. Load current specs. |
| "I'll check specs after coding" → Late-bound spec check produces re-work. Load before coding. |
| "Let me explore first" → spec-anchor tells you WHERE to look. Invoke it first. |
| "This is just a quick fix" → Quick fixes in the wrong pattern create tech debt. Load specs. |
CONTEXT_EOF

context_escaped=$(escape_for_json "$CONTEXT_BODY")
session_context="<IMPORTANT>\nSpecAnchor Project Detected: ${project_name}\n\n${context_escaped}\n</IMPORTANT>"

# ── 输出 JSON ──
# 适配不同平台（与 superpowers 一致的检测逻辑）
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  printf '{\n  "additional_context": "%s"\n}\n' "$session_context"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
  printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$session_context"
else
  printf '{\n  "additionalContext": "%s"\n}\n' "$session_context"
fi

exit 0
```

**关键设计决策**：

- **条件注入**：只在检测到 anchor.yaml / .specanchor/ 时注入，不是所有项目。这和 superpowers 不同——superpowers 无条件注入，因为它是通用技能；spec-anchor 是项目专属的，无条件注入会在非 SpecAnchor 项目中产生噪音。
- **`<IMPORTANT>` 而非 `<EXTREMELY_IMPORTANT>`**：避免与 superpowers 的标签竞争。superpowers 用 `<EXTREMELY_IMPORTANT>` 是因为它是通用的元技能调度器；spec-anchor 是项目级上下文，用 `<IMPORTANT>` 足够且更合理。
- **内联防跳过表**：直接在注入内容中包含 5 条防跳过理由，不需要额外 skill 加载。
- **superpowers 链式引导**：明确要求在 superpowers 技能之前先调用 spec-anchor。

#### 1.3 `hooks/run-hook.cmd` 跨平台入口

直接复用 superpowers 的 polyglot 结构（cmd.exe + bash 双入口），改路径即可。

#### 1.4 `package.json`

```json
{
  "name": "spec-anchor",
  "version": "0.7.0",
  "type": "module",
  "description": "Spec-anchored development — compile bounded, auditable engineering context for coding agents",
  "keywords": ["spec", "context", "coding-standards", "module-contracts"]
}
```

最小化的 package.json，仅声明插件身份。不引入任何 npm 依赖。

---

### 第二层：命令式短 Description

**目标**：重写 SKILL.md 的 description frontmatter，从解释性改为命令式。

#### 当前（200+ 字，解释性）

```yaml
description: "Context Construction System for AI coding agents——为 agent 编译有边界、
  可审计、可沉淀的工程上下文。三类工作记忆产物...只要项目中有 anchor.yaml 或 .specanchor/
  目录...就应该使用此 Skill。"
```

#### 目标（~40 字，命令式）

```yaml
description: >-
  MUST invoke before writing code in projects with anchor.yaml or .specanchor/ —
  loads coding standards, module contracts, and active tasks to anchor implementation.
```

**设计原则**：
1. 以 MUST 开头，命令式语气
2. 前置触发条件（"before writing code in projects with..."）
3. 说明做什么（"loads coding standards, module contracts..."）
4. 说明为什么（"to anchor implementation"）
5. 不解释内部概念（不提 Context Bundle, Sediment, Finding 等）

---

### 第三层：宽触发面积

**目标**：让 spec-anchor 的触发条件覆盖更多场景。

#### 策略

触发面积通过**两层协同**实现：

1. **SessionStart Hook（第一层已覆盖）**：在项目级别自动触发，不依赖用户消息中的关键词。这是最宽的触发面积——只要项目有 anchor.yaml，每次会话都会被提醒。

2. **Description 中的场景覆盖**：不限于"有 anchor.yaml 的项目"这一条件触发，而是描述覆盖的**场景**。

#### 在技能列表中的展示

技能列表中的 description 由 SKILL.md 的 frontmatter 控制。优化后：

```
- spec-anchor: MUST invoke before writing code in projects with anchor.yaml
  or .specanchor/ — loads coding standards, module contracts, and active tasks
  to anchor implementation.
```

对比 superpowers 的展示：
```
- superpowers:brainstorming: You MUST use this before any creative work...
```

格式一致，命令式语气一致，触发条件前置。

#### 同时触发的场景扩展

在 SessionStart 注入中已经覆盖了这些场景：
- 写代码 → MUST
- 编辑代码 → MUST
- review 代码 → MUST
- bug fix → MUST
- refactor → MUST
- 调用 superpowers 技能 → MUST first

这比 description 中的静态触发词列表（规范、约定、对齐...）覆盖面广得多。

---

### 第四层：防跳过对策

**目标**：预判 agent 可能的跳过理由并提前反驳。

#### 4.1 SessionStart 注入中的防跳过表

已在第一层的 session-start 脚本中内联。5 条最常见的跳过理由：

| 跳过理由 | 反驳 |
|---------|------|
| "The task is too simple" | Simple tasks still must follow project conventions |
| "I already know the codebase" | Conventions change. Load current specs. |
| "I'll check specs after coding" | Late-bound spec check produces re-work |
| "Let me explore first" | spec-anchor tells you WHERE to look |
| "This is just a quick fix" | Quick fixes in wrong pattern create tech debt |

#### 4.2 SKILL.md 中的防跳过强化

在 SKILL.md 的 Boot Requirement 之前添加一个 Hard Gate 区块：

```markdown
<HARD-GATE>
This skill is MANDATORY in SpecAnchor projects. Do NOT skip boot.
Do NOT write code before the Spec Landscape is loaded.
Do NOT propose architectural decisions without referencing loaded specs.
</HARD-GATE>
```

#### 4.3 spec-anchor-prelude 中的防跳过

已有 Anti-patterns 表。保持不变，已经足够好。

---

### 第五层：链式调用

**目标**：让 spec-anchor 与 superpowers 形成工作流链，而不是并行的孤立系统。

#### 当前状态

- `spec-anchor-prelude` skill 存在，设计用于在 superpowers 技能之前调用
- 但 prelude 的 description 太长（~60 字），且没有被 superpowers 的 using-superpowers 元技能引用
- superpowers 不知道 spec-anchor-prelude 的存在

#### 方案

**5.1 SessionStart 注入中的链式引导**（已在第一层实现）

注入内容明确要求：
> "Before invoking any superpowers process skill (brainstorming, writing-plans, executing-plans, systematic-debugging), you MUST first invoke `spec-anchor` (or `spec-anchor-prelude`)"

这样 agent 在收到 using-superpowers 的指令后，也同时收到了 spec-anchor 的链式要求。

**5.2 spec-anchor-prelude description 优化**

当前：
```yaml
description: "Use BEFORE invoking any superpowers process skill (brainstorming,
  writing-plans, executing-plans, systematic-debugging) in a project that contains
  anchor.yaml or .specanchor/..."
```

优化为：
```yaml
description: >-
  MUST invoke BEFORE any superpowers process skill (brainstorming, writing-plans,
  executing-plans) in SpecAnchor projects — loads Spec Landscape first.
```

更短，MUST 前置。

**5.3 完成后的反向链式**

在 SKILL.md 的 Workflow Selection 部分，添加完成链式触发：

```markdown
## Post-Coding Chain

编码完成后的 chain-back 步骤：
1. 运行 `specanchor_check` 进行对齐检测
2. 如果有新发现 → 写入 `.specanchor/findings/`
3. 评估是否需要 Sediment Proposal
```

这形成了一个闭环：
```
SessionStart hook → spec-anchor (boot) → superpowers (brainstorm/plan/execute)
→ spec-anchor (alignment check) → finding/sediment
```

---

## 目录结构变更

### 从独立 skill 到 plugin + skill

当前结构（`~/.claude/skills/spec-anchor/`）：
```
spec-anchor/
├── SKILL.md
├── scripts/
├── references/
└── ...
```

目标结构（作为 Claude Code plugin）：
```
spec-anchor/
├── package.json              # [新建] 插件元数据
├── hooks/
│   ├── hooks.json            # [新建] SessionStart hook 定义
│   ├── run-hook.cmd          # [新建] 跨平台入口
│   └── session-start         # [新建] 条件注入脚本
├── skills/
│   └── spec-anchor/
│       └── SKILL.md          # [移动] 从根目录移入 skills/ 子目录
├── scripts/                  # [保持] 原有脚本不变
├── references/               # [保持] 原有协议文件不变
└── ...
```

**向后兼容注意**：
- 如果用户仍将 spec-anchor 放在 `~/.claude/skills/` 下（非插件安装），skill 仍能通过自动发现工作，只是没有 SessionStart hook
- boot-install.sh 继续提供 CLAUDE.md 注入作为 fallback

---

## 分发与安装

### 插件安装方式

```bash
# 从 git repo 安装
claude plugin add --git https://github.com/<org>/spec-anchor

# 或从 marketplace（如果上架）
claude plugin add spec-anchor@<marketplace>
```

### 向后兼容：非插件安装

对于不使用 Claude Code 插件系统的环境：
- `specanchor-boot-install.sh` 继续将触发块注入 CLAUDE.md / AGENTS.md / GEMINI.md
- 这是 fallback 机制，触发效果弱于 SessionStart hook，但仍有效

---

## 验证标准

| # | 验证项 | 方法 |
|---|--------|------|
| 1 | SessionStart hook 在 SpecAnchor 项目中注入 context | 新建会话 → 检查系统提示是否包含 "SpecAnchor Project Detected" |
| 2 | SessionStart hook 在非 SpecAnchor 项目中静默 | 在无 anchor.yaml 的目录新建会话 → 无注入 |
| 3 | description 重写后在技能列表中显示命令式短文本 | 检查 `/skills` 输出 |
| 4 | 防跳过表在注入内容中可见 | 检查系统提示中的 additionalContext |
| 5 | superpowers 技能调用前 agent 先调用 spec-anchor | 在 SpecAnchor 项目中让 agent brainstorm → 观察是否先加载 spec |
| 6 | 编码完成后 agent 触发 alignment check | 完成编码任务后观察 agent 是否运行 specanchor_check |
| 7 | 非插件安装仍通过 boot-install fallback 工作 | 在 `~/.claude/skills/` 安装方式下测试触发 |

---

## 风险与缓解

| 风险 | 严重度 | 缓解 |
|------|--------|------|
| superpowers 和 spec-anchor 的 SessionStart hook 冲突 | 中 | 两个 hook 独立运行、输出不同的 additionalContext；Claude Code 合并多个 hook 的 context |
| `<IMPORTANT>` 标签优先级不如 `<EXTREMELY_IMPORTANT>` | 低 | spec-anchor 是项目级 context，不需要与 superpowers 元技能竞争优先级；两者互补不冲突 |
| SKILL.md 移入 `skills/` 子目录后路径引用断裂 | 高 | 所有 `references/` 路径使用相对路径，移动后需验证；脚本通过 `$SA_SKILL_DIR` 定位 |
| 插件化后旧 skill 安装与新 plugin 安装冲突 | 中 | 文档中明确迁移步骤：先 `rm -rf ~/.claude/skills/spec-anchor`，再 `claude plugin add` |
| description 过短丢失必要触发词 | 低 | SessionStart hook 已覆盖项目级触发；description 只需覆盖 agent 在技能列表中的判断 |

---

## 实现顺序

1. **创建 hooks 目录和脚本**（session-start, run-hook.cmd, hooks.json）
2. **创建 package.json**
3. **重写 SKILL.md description**（命令式短 description + Hard Gate 区块）
4. **优化 spec-anchor-prelude description**
5. **在 SKILL.md 中添加 Post-Coding Chain 区块**
6. **调整目录结构**（SKILL.md 移入 skills/ 子目录）
7. **更新 scripts 中的路径引用**
8. **端到端测试**（7 项验证标准）
9. **更新文档**（README, CONTRIBUTING, CHANGELOG）
