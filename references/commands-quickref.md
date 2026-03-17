# SpecAnchor 意图映射

用户用自然语言描述意图时，根据下表匹配到对应命令，然后读取该命令的详细定义文件执行。

SpecAnchor 不使用 CLI 风格的命令前缀，所有交互通过自然语言完成。

## 意图映射表

### SpecAnchor 核心命令

| 用户意图                                          | 执行动作            | 详细定义             |
| ------------------------------------------------- | ------------------- | -------------------- |
| 初始化规范 / 开始用 SpecAnchor / 创建 .specanchor | `specanchor_init`   | `commands/init.md`   |
| 生成编码规范 / 推断架构约定 / 全局规范            | `specanchor_global` | `commands/global.md` |
| 创建模块规范 / 更新模块 Spec / 同步模块规范       | `specanchor_module` | `commands/module.md` |
| 从代码推断模块规范 / 自动生成 Spec 草稿           | `specanchor_infer`  | `commands/infer.md`  |
| 创建任务 / 新建任务 Spec / 开始新任务             | `specanchor_task`   | `commands/task.md`   |
| 加载规范 / 读取 Spec 到上下文                     | `specanchor_load`   | `commands/load.md`   |
| 查看规范状态 / 覆盖率 / 哪些 Spec 加载了          | `specanchor_status` | `commands/status.md` |
| 检测 Spec-代码对齐 / 检查过期 / 覆盖率报告        | `specanchor_check`  | `commands/check.md`  |
| 更新模块索引 / 刷新 module-index                  | `specanchor_index`  | `commands/index.md`  |

### 工作流命令

| 用户意图                                           | 执行动作               | 详细定义                           |
| -------------------------------------------------- | ---------------------- | ---------------------------------- |
| 提交代码评审 / 评审代码 / 提交 CR / 代码评审       | `workflow_submit_cr`   | `commands/workflow_submit_cr.md`   |
| 提交 / 提交代码 / push / 推送代码 / commit         | `workflow_commit_push` | `commands/workflow_commit_push.md` |
| 启动项目 / 运行项目 / start / dev / 启动开发服务器 | `workflow_start_dev`   | `commands/workflow_start_dev.md`   |
| 停止项目 / 停止开发服务器 / stop / 关闭项目        | `workflow_stop_dev`    | `commands/workflow_stop_dev.md`    |

### 项目初始化

| 用户意图                                      | 执行动作            | 详细定义             |
| --------------------------------------------- | ------------------- | -------------------- |
| 初始化项目信息 / 创建 metadata / 设置项目信息 | `specanchor_global` | `commands/global.md` |

## 按场景分组

### SpecAnchor 规范管理

#### 项目初始化

"帮我初始化规范管理" / "初始化 SpecAnchor" → `specanchor_init`

#### 全局规范

"帮我生成编码规范" / "从代码推断架构约定" → `specanchor_global`

#### 模块规范

"帮我创建 auth 模块的规范" / "更新用户认证模块的 Spec" → `specanchor_module`
"帮我从代码推断模块规范" / "先自动生成草稿" → `specanchor_infer`

#### 任务管理

"创建任务：登录页增加验证码" / "开始新任务" → `specanchor_task`
"加载 auth 模块的规范" → `specanchor_load`

#### 状态与检测

"看看规范状态" / "覆盖率怎么样" → `specanchor_status`
"检查 Spec 和代码是否对齐" / "模块规范是否过期" → `specanchor_check`
"更新模块索引" → `specanchor_index`

### 工作流管理

#### 项目配置

"初始化项目信息" / "创建 metadata" / "设置项目信息" → `specanchor_global` (project-setup 类型)

#### 代码管理

"提交" / "提交代码" / "push" / "推送代码" → `workflow_commit_push`
"提交代码评审" / "评审代码" / "CR" / "代码评审" → `workflow_submit_cr`

#### 开发服务器

"启动项目" / "运行项目" / "start" / "dev" → `workflow_start_dev`
"停止项目" / "停止开发服务器" / "stop" → `workflow_stop_dev`

## 推荐流程

### 首次使用

1. "帮我初始化 SpecAnchor" → `specanchor_init`
2. "初始化项目信息" → `specanchor_global` (project-setup 类型)
3. "帮我生成编码规范" → `specanchor_global` (coding-standards 类型)
4. "帮我生成架构约定" → `specanchor_global` (architecture 类型)
5. 触碰模块时："帮我创建 auth 模块的规范" → `specanchor_module`

### 日常开发

1. "创建任务：XX功能" → `specanchor_task`
2. 按 Task Spec 开发
3. "提交代码" → `workflow_commit_push`
4. "提交代码评审" → `workflow_submit_cr`
5. "检查 Spec 和代码对齐" → `specanchor_check`

### 开发服务器管理

1. "启动项目" → `workflow_start_dev`
2. 开发过程...
3. "停止项目" → `workflow_stop_dev`

## 命令执行优先级

当用户输入包含多个命令触发词时，按以下优先级执行：

1. `specanchor_init` - 最高优先级，创建 SpecAnchor 环境
2. `specanchor_global` (project-setup) - 项目配置规范生成
3. `workflow_commit_push` - 代码评审前的前置步骤
4. `workflow_submit_cr` - 依赖 commit_push
5. `workflow_start_dev` - 独立命令
6. `workflow_stop_dev` - 独立命令
7. 其他 SpecAnchor 核心命令 - 按用户意图执行

## 重要区分

### 工作流命令 vs SpecAnchor 命令

**工作流命令**（workflow\_\*）：

- 标准化的工作流操作
- 用途：代码管理、开发服务器管理

**SpecAnchor 命令**（specanchor\_\*）：

- 规范管理流程
- 用途：规范管理、代码开发指导

### 识别流程

```
用户输入
    ↓
检查是否匹配工作流命令触发词
    ↓
[是] → 执行对应工作流命令
    ↓
[否] → 检查是否匹配 SpecAnchor 命令触发词
    ↓
[是] → 执行对应 SpecAnchor 命令
    ↓
[否] → 判断为开发需求 → 执行相应处理
```
