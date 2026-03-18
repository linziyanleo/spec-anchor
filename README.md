# SpecAnchor

> Spec 是锚，代码是船。锚定住了，船才不会漂。

SpecAnchor 是一个 **Skill**，为 AI 辅助开发提供三级 Spec（规范）管理体系。它不生成代码，而是在 AI 生成代码之前，确保 AI 已经读取并遵循团队的编码规范、模块契约和任务计划。

---

## 它解决什么问题

| 问题                           | SpecAnchor 的回答                            |
| ------------------------------ | -------------------------------------------- |
| AI 生成的代码不符合团队规范    | Global Spec 提供"宪法级"约束，AI 必须遵守    |
| 不同开发者改同一模块风格不统一 | Module Spec 定义模块的接口契约和设计约定      |
| 代码改了但"为什么改"丢失了     | Task Spec 记录每次变更的意图和决策            |
| Spec 和代码不一致（腐化）      | 对齐检测功能检测 Spec-代码对齐度              |

## 三级 Spec 体系

```
L1  Global Spec    全局规范    编码标准、架构约定、设计系统、项目配置    季度级变更    .specanchor/global/
L2  Module Spec    模块契约    接口、业务规则、代码结构               迭代级变更    .specanchor/modules/
L3  Task Spec      任务计划    单次变更的目标、计划、执行日志           每任务        .specanchor/tasks/
```

---

## 目录结构

### Skill 本体（本仓库）

```
SpecAnchor/
├── SKILL.md                           ← Skill 入口
├── extensions/
│   └── workflow/                      ← 工作流扩展（可选，按需加载）
│       ├── SKILL.md                   ← 扩展入口
│       └── references/commands/       ← 工作流命令定义
├── references/
│   ├── specanchor-protocol.md         ← 核心协议：启动检查、加载规则、集成协议、管理协议
│   ├── commands-quickref.md           ← 自然语言使用指南 + 意图映射表
│   ├── complexity-assessment.md       ← 需求复杂度评估
│   ├── commands/                      ← 各命令详细定义（按需读取）
│   │   ├── init.md                    ← specanchor_init
│   │   ├── global.md                  ← specanchor_global（包含 project-setup 类型）
│   │   ├── module.md                  ← specanchor_module
│   │   ├── infer.md                   ← specanchor_infer
│   │   ├── task.md                    ← specanchor_task
│   │   ├── load.md                    ← specanchor_load
│   │   ├── status.md                  ← specanchor_status
│   │   ├── check.md                   ← specanchor_check
│   │   └── index.md                   ← specanchor_index
│   ├── global-spec-template.md        ← Global Spec 模板（5 种类型，包含 project-setup）
│   ├── module-spec-template.md        ← Module Spec 模板
│   └── task-spec-template.md          ← Task Spec 模板（SDD-RIPER-ONE 默认 + 简化两种）
├── scripts/
│   └── specanchor-check.sh            ← Spec-Commit 对齐检测脚本
└── mydocs/                            ← 设计文档（不入库）
    └── idea.md                        ← 原始设计研讨稿
```

### 安装后在目标项目中的结构

```
your-project/
├── .specanchor/                       ← 初始化时创建
│   ├── config.yaml                    ← 配置（扫描路径、覆盖率阈值等）
│   ├── global/                        ← L1: Global Spec（合计 ≤ 200 行）
│   │   ├── coding-standards.spec.md
│   │   ├── architecture.spec.md
│   │   └── project-setup.spec.md      ← 项目配置规范
│   ├── modules/                       ← L2: Module Spec（集中存放）
│   │   ├── src-modules-auth.spec.md        ← src/modules/auth 的 Spec
│   │   ├── src-modules-order.spec.md       ← src/modules/order 的 Spec
│   │   └── src-components-LoginForm.spec.md ← src/components/LoginForm 的 Spec
│   ├── module-index.md                ← Module Spec 索引（自动生成）
│   ├── tasks/                         ← L3: Task Spec（按模块分目录）
│   │   ├── auth/
│   │   │   └── 2026-03-13_sms-login.spec.md
│   │   └── _cross-module/             ← 跨模块任务
│   ├── archive/                       ← 已完成任务归档
│   └── project-codemap.md             ← 项目全景图
└── src/
    └── modules/
        └── auth/
            ├── auth.service.ts
            └── ...
```

---

## 安装

SpecAnchor 是一个通用 AI Skill，支持多种 AI 编码工具。根据你使用的工具选择安装方式：

### Cursor

```bash
# 方式 1：项目级安装
cp -r /path/to/SpecAnchor/ your-project/.cursor/skills/specanchor/

# 方式 2：symlink（开发时推荐）
ln -s /path/to/SpecAnchor your-project/.cursor/skills/specanchor

# 方式 3：全局安装（所有项目可用）
cp -r /path/to/SpecAnchor/ ~/.cursor/skills/specanchor/
```

### Claude Code

```bash
# 方式 1：项目级安装（推荐）
cp -r /path/to/SpecAnchor/ your-project/.agents/skills/specanchor/

# 方式 2：全局安装
cp -r /path/to/SpecAnchor/ ~/.agents/skills/specanchor/
```

在项目的 `CLAUDE.md` 或 `AGENTS.md` 中添加引用：

```markdown
## Skills

- 使用 SpecAnchor 管理 Spec：参考 `.agents/skills/specanchor/SKILL.md`
```

### Cline

```bash
# 项目级安装
cp -r /path/to/SpecAnchor/ your-project/.cline/skills/specanchor/
```

在 `.clinerules` 中添加引用：

```
在生成代码前，先读取 .cline/skills/specanchor/SKILL.md 中的 Spec 管理规范。
```

### 其他 AI 编码工具

SpecAnchor 是纯文本的 Skill 文件，可以在任何支持读取文件的 AI 编码工具中使用。核心步骤：

1. 将 SpecAnchor 目录复制到项目中的约定位置
2. 在 AI 工具的系统提示或项目配置中引用 `SKILL.md`
3. 确保 AI 工具能读取 `.specanchor/` 目录下的文件

### 安装检测脚本（可选）

```bash
cp /path/to/SpecAnchor/scripts/specanchor-check.sh your-project/scripts/
chmod +x your-project/scripts/specanchor-check.sh
```

---

## 使用流程

### 第一步：初始化

在 AI 对话中引用 SpecAnchor Skill，然后说：

> "帮我初始化 SpecAnchor"

AI 会在项目根目录创建 `.specanchor/` 目录结构和默认 `config.yaml`。

### 第二步：生成项目配置和 Global Spec

> "初始化项目信息"
> "帮我生成编码规范"
> "帮我生成架构约定"

AI 会：

1. 扫描 `package.json` 自动识别项目信息（名称、启动命令、评审人等），生成 `project-setup.spec.md`
2. 扫描项目代码推断编码规范和架构约定，生成对应 Global Spec

**重要约束**：所有 Global Spec 合计不超过 200 行。这是 AI 上下文的 token 预算硬约束。

### 第三步：按需生成 Module Spec

当你要修改某个模块时，先为它创建 Module Spec：

> "帮我创建 auth 模块的规范"

或者从代码逆向推断一份草稿：

> "帮我从代码推断 auth 模块的规范"

Module Spec 会自动存放在 `.specanchor/modules/` 目录下，并更新 `module-index.md` 索引。

### 第四步：创建任务并开发

> "创建任务：登录页增加验证码"

AI 会自动加载相关的 Global Spec 和 Module Spec，然后创建 Task Spec。默认使用 SDD-RIPER-ONE 模板，进入 RIPER 流程（Research → Plan → Execute → Review）。

### 第五步：使用工作流命令

开发过程中可以随时使用工作流命令（由 workflow 扩展提供）：

> "提交代码" → 自动分析变更、生成 commit message、提交推送
> "提交代码评审" → 执行 CR 脚本、展示评审链接
> "启动项目" → 启动开发服务器并打开浏览器
> "停止项目" → 停止开发服务器

### 第六步：检测 Spec-代码对齐

在 AI 对话中直接说：

> "检查一下这个任务的 Spec 和代码是否对齐"
> "看看模块规范是否过期了"
> "全局覆盖率报告"

也可以直接使用检测脚本：

```bash
scripts/specanchor-check.sh task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md --base=main
scripts/specanchor-check.sh module --all
scripts/specanchor-check.sh global
```

---

## 扩展

SpecAnchor 支持通过扩展增强功能。扩展按需加载，不影响核心 Spec 管理的 token 预算。

### Workflow 扩展

提供开发工作流命令：代码提交/推送、代码评审、开发服务器管理。

安装 SpecAnchor 时自动包含，在 `extensions/workflow/` 目录下。当用户提及工作流操作（如"提交代码"、"启动项目"、"代码评审"）时，SpecAnchor 自动加载此扩展。

支持的命令：
- "提交代码" / "push" → 分析变更并自动提交推送
- "提交代码评审" / "CR" → 执行 CR 脚本并展示链接
- "启动项目" / "dev" → 启动开发服务器
- "停止项目" / "stop" → 停止开发服务器

详见 `extensions/workflow/SKILL.md`。

---

## 不同角色的使用建议

### 团队工程师

工程师是 SpecAnchor 体系的**全权参与者**。

**日常工作流**：

```
1. 拿到需求
   ↓
2. "启动项目"                              启动开发服务器（workflow 扩展）
   ↓
3. "创建任务：<任务名>"                     创建 Task Spec
   ↓
4. （AI 自动加载 Global + Module Spec）
   ↓
5. 按 Task Spec 开发（默认走 SDD-RIPER-ONE 的 RIPER 流程）
   ↓
6. 开发完成，检查 Module Spec 是否需要更新
   ↓
7. "提交代码"                              自动 commit + push（workflow 扩展）
   ↓
8. "提交代码评审"                          创建 CR + 质量检查（workflow 扩展）
   ↓
9. "检查 Spec 和代码对齐"                   确认 Spec-代码对齐
   ↓
10. 收到 Review 反馈 → 修改 → 重复 7-9
   ↓
11. "停止项目"                             停止开发服务器（workflow 扩展）
```

**额外职责**：

- 维护 Global Spec（建议 Peer Review 后合入）
- Review 外包提交的 Module Spec 变更
- 定期"检查所有模块规范的新鲜度"
- 重大重构前先更新相关 Module Spec

**推荐频率**：

| 操作                | 频率                         |
| ------------------- | ---------------------------- |
| 创建任务 Spec       | 每个任务                     |
| 创建/更新模块规范   | 触碰新模块时 / Sprint 结束同步 |
| 更新全局规范        | 季度级                       |
| 全局覆盖率报告      | 每个 Sprint 结束             |

### 外部协作者

协作者是 SpecAnchor 体系的**最大受益者**——Global Spec + Module Spec 已经定义好了"怎么写代码"，AI 在这些约束下生成的代码天然符合团队规范。

**日常工作流**：

```
1. 工程师分配任务 + 指向相关 Module Spec
   ↓
2. "启动项目"                              启动开发服务器
   ↓
3. "创建任务：<任务名>"                     创建 Task Spec
   ↓
4. （AI 自动加载 Global + Module Spec → 代码生成受约束）
   ↓
5. 按 Task Spec 开发
   ↓
6. "提交代码"                              自动 commit + push
   ↓
7. "提交代码评审"                          创建 CR
   ↓
8. 如果发现 Module Spec 需要更新 → 在 PR 中一起提交变更
   ↓
9. 提交 PR（工程师 Review）
```

**权限边界**：

| 操作                  | 允许？          |
| --------------------- | --------------- |
| 读取 Global Spec      | ✅              |
| 修改 Global Spec      | ❌              |
| 创建/修改 Module Spec | 需工程师 Review |
| 创建/执行 Task Spec   | ✅              |
| 使用工作流命令        | ✅              |
| 运行对齐检测          | ✅              |

**关键提示**：外包拿到任务后，第一件事是确认相关模块是否有 Module Spec。如果没有，先请工程师创建，或自己说"帮我从代码推断模块规范"生成草稿后请工程师确认。

---

## 存量项目冷启动方案

### Phase 0：初始化 + Global Spec（Day 1-2）

```
1. 安装 Skill（根据使用的 AI 工具选择安装方式，参考"安装"章节）

2. 在 AI 对话中说：
   "帮我初始化 SpecAnchor，并扫描项目"

3. 生成项目配置和 Global Spec：
   "初始化项目信息"
   "帮我生成编码规范"
   "帮我生成架构约定"

4. 人工 Review Global Spec → 调整 → 提交
   git add .specanchor/
   git commit -m "spec: 初始化 SpecAnchor，生成 Global Spec"
```

**产出**：`.specanchor/` 目录结构 + 3-5 个 Global Spec 文件（包含项目配置）。

**耗时**：AI 生成 10 分钟，人工 Review 1-2 小时。

### Phase 1：渐进式 Module Spec（持续进行）

**"触碰即文档化"原则**——不主动为所有模块生成 Spec，在以下时机自然触发：

| 触发条件         | 动作                                     |
| ---------------- | ---------------------------------------- |
| 新建模块         | 创建 Module Spec 作为模块的第一个文件    |
| 首次修改现有模块 | "从代码推断模块规范" 生成草稿 → 人工确认 |
| 重大重构         | 强制先更新/创建 Module Spec              |
| 新人接手模块     | 创建 Module Spec 作为知识传递            |

### Phase 2：Task Spec 融入日常（立即）

从 Phase 0 完成的那一刻起，所有新任务都可以直接说"创建任务：修复订单列表分页 bug"。

即使相关模块还没有 Module Spec，Task Spec 仍然有效——它至少会加载 Global Spec 来约束代码生成。

### 冷启动里程碑

| 时间      | 预期覆盖率                       | 重点                   |
| --------- | -------------------------------- | ---------------------- |
| 第 1 周   | Global Spec 100%, Module Spec 0% | 建立基线               |
| 第 1 个月 | Module Spec 10-20%               | 覆盖高频修改的核心模块 |
| 第 3 个月 | Module Spec 40-60%               | 高频改动模块自然覆盖   |
| 第 6 个月 | Module Spec 70%+                 | 接近"健康水位"         |

可以随时说"全局覆盖率报告"查看当前覆盖率。

---

## 命令速查

你可以用自然语言描述想做的事，Agent 会自动匹配对应操作。完整的意图映射和使用指南见 `references/commands-quickref.md`。

### 初始化

- "帮我初始化规范管理"
- "初始化 SpecAnchor 并扫描项目"
- "初始化项目信息"

### Spec 管理

- "帮我生成编码规范"
- "帮我生成架构约定"
- "帮我创建 auth 模块的规范"
- "从代码推断 auth 模块规范"
- "创建任务：登录页增加验证码"

### 工作流（扩展）

- "启动项目" / "运行项目" / "start" / "dev"
- "停止项目" / "停止开发服务器" / "stop"
- "提交代码" / "提交" / "push" / "commit"
- "提交代码评审" / "评审代码" / "CR"

### 查看 & 检测

- "加载 auth 模块的规范"
- "看看规范状态"
- "更新模块索引"
- "检查 Spec 和代码对齐"
- "模块规范是否过期"
- "全局覆盖率报告"

---

## 与 SDD-RIPER-ONE 的关系

```
SpecAnchor  = 图书馆（管理 Spec 的存放、索引、状态）
SDD-RIPER-ONE = 作家（按 RIPER 流程创作 Task Spec）
```

- **SpecAnchor 不依赖 SDD-RIPER-ONE**：可以独立使用，Task Spec 使用简化模板
- **SDD-RIPER-ONE 不依赖 SpecAnchor**：可以独立管理 Task Spec
- **两者结合是最佳实践**：SpecAnchor 提供 Global + Module Spec 上下文，SDD-RIPER-ONE 在这个上下文约束下执行 RIPER 流程
- **默认内置**：SpecAnchor 内置 SDD-RIPER-ONE 模板作为默认写作协议，开箱即用

同时使用时，SpecAnchor 会在 RIPER 各阶段自动注入行为（加载 Spec、校验一致性、检查是否需要更新 Module Spec）。

---

## 检测脚本

`scripts/specanchor-check.sh` 提供三个级别的 Spec-代码对齐检测，输出类似 `git status` 的终端样式：

```bash
# Task 级
./scripts/specanchor-check.sh task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md

# 输出示例：
# SpecAnchor Task Check
#   spec: .specanchor/tasks/auth/2026-03-13_sms-login.spec.md
#   branch: feat/sms-login → main
#
# Planned files:
#   ✓ src/modules/auth/auth.service.ts
#   ✗ src/components/LoginForm/LoginForm.tsx       (not in commit)
#
# Plan coverage: 1/2 (50%)
```

依赖：bash 4.0+、git。无需 Python/Node.js。

---

## 配置

`.specanchor/config.yaml` 控制 SpecAnchor 的行为：

```yaml
specanchor:
  version: "0.3.0"
  project_name: "your-project"

  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    module_index: ".specanchor/module-index.md"
    project_codemap: ".specanchor/project-codemap.md"

  coverage:
    scan_paths:                        # Module Spec 覆盖率扫描范围
      - "src/modules/**"
      - "src/components/**"
    ignore_paths:                      # 排除路径
      - "src/components/ui/**"
      - "src/**/*.test.*"

  check:                               # 对齐检测阈值
    stale_days: 14                     # Spec 同步后超过 N 天且有新提交 → STALE
    outdated_days: 30                  # Spec 同步后超过 N 天且有新提交 → OUTDATED
    warn_recent_commits_days: 14       # 无 Spec 的模块在最近 N 天有提交 → 警告
    task_base_branch: "main"           # 检测 task 对齐时的默认基准分支

  sync:
    auto_check_on_mr: true
    sprint_sync_reminder: true
```

### check 配置说明

| 字段                      | 默认值 | 说明                                                                      |
| ------------------------- | ------ | ------------------------------------------------------------------------- |
| `stale_days`              | 14     | Module Spec 上次同步后超过此天数，且模块代码有新提交 → STALE              |
| `outdated_days`           | 30     | Module Spec 上次同步后超过此天数，且模块代码有新提交 → OUTDATED           |
| `warn_recent_commits_days`| 14     | 无 Spec 覆盖的模块在最近此天数内有代码提交 → 发出警告                     |
| `task_base_branch`        | main   | 检测 task 对齐时的默认 git 基准分支，命令行 `--base=` 可覆盖              |

所有阈值均可在 `config.yaml` 中修改，脚本和 Agent 会自动读取。命令行参数（如 `--base=develop`）优先于配置文件。

---

## 设计原则

1. **Spec 是因，代码是果**——先写 Spec 再写代码（正向流）；代码变了检查 Spec 是否过期（逆向流）
2. **不追求 100% 覆盖**——让最重要的模块先有 Spec，渐进式覆盖
3. **不绑定写作工具**——SpecAnchor 只管"组织"（放哪、格式、状态），不管"写作"（默认 SDD-RIPER-ONE，可替换）
4. **Global Spec ≤ 200 行**——这是 AI 上下文的物理约束，强制精简
5. **Module Spec 集中管理**——存放在 `.specanchor/modules/`，通过 `module-index.md` 索引到真实模块路径
6. **全量更新 + git 管理版本**——Module Spec 更新时全文重写，通过 `git diff` 和 Code Review 管理变更
7. **平台无关**——纯文本 Skill，支持 Cursor、Claude Code、Cline 及任何可读取文件的 AI 工具
8. **扩展式增强**——非核心功能通过 Extension 按需加载，不增加核心 Skill 的 token 预算

---

## 流程图

Skill 调用全链路流程图见 [FLOWCHART.md](FLOWCHART.md)，包含 Mermaid 图：

1. Skill 启动与加载链路
2. 用户意图识别与命令分发
3. 首次使用场景链路
4. 日常开发任务链路
5. 文件读取层级（上下文管理）
6. 全景架构图

## License

MIT
