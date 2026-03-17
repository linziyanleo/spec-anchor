---
name: specanchor
description: >-
  Manages three-level Spec hierarchy (Global/Module/Task) for AI-assisted
  development and integrates React AI workflow commands. Auto-loads coding standards 
  and module contracts before code generation to ensure consistent, team-aligned output. 
  Includes workflow commands for project management (init metadata, commit/push, 
  code review, dev server management). Use this skill whenever the user mentions 
  SpecAnchor, spec management, module spec, coding standards, or wants to 
  create/update/check any specification. Also trigger when the user asks to 
  "initialize specs", "create module rules", "check spec freshness", "align code 
  with spec", or uses any SA-prefixed command. Even if the user doesn't explicitly 
  say "spec", trigger when they discuss coding conventions, module contracts, or 
  task planning in a project that has a .specanchor/ directory.
---

# SpecAnchor

Spec 是锚，代码是船。锚定住了，船才不会漂。

SpecAnchor 管理三级 Spec 体系：Global（全局规范）→ Module（模块契约）→ Task（任务执行）。它在 AI 生成代码之前，确保 AI 已经读取并遵循团队的编码规范和模块契约。

内置 SDD-RIPER-ONE 作为默认写作协议，可替换。

## 需求复杂度评估

当用户输入需求时，必须首先进行复杂度评估，以决定使用快速流程还是标准流程：

### 简单需求特征（使用快速流程）

- 单文件修改（如修改一个组件、修改一个函数）
- 简单的样式调整
- 单个 bug 修复
- 简单的配置修改
- 不涉及架构变更
- 不涉及多模块协作
- 预计工作量 < 2 小时

### 复杂需求特征（使用标准流程）

- 新增功能模块
- 涉及多个文件修改
- 需要架构设计
- 涉及数据流变更
- 需要 API 接口设计
- 涉及多模块协作
- 预计工作量 >= 2 小时

### 流程选择策略

- **简单需求**：直接执行相应的 SpecAnchor 命令或工作流命令，无需创建 Task Spec
- **复杂需求**：必须先执行 `specanchor_task` 创建 Task Spec，然后按 RIPER 流程执行

## 启动检查

Skill 激活时立即执行以下检查。这是为了确保 Agent 在回答任何代码问题前已经具备项目规范上下文。

1. 检查 `.specanchor/` 是否存在
   - 不存在 → 报错：`⛔ .specanchor/ 目录不存在。请先说"初始化 SpecAnchor"来创建。`，阻塞后续操作
   - 存在 → 继续
2. 读取 `.specanchor/config.yaml`
3. 读取 `.specanchor/global/` 下所有 Global Spec（合计 ≤ 200 行，这是 token 预算硬约束）
4. 报告加载状态

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

### SpecAnchor 核心命令

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

### 工作流命令

| 命令                   | 用途               | 详细定义                                      |
| ---------------------- | ------------------ | --------------------------------------------- |
| `workflow_commit_push` | 自动提交并推送代码 | `references/commands/workflow_commit_push.md` |
| `workflow_submit_cr`   | 提交代码评审       | `references/commands/workflow_submit_cr.md`   |
| `workflow_start_dev`   | 启动开发服务器     | `references/commands/workflow_start_dev.md`   |
| `workflow_stop_dev`    | 停止开发服务器     | `references/commands/workflow_stop_dev.md`    |

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

写作协议可替换：替换 `references/task-spec-template.md` 的 SDD 变体即可。

## `.specanchor/` 不存在时

报错并阻塞。提示用户说"初始化 SpecAnchor"。不自动创建目录——初始化是一个有意识的决定，需要用户确认项目配置。

## 推荐流程

### 首次使用

1. "帮我初始化 SpecAnchor" → 创建目录结构
2. "初始化项目信息" → 生成项目配置规范（project-setup 类型的 Global Spec）
3. "帮我生成编码规范" → 从代码推断 Global Spec
4. 开发时触碰模块 → "帮我创建这个模块的规范"

### 日常开发

1. "创建任务：XX功能" → 自动加载相关规范，创建 Task Spec
2. 按 Task Spec 开发（默认走 RIPER 流程）
3. "提交代码" → 自动生成 commit message 并推送
4. "提交代码评审" → 创建 CR 并执行质量检查
5. "检查 Spec 和代码是否对齐" → 运行对齐检测

### 开发服务器管理

1. "启动项目" → 启动开发服务器并打开浏览器
2. 开发过程...
3. "停止项目" → 停止开发服务器

## 工作流命令集成

SpecAnchor 集成了 React AI 工作流命令，提供完整的开发流程支持：

### 项目初始化

- 通过 `specanchor_global` (project-setup 类型) 生成项目配置规范
- 从 package.json 自动识别项目信息并整合到 Global Spec
- 支持项目配置的自动推断和用户补充
- 将项目元数据作为规范的一部分进行管理

### 代码管理

- 智能分析代码变更类型
- 自动生成符合规范的 commit message
- 支持代码评审流程的自动化

### 开发服务器

- 自动启动/停止开发服务器
- 智能检测服务器状态和端口
- 支持多项目和多服务器管理

### 质量保证

- 代码评审前自动执行 SpecAnchor 质量检查
- 检查代码规范、架构合规性、测试覆盖率
- 提供详细的质量报告和改进建议

## 引用文件指引

根据当前任务按需读取，不要一次全部加载：

| 文件                                 | 何时读取                                         |
| ------------------------------------ | ------------------------------------------------ |
| `references/commands-quickref.md`    | 需要匹配用户意图到具体命令时                     |
| `references/commands/<cmd>.md`       | 确定了要执行的命令后，读取该命令的详细定义       |
| `references/specanchor-protocol.md`  | 需要了解启动检查、加载规则、集成协议、管理协议时 |
| `references/global-spec-template.md` | 执行 `specanchor_global` 时                      |
| `references/module-spec-template.md` | 执行 `specanchor_module` / `specanchor_infer` 时 |
| `references/task-spec-template.md`   | 执行 `specanchor_task` 时                        |
