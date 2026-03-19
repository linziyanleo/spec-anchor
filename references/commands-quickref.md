# SpecAnchor 意图映射

用户用自然语言描述意图时，根据下表匹配到对应命令，然后读取该命令的详细定义文件执行。

所有详细定义路径相对于 Skill 根目录（即主 SKILL.md 所在目录）。

SpecAnchor 不使用 CLI 风格的命令前缀，所有交互通过自然语言完成。

## 意图映射表

| 用户意图                                          | 执行动作            | 详细定义                          |
| ------------------------------------------------- | ------------------- | --------------------------------- |
| 初始化规范 / 开始用 SpecAnchor / 创建 .specanchor | `specanchor_init`   | `references/commands/init.md`     |
| 生成编码规范 / 推断架构约定 / 全局规范            | `specanchor_global` | `references/commands/global.md`   |
| 初始化项目信息 / 设置项目信息                     | `specanchor_global` | `references/commands/global.md`（project-setup 类型） |
| 创建模块规范 / 更新模块 Spec / 同步模块规范       | `specanchor_module` | `references/commands/module.md`   |
| 从代码推断模块规范 / 自动生成 Spec 草稿           | `specanchor_infer`  | `references/commands/infer.md`    |
| 创建任务 / 新建任务 Spec / 开始新任务             | `specanchor_task`   | `references/commands/task.md`     |
| 加载规范 / 读取 Spec 到上下文                     | `specanchor_load`   | `references/commands/load.md`     |
| 查看规范状态 / 覆盖率 / 哪些 Spec 加载了          | `specanchor_status` | `references/commands/status.md`   |
| 检测 Spec-代码对齐 / 检查过期 / 覆盖率报告        | `specanchor_check`  | `references/commands/check.md`    |
| 更新模块索引 / 刷新 module-index                  | `specanchor_index`  | `references/commands/index.md`    |
| 导入 OpenSpec / 兼容 OpenSpec / 从 OpenSpec 迁移  | `specanchor_import` | `references/commands/import.md`   |

### 工作流命令

工作流命令由 SpecAnchor 的 workflow 扩展提供。当用户提及以下意图时，读取 `extensions/workflow/SKILL.md` 并按其指引执行。

| 用户意图                                           | 扩展命令               |
| -------------------------------------------------- | ---------------------- |
| 提交代码 / push / commit                           | `workflow_commit_push` |
| 提交代码评审 / CR / 代码评审                       | `workflow_submit_cr`   |
| 启动项目 / start / dev                             | `workflow_start_dev`   |
| 停止项目 / stop                                    | `workflow_stop_dev`    |

## 按场景分组

### 项目初始化

"帮我初始化规范管理" / "初始化 SpecAnchor" → `specanchor_init`
"初始化项目信息" → `specanchor_global`（project-setup 类型）

### 全局规范

"帮我生成编码规范" / "从代码推断架构约定" → `specanchor_global`

### 模块规范

"帮我创建 auth 模块的规范" / "更新用户认证模块的 Spec" → `specanchor_module`
"帮我从代码推断模块规范" / "先自动生成草稿" → `specanchor_infer`

### 任务管理

"创建任务：登录页增加验证码" / "开始新任务" → `specanchor_task`
"加载 auth 模块的规范" → `specanchor_load`

### 状态与检测

"看看规范状态" / "覆盖率怎么样" → `specanchor_status`
"检查 Spec 和代码是否对齐" / "模块规范是否过期" → `specanchor_check`
"更新模块索引" → `specanchor_index`

### 外部导入

"导入 OpenSpec 配置" / "兼容 OpenSpec" / "从 OpenSpec 迁移" → `specanchor_import`

### 工作流

"提交代码" / "启动项目" / "代码评审" / "停止项目" → 读取 `extensions/workflow/SKILL.md`

## 推荐流程

### 首次使用

1. "帮我初始化 SpecAnchor" → `specanchor_init`
2. "初始化项目信息" → `specanchor_global`（project-setup 类型）
3. "帮我生成编码规范" → `specanchor_global`（coding-standards 类型）
4. "帮我生成架构约定" → `specanchor_global`（architecture 类型）
5. 触碰模块时："帮我创建 auth 模块的规范" → `specanchor_module`

### 日常开发

1. "创建任务：XX功能" → `specanchor_task`
2. 按 Task Spec 开发
3. "提交代码" → workflow 扩展
4. "提交代码评审" → workflow 扩展
5. "检查 Spec 和代码对齐" → `specanchor_check`
