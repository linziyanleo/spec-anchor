---
name: spec-anchor
description: 三级 Spec 体系（Global/Module/Task），在 AI 生成代码前自动加载编码规范与模块契约，保障团队一致性。只要项目中有 .specanchor/ 目录，就应该使用此 Skill——无论用户是在讨论编码规范、模块设计、任务规划，还是在开始开发任务、提交代码、代码评审。即使用户只是简单地说"开始做 XX 功能"或"改一下 XX"，也应该触发此 Skill 进行工作流选择（⚡/📋）。中英文关键词触发：规范、约定、对齐、覆盖率、spec、SA 前缀命令。
---

# SpecAnchor

Spec 是锚，代码是船。锚定住了，船才不会漂。

SpecAnchor 管理三级 Spec 体系：Global（全局规范）→ Module（模块契约）→ Task（任务执行）。它在 AI 生成代码之前，确保 AI 已经读取并遵循团队的编码规范和模块契约。

内置 SDD-RIPER-ONE 作为默认写作协议，可通过 Schema 系统替换。`references/` 路径相对于 Skill 安装目录，`.specanchor/` 路径相对于用户工作区。

## 启动检查

Skill 激活时立即执行以下检查。这是为了确保 Agent 在回答任何代码问题前已经具备项目规范上下文。

1. 检查 `.specanchor/` 是否存在
   - 不存在 → 报错：`⛔ .specanchor/ 目录不存在。请先说"初始化 SpecAnchor"来创建。`，阻塞后续操作
   - 存在 → 继续
2. 读取 `.specanchor/config.yaml`
3. 读取 `.specanchor/global/` 下所有 Global Spec（合计 ≤ 200 行，这是 token 预算硬约束）
4. 发现可用 Schema（扫描 `.specanchor/schemas/` + `references/schemas/`，详见 `references/specanchor-protocol.md` §1）
5. 报告加载状态（包含 Available Schemas 列表）

## 上下文加载策略

Spec 分层加载是为了在 token 预算内最大化相关上下文。Global Spec 始终加载因为它是"宪法"；Module Spec 按需加载因为它可能很多。

| 层级        | 何时加载       | 加载什么                                       |
| ----------- | -------------- | ---------------------------------------------- |
| Always Load | Skill 激活时   | `config.yaml` + 全部 Global Spec               |
| On-Demand   | 涉及具体模块时 | 从 `.specanchor/modules/` 加载对应 Module Spec |
| On-Demand   | 需要全局视角时 | `.specanchor/project-codemap.md`               |

On-Demand 触发场景：

- 用户提及的文件路径落在某模块目录下（通过 `module-index.md` 匹配）
- 执行 `specanchor_task` / `specanchor_module` 时自动定位关联模块
- RIPER Research 阶段发现相关模块

## 命令

用户可以用自然语言描述意图，也可以用 SA 前缀的精确命令。遇到用户意图时，先查阅 `references/commands-quickref.md` 的意图映射表确定要执行的命令，然后读取对应的命令详细定义文件执行。

| 命令                | 用途                             | 详细定义                        |
| ------------------- | -------------------------------- | ------------------------------- |
| `specanchor_init`   | 初始化 `.specanchor/` 目录和配置 | `references/commands/init.md`   |
| `specanchor_global` | 创建/全量更新 Global Spec        | `references/commands/global.md` |
| `specanchor_module` | 创建/全量更新 Module Spec        | `references/commands/module.md` |
| `specanchor_infer`  | 从代码逆向推断 Module Spec 草稿  | `references/commands/infer.md`  |
| `specanchor_task`   | 创建 Task Spec                   | `references/commands/task.md`   |
| `specanchor_load`   | 手动加载指定 Spec 到上下文       | `references/commands/load.md`   |
| `specanchor_status` | 显示 Spec 加载状态和覆盖率       | `references/commands/status.md` |
| `specanchor_check`  | 运行 Spec-Commit 对齐检测        | `references/commands/check.md`  |
| `specanchor_index`  | 更新 Module Spec 索引            | `references/commands/index.md`  |
| `specanchor_import` | 从外部 SDD 框架导入配置          | `references/commands/import.md` |

工作流命令（提交代码/代码评审/启停服务器）由扩展提供，见下方「扩展」段落。

匹配到命令后，**输出决策检查点**：

- 核心命令 → `🔧 <命令名> — <用途>`
- 扩展命令 → `🔌 <命令名> — <用途>`

## Module Spec 集中管理

Module Spec 存放在 `.specanchor/modules/`，通过 `module-index.md` 索引到真实模块路径。集中管理是为了让 Agent 能快速定位任何模块的规范，而不需要遍历整个项目目录。

- 文件命名：模块路径中 `/` 替换为 `-`，如 `src/modules/auth` → `src-modules-auth.spec.md`
- 索引更新：`specanchor_module` / `specanchor_infer` / `specanchor_status` / `specanchor_index` 执行时自动更新

## 与 SDD-RIPER-ONE 的集成

SpecAnchor 内置 SDD-RIPER-ONE 作为 Task Spec 的默认写作协议。集成的价值在于：RIPER 提供结构化的开发流程，SpecAnchor 在每个阶段注入规范上下文，两者组合确保 AI 生成的代码既有计划性又符合团队规范。

| RIPER 阶段   | SpecAnchor 注入                                                        |
| ------------ | ---------------------------------------------------------------------- |
| Pre-Research | 自动加载 Global Spec + 通过 module-index.md 定位并读取相关 Module Spec |
| Research     | Module Spec 作为现状分析输入                                           |
| Plan         | File Changes 与 Module Spec 的关键文件交叉校验                         |
| Execute      | 代码生成受 Global + Module Spec 约束                                   |
| Review       | 检查 Module Spec 是否需要更新（接口变更/新增依赖）                     |

路径替换：RIPER 默认 `mydocs/specs/` → SpecAnchor 的 `.specanchor/tasks/<module>/`

写作协议可替换：通过 Schema 系统切换（见 `references/specanchor-protocol.md` §4.1）。

## 工作流选择

收到开发需求时，Agent 根据任务描述 + 启动时发现的 Available Schemas，一步选择工作流，**必须输出决策检查点**：

- **简单需求** → 输出 `⚡ 轻量流程 — <原因>`，直接执行，无需创建 Task Spec
  特征：单文件修改、样式调整、单个 bug 修复、不涉及架构变更、预计 < 2 小时
- **复杂需求** → 输出 `📋 <schema_name> — <原因>`，**必须**执行 `specanchor_task` 创建 Task Spec 后才能开展任何面向实现的工作
  特征：新增功能模块、多文件/多模块修改、架构设计、数据流/API 变更、预计 >= 2 小时
  Schema 推荐基于启动时加载的 Available Schemas 的 `match.when` 与任务描述的语义匹配，用户可在此步确认或指定其他 Schema

### 标准流程门禁

输出 `📋 <schema>` 后，进入**门禁状态**直到 Task Spec 创建完成。这个门禁存在是因为：如果不先创建 Task Spec 就开始分析代码或口头讨论方案，Agent 会自然地在对话中"走完" RIPER 流程而从未创建持久化的 Spec 文件——导致 Plan Approved 等门禁从未激活、所有产出不可追溯。

门禁期间应避免：读取源代码进行实现分析、编写代码、在对话中口头执行 RIPER 阶段。读取 Spec/配置文件不受限。

**唯一允许的下一步**：执行 `specanchor_task` 创建 Task Spec。

Task Spec 创建完成后，输出解锁检查点：`🔓 标准流程已激活 — Task Spec: <文件路径>`，然后按 Schema 定义的流程推进。各阶段产出写入 Task Spec 文件而非仅在对话中口头执行，这样才能被追溯和审查。

### 阶段门禁执行规则

写作协议（Schema）中声明了 `gate` 的阶段，Agent 必须**主动向用户请求确认**，不得自行跳过。以 `sdd-riper-one` 的 Plan Approved 门禁为例：

1. 完成 Plan（§4）写入 Task Spec 后，向用户展示 Plan 摘要
2. 明确询问：`⏸️ Plan 已就绪，请确认后回复「Plan Approved」继续执行`
3. **等待用户回复**，收到确认前禁止进入 Execute
4. 收到确认后输出 `▶️ Plan Approved — 进入 Execute 阶段`

此规则适用于所有 `philosophy: strict` 的 Schema 中声明的 gate。`philosophy: fluid` 的 Schema 无此约束。

## 扩展（可选）

SpecAnchor 支持通过扩展按需加载增强功能。

| 扩展     | 用途                                     | 触发时机                 | 入口                              |
| -------- | ---------------------------------------- | ------------------------ | --------------------------------- |
| workflow | 开发工作流（提交/评审/启停服务器）       | 用户提及工作流操作       | `extensions/workflow/SKILL.md`    |

当用户需要工作流能力时，读取对应扩展的 SKILL.md 并按其指引执行。

## 引用文件指引

根据当前任务按需读取，不要一次全部加载：

| 文件                                 | 何时读取                                         |
| ------------------------------------ | ------------------------------------------------ |
| `references/commands-quickref.md`    | 需要匹配用户意图到具体命令时                     |
| `references/commands/<cmd>.md`       | 确定了要执行的命令后，读取该命令的详细定义       |
| `references/specanchor-protocol.md`  | 需要了解启动检查、加载规则、集成协议、管理协议时 |
| `references/external-sources-protocol.md` | config.yaml 中存在 `external_sources` 时    |
| `references/global-spec-template.md` | 执行 `specanchor_global` 时                      |
| `references/module-spec-template.md` | 执行 `specanchor_module` / `specanchor_infer` 时 |
| `references/schemas/<name>/`         | 执行 `specanchor_task` 时，加载对应 Schema 的 `schema.yaml` + `template.md` |
