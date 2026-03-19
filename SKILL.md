---
name: spec-anchor
description:
  三级 Spec 体系（Global/Module/Task），在 AI 生成代码前自动加载编码规范与模块契约，
  保障团队一致性。触发条件：Spec 相关操作（创建/更新/检查/推断规范、SA 前缀命令、
  初始化 SpecAnchor）；含 .specanchor/ 的项目中讨论编码规范、模块边界、任务规划、
  代码风格，或使用工作流命令（"提交代码"、"启动项目"、"代码评审"、"停止项目"）；
  中文关键词："规范"、"约定"、"对齐"、"覆盖率"；在有 .specanchor/ 的项目中启动
  开发任务或询问代码组织方式时也应触发。
---

# SpecAnchor

Spec 是锚，代码是船。锚定住了，船才不会漂。

SpecAnchor 管理三级 Spec 体系：Global（全局规范）→ Module（模块契约）→ Task（任务执行）。它在 AI 生成代码之前，确保 AI 已经读取并遵循团队的编码规范和模块契约。

内置 SDD-RIPER-ONE 作为默认写作协议，可替换。

## 路径约定

本 Skill 引用两类路径，Agent 需要区分它们的解析基准：

| 前缀 | 解析基准 | 示例 |
|------|----------|------|
| `references/`、`extensions/`、`scripts/` | 本 SKILL.md 所在目录（Skill 安装目录） | `references/commands/init.md` → Skill 内的命令定义文件 |
| `.specanchor/`、`src/` 等项目目录 | 用户工作区根目录 | `.specanchor/config.yaml` → 用户项目中的配置文件 |

完整的 Skill 资源文件清单及其加载时机见文末「引用文件指引」。

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

写作协议可替换：替换 `references/task-spec-template.md` 的 SDD 变体即可。

## `.specanchor/` 不存在时

报错并阻塞。提示用户说"初始化 SpecAnchor"。不自动创建目录——初始化是一个有意识的决定，需要用户确认项目配置。

## 需求复杂度评估

不是所有需求都值得创建 Task Spec。收到开发需求时，先评估复杂度再决定流程，**必须输出决策检查点**：

- **简单需求** → 输出 `⚡ 轻量流程 — <原因>`，直接执行，无需创建 Task Spec
  特征：单文件修改、样式调整、单个 bug 修复、不涉及架构变更、预计 < 2 小时
- **复杂需求** → 输出 `📋 标准流程 — <原因>`，先 `specanchor_task` 创建 Task Spec，按 RIPER 流程执行
  特征：新增功能模块、多文件/多模块修改、架构设计、数据流/API 变更、预计 >= 2 小时

## 扩展（可选）

SpecAnchor 支持通过扩展按需加载增强功能。

| 扩展     | 用途                                     | 触发时机                 | 入口                              |
| -------- | ---------------------------------------- | ------------------------ | --------------------------------- |
| workflow | 开发工作流（提交/评审/启停服务器）       | 用户提及工作流操作       | `extensions/workflow/SKILL.md`    |

当用户需要工作流能力时，读取对应扩展的 SKILL.md 并按其指引执行。

## 推荐流程

### 首次使用

1. "帮我初始化 SpecAnchor" → 创建目录结构
2. "初始化项目信息" → 生成项目配置规范（project-setup 类型的 Global Spec）
3. "帮我生成编码规范" → 从代码推断 Global Spec
4. 开发时触碰模块 → "帮我创建这个模块的规范"

### 日常开发

1. 收到开发需求 → 评估复杂度（输出 ⚡ 或 📋 检查点）
2. ⚡ 轻量流程：直接执行，完成后可选"提交代码"
3. 📋 标准流程：
   a. "创建任务：XX功能" → 自动检查 Module Spec 覆盖度（输出 ✅ 或 ⚠️），创建 Task Spec
   b. 按 Task Spec 开发（默认走 RIPER 流程）
   c. "检查 Spec 和代码是否对齐" → 运行对齐检测

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
| `references/task-spec-template.md`   | 执行 `specanchor_task` 时（无 Schema 配置时的 fallback） |
| `references/schemas/<name>/`         | 执行 `specanchor_task` 时，根据 `writing_protocol.schema` 加载对应 Schema |
