---
specanchor:
  level: module
  module_name: "协议层"
  module_path: "references/"
  summary: "协议声明层：命令定义、Spec 模板、Schema 系统、核心协议"
  version: "1.4.0"
  owner: "maintainers"
  author: "maintainers"
  reviewers: []
  created: "2026-04-02"
  updated: "2026-05-25"
  last_synced: "2026-05-25"
  last_synced_sha: "c198ade"
  last_change: "agents/*.md boot-activation upgraded with boot-install.sh recipe + idempotent marker-block template; init.md step 13 rewritten to call boot-install"
  status: active
  depends_on: []
---

# Module Spec: references/ (协议层)

## 1. 职责

SpecAnchor 的协议声明层，定义所有命令的语义、Spec 模板、Schema 系统和核心协议。纯声明式内容，不含可执行代码。提供 Agent 按需读取的上下文文件，驱动 SKILL.md 的路由和行为。

## 2. 业务规则

- 所有命令定义文件独立自包含：Agent 仅需读取单个 `commands/<cmd>.md` 即可执行
- Schema 每个目录必须包含 `schema.yaml` + `template.md` 两个文件
- 模板文件中使用 `<placeholder>` 标记占位符，不使用 Jinja/Handlebars 等模板语法
- Boot 输出的 `Available Commands:` 是默认命令路由真源；`commands-quickref.md` 必须与 `commands/` 目录保持同步，但仅作 boot 不可用时的 fallback
- Global Spec 模板中各类型合计 ≤ 200 行的硬约束在模板文件内声明

## 3. 公开接口

### 3.1 命令定义（commands/）

| 文件 | 命令 | 模式限制 |
|------|------|----------|
| `init.md` | `specanchor_init` | 均可 |
| `global.md` | `specanchor_global` | full |
| `module.md` | `specanchor_module` | full |
| `infer.md` | `specanchor_infer` | full |
| `task.md` | `specanchor_task` | full |
| `load.md` | `specanchor_load` | 均可 |
| `status.md` | `specanchor_status` | 均可 |
| `check.md` | `specanchor_check` | 均可 |
| `index.md` | `specanchor_index` | full |
| `import.md` | `specanchor_import` | 均可 |
| `handoff.md` | `specanchor_handoff` | 均可 |
| `codemap.md` | `specanchor_codemap` | full (draft/deferred, time-gated ≥ 2026-06-15) |

### 3.2 Schema 系统（schemas/）

| Schema | 哲学 | 用途 |
|--------|------|------|
| `sdd-riper-one` | strict | 默认 — 规范驱动开发 |
| `bug-fix` | strict | Bug 修复快速流程 |
| `refactor` | strict | 重构任务 |
| `research` | strict | 调研任务 |
| `simple` | fluid | 简单变更 |
| `openspec-compat` | fluid | OpenSpec 兼容 |
| `handoff` | fluid | 跨任务/跨版本 portfolio handoff |

### 3.3 模板文件

| 文件 | 用途 |
|------|------|
| `global-spec-template.md` | Global Spec 各类型的模板 |
| `module-spec-template.md` | Module Spec 通用模板 |
| `task-spec-template.md` | (DEPRECATED) 旧版 Task Spec 模板，已被 Schema 系统取代 |

### 3.4 协议文件

| 文件 | 用途 |
|------|------|
| `specanchor-protocol.md` | 核心协议（启动检查、加载规则、Schema 发现、管理协议） |
| `external-sources-protocol.md` | 外部来源治理协议（sources 配置、frontmatter 注入、腐化检测） |
| `commands-quickref.md` | 意图映射快速参考（boot 不可用时的自然语言 → 核心命令路由 fallback） |
| `script-contract.md` | 脚本清单、调用契约与输出边界 |
| `assembly-trace.md` | Assembly Trace 的格式与刷新时机 |
| `workflow-gates.md` | `⚡/📋` 选择与严格门禁规则 |
| `integrations/*.md` | 与 SDD-RIPER-ONE / superpowers 的集成说明 |
| `agents/agent-contract.md` | Agent 标准工作循环（7 步：boot → resolve → workflow → execute → check → sediment → archive） |
| `agents/{claude-code,codex,cursor,gemini}.md` | 各 Agent 工具的入口适配说明 + Boot Activation 模板 |
| `concepts/*.md` | 可被 schema / template 引用的稳定概念说明 |
| `skills/*.md` | 可外置安装或桥接其他 workflow 的 skill 草稿 |

## 4. 内部状态

无运行时状态。所有内容为静态 Markdown/YAML 文件，由 Agent 按需读取。

## 5. 模块约定

- 命令定义结构统一：参数 → 执行步骤 → 输出格式
- Schema 的 `schema.yaml` 必须包含 `name`、`version`、`philosophy`、`artifacts`、`template` 字段
- `match.when` 数组用于 Agent 的语义推荐，非精确匹配

## 6. 约束

- 文件全部为 Markdown 或 YAML，不含可执行代码
- `task-spec-template.md` 已标记 DEPRECATED，不应被新代码引用
- SDD-RIPER-ONE Task Spec 的 phase 真源是 body marker：`> Current RIPER Phase: <PHASE>`；章节推断只用于 legacy fallback

## 7. 代码结构

| 路径 | 文件数 | 职责 |
|------|--------|------|
| `commands/` | 12 个 .md | 各命令的详细定义（含 `handoff.md`；`codemap.md` 为 draft/deferred） |
| `schemas/` | 7 个子目录（各含 2 文件） | Schema 系统（含 `handoff` schema；sdd-riper-one v2 起含 `context_control` 节，声明 6 区段协议事实） |
| 根级 .md | 10 个 | 协议、模板、快速参考 |
| `integrations/` | 3 个 .md | 外部工作流集成说明 |
| `agents/` | 5 个 .md | Agent 工作循环契约 + 各 Agent 入口适配 + Boot Activation 模板 |
| `concepts/` | 1 个 .md | Capability Drift 等稳定概念说明 |
| `skills/` | 1 个 skill | 外部 workflow 桥接 skill 草稿 |

## 8. 已知问题

- `task-spec-template.md` 虽标记 DEPRECATED 但未从 git 移除，可能误导 Agent 引用
- Schema 的 `match.when` 语义匹配依赖 Agent 理解力，无回退到关键词匹配的降级机制
