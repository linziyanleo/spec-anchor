# SpecAnchor

> Spec 是锚，代码是船。锚定住了，船才不会漂。

SpecAnchor 是一个 **Skill**，为 AI 辅助开发提供三级 Spec（规范）管理体系。它不生成代码，而是在 AI 生成代码之前，确保 AI 已经读取并遵循团队的编码规范、模块契约和任务计划。

---

## 它解决什么问题


| 问题              | SpecAnchor 的回答                |
| --------------- | ----------------------------- |
| AI 生成的代码不符合团队规范 | Global Spec 提供"宪法级"约束，AI 必须遵守 |
| 不同开发者改同一模块风格不统一 | Module Spec 定义模块的接口契约和设计约定    |
| 代码改了但"为什么改"丢失了  | Task Spec 记录每次变更的意图和决策        |
| Spec 和代码不一致（腐化） | `SA CHECK` 检测 Spec-代码对齐度      |


## 三级 Spec 体系

```
L1  Global Spec    全局规范    编码标准、架构约定、设计系统    季度级变更    .specanchor/global/
L2  Module Spec    模块契约    接口、业务规则、代码结构       迭代级变更    .specanchor/modules/
L3  Task Spec      任务计划    单次变更的目标、计划、执行日志   每任务        .specanchor/tasks/
```

---

## 目录结构

### Skill 本体（本仓库）

```
SpecAnchor/
├── SKILL.md                           ← Skill 入口
├── references/
│   ├── specanchor-protocol.md         ← 核心协议：命令定义、加载规则、集成协议
│   ├── global-spec-template.md        ← Global Spec 模板（4 种类型）
│   ├── module-spec-template.md        ← Module Spec 模板
│   ├── task-spec-template.md          ← Task Spec 模板（SDD-RIPER-ONE 默认 + 简化两种）
│   └── commands-quickref.md           ← 命令速查表
├── scripts/
│   └── specanchor-check.sh            ← Spec-Commit 对齐检测脚本
└── mydocs/                            ← 设计文档（不入库）
    └── idea.md                        ← 原始设计研讨稿
```

### 安装后在目标项目中的结构

```
your-project/
├── .specanchor/                       ← SA INIT 创建
│   ├── config.yaml                    ← 配置（扫描路径、覆盖率阈值等）
│   ├── global/                        ← L1: Global Spec（合计 ≤ 200 行）
│   │   ├── coding-standards.spec.md
│   │   └── architecture.spec.md
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

在 AI 对话中引用 SpecAnchor Skill，然后输入：

```
SA INIT
```

这会在项目根目录创建 `.specanchor/` 目录结构和默认 `config.yaml`。

### 第二步：生成 Global Spec

```
SA GLOBAL coding-standards
SA GLOBAL architecture
```

AI 会扫描项目代码（`package.json`、`tsconfig.json`、目录结构、代码模式等），推断编码规范和架构约定，生成 Global Spec 草稿。

**重要约束**：所有 Global Spec 合计不超过 200 行。这是 AI 上下文的 token 预算硬约束。

### 第三步：按需生成 Module Spec

当你要修改某个模块时，先为它创建 Module Spec：

```
SA MODULE src/modules/auth
```

或者从代码逆向推断一份草稿：

```
SA INFER src/modules/auth
```

Module Spec 会自动存放在 `.specanchor/modules/` 目录下，并更新 `module-index.md` 索引。

### 第四步：创建任务并开发

```
SA TASK 登录页增加验证码
```

AI 会自动加载相关的 Global Spec 和 Module Spec，然后创建 Task Spec。默认使用 SDD-RIPER-ONE 模板，进入 RIPER 流程（Research → Plan → Execute → Review）。

### 第五步：检测 Spec-代码对齐

```bash
# Task 级：PR 改动文件 vs Spec 计划的文件
scripts/specanchor-check.sh task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md --base=main

# Module 级：所有 Module Spec 的新鲜度
scripts/specanchor-check.sh module --all

# Global 级：Spec 覆盖率报告
scripts/specanchor-check.sh global
```

也可以在 AI 对话中直接输入：

```
SA CHECK task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md
SA CHECK module --all
SA CHECK global
```

---

## 不同角色的使用建议

### 团队工程师

工程师是 SpecAnchor 体系的**全权参与者**。

**日常工作流**：

```
1. 拿到需求
   ↓
2. SA TASK <任务名>                        创建 Task Spec
   ↓
3. （AI 自动加载 Global + Module Spec）
   ↓
4. 按 Task Spec 开发（默认走 SDD-RIPER-ONE 的 RIPER 流程）
   ↓
5. 开发完成，检查 Module Spec 是否需要更新
   ↓
6. SA CHECK task <spec-file>              确认 Spec-代码对齐
   ↓
7. 提交 PR（Task Spec + Module Spec 变更 + 代码变更 一起提交）
```

**额外职责**：

- 维护 Global Spec（建议 Peer Review 后合入）
- Review 外包提交的 Module Spec 变更
- 定期运行 `SA CHECK module --all` 检查 Spec 新鲜度
- 重大重构前先更新相关 Module Spec

**推荐命令频率**：


| 命令                | 频率                   |
| ----------------- | -------------------- |
| `SA TASK`         | 每个任务                 |
| `SA MODULE`       | 触碰新模块时 / Sprint 结束同步 |
| `SA GLOBAL`       | 季度级                  |
| `SA CHECK global` | 每个 Sprint 结束         |


### 外部协作者

协作者是 SpecAnchor 体系的**最大受益者**——Global Spec + Module Spec 已经定义好了"怎么写代码"，AI 在这些约束下生成的代码天然符合团队规范。

**日常工作流**：

```
1. 工程师分配任务 + 指向相关 Module Spec
   ↓
2. SA TASK <任务名>                        创建 Task Spec
   ↓
3. （AI 自动加载 Global + Module Spec → 代码生成受约束）
   ↓
4. 按 Task Spec 开发
   ↓
5. 如果发现 Module Spec 需要更新 → 在 PR 中一起提交变更
   ↓
6. 提交 PR（工程师 Review）
```

**权限边界**：


| 操作                | 允许？         |
| ----------------- | ----------- |
| 读取 Global Spec    | ✅           |
| 修改 Global Spec    | ❌           |
| 创建/修改 Module Spec | 需工程师 Review |
| 创建/执行 Task Spec   | ✅           |
| 运行 `SA CHECK`     | ✅           |


**关键提示**：外包拿到任务后，第一件事是确认相关模块是否有 Module Spec。如果没有，先请工程师创建，或自己运行 `SA INFER <path>` 生成草稿后请工程师确认。

---

## 存量项目冷启动方案

### Phase 0：初始化 + Global Spec（Day 1-2）

```bash
# 1. 安装 Skill（根据使用的 AI 工具选择安装方式，参考"安装"章节）

# 2. 在 AI 对话中初始化
SA INIT scan=true

# 3. 生成 Global Spec（AI 扫描项目推断）
SA GLOBAL coding-standards
SA GLOBAL architecture

# 4. 人工 Review Global Spec → 调整 → 提交
git add .specanchor/
git commit -m "spec: 初始化 SpecAnchor，生成 Global Spec"
```

**产出**：`.specanchor/` 目录结构 + 2-4 个 Global Spec 文件。

**耗时**：AI 生成 10 分钟，人工 Review 1-2 小时。

### Phase 1：渐进式 Module Spec（持续进行）

**"触碰即文档化"原则**——不主动为所有模块生成 Spec，在以下时机自然触发：


| 触发条件     | 动作                            |
| -------- | ----------------------------- |
| 新建模块     | 创建 Module Spec 作为模块的第一个文件     |
| 首次修改现有模块 | `SA INFER <path>` 生成草稿 → 人工确认 |
| 重大重构     | 强制先更新/创建 Module Spec          |
| 新人接手模块   | 创建 Module Spec 作为知识传递         |


### Phase 2：Task Spec 融入日常（立即）

从 Phase 0 完成的那一刻起，所有新任务都可以使用 `SA TASK`：

```
SA TASK 修复订单列表分页 bug
```

即使相关模块还没有 Module Spec，Task Spec 仍然有效——它至少会加载 Global Spec 来约束代码生成。

### 冷启动里程碑


| 时间     | 预期覆盖率                            | 重点          |
| ------ | -------------------------------- | ----------- |
| 第 1 周  | Global Spec 100%, Module Spec 0% | 建立基线        |
| 第 1 个月 | Module Spec 10-20%               | 覆盖高频修改的核心模块 |
| 第 3 个月 | Module Spec 40-60%               | 高频改动模块自然覆盖  |
| 第 6 个月 | Module Spec 70%+                 | 接近"健康水位"    |


可以通过 `SA CHECK global` 随时查看当前覆盖率。

---

## 命令速查

### 初始化

```
SA INIT                                  初始化 .specanchor/ 目录
SA INIT scan=true                        初始化并自动生成 Global Spec 草稿
```

### Spec 管理

```
SA GLOBAL coding-standards               创建/更新编码规范
SA GLOBAL architecture                   创建/更新架构约定
SA MODULE src/modules/auth               创建/更新模块规范（存放到 .specanchor/modules/）
SA INFER src/modules/auth                从代码逆向推断模块规范
SA TASK 登录页增加验证码                   创建任务规范（默认 SDD-RIPER-ONE 模板）
```

### 查看 & 检测

```
SA LOAD .specanchor/modules/src-modules-auth.spec.md  手动加载 Spec
SA STATUS                                查看加载状态和覆盖率
SA INDEX                                 更新 Module Spec 索引
SA CHECK task <spec-file>                Task 级对齐检测
SA CHECK module --all                    Module 级新鲜度检测
SA CHECK global                          全局覆盖率报告
```

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
  version: "0.2.0"
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
    thresholds:
      module_spec_coverage: 60         # 目标覆盖率 %
      stale_days: 30                   # 超过 N 天未同步标记过期
```

---

## 设计原则

1. **Spec 是因，代码是果**——先写 Spec 再写代码（正向流）；代码变了检查 Spec 是否过期（逆向流）
2. **不追求 100% 覆盖**——让最重要的模块先有 Spec，渐进式覆盖
3. **不绑定写作工具**——SpecAnchor 只管"组织"（放哪、格式、状态），不管"写作"（默认 SDD-RIPER-ONE，可替换）
4. **Global Spec ≤ 200 行**——这是 AI 上下文的物理约束，强制精简
5. **Module Spec 集中管理**——存放在 `.specanchor/modules/`，通过 `module-index.md` 索引到真实模块路径
6. **全量更新 + git 管理版本**——Module Spec 更新时全文重写，通过 `git diff` 和 Code Review 管理变更
7. **平台无关**——纯文本 Skill，支持 Cursor、Claude Code、Cline 及任何可读取文件的 AI 工具

---

## License

MIT