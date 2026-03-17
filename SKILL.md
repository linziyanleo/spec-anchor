---
name: specanchor
description: >-
  Manages three-level Spec hierarchy (Global/Module/Task) for AI-assisted
  development. Auto-loads coding standards and module contracts before code
  generation. Use when creating specs, updating module contracts, starting
  tasks with "SA" prefix commands, or when the user mentions SpecAnchor,
  spec management, module spec, or coding standards.
---

# SpecAnchor Skill

## 核心定位

- **SpecAnchor = Spec 的组织管理工具**（图书馆），不是写作工具（作家）
- 三级 Spec 体系：Global（全局规范）→ Module（模块契约）→ Task（任务执行）
- 内置 SDD-RIPER-ONE 作为默认写作协议，可替换为其他协议
- 三条底线：
  1. **先读 Spec 再写代码**：生成/修改代码前必须读取相关 Global + Module Spec
  2. **Spec 覆盖优先**：优先修改有 Spec 覆盖的模块；无 Spec 模块提醒用户
  3. **变更同步**：Module Spec 的接口/依赖发生变化时，标记 Spec 需更新

## 启动检查（Skill 激活时自动执行）

1. 检查 `.specanchor/` 目录是否存在
   - **不存在** → 报错：`⛔ .specanchor/ 目录不存在。请先运行 SA INIT 初始化。`，阻塞后续操作
   - **存在** → 继续
2. 读取 `.specanchor/config.yaml`（轻量元信息）
3. 读取 `.specanchor/global/` 下的**所有** Global Spec（合计 ≤ 200 行）
4. 报告加载状态：已加载哪些 Global Spec

## 自动加载策略（分层）

| 层级 | 触发条件 | 加载内容 |
|------|---------|---------|
| **Always Load** | Skill 激活时 | `config.yaml` + 全部 Global Spec |
| **On-Demand** | 涉及具体模块时 | 对应 `MODULE.spec.md` |
| **On-Demand** | 需要全局视角时 | `.specanchor/project-codemap.md` |

On-Demand 触发场景：
- 用户提及的文件路径落在某模块目录下
- `SA TASK` / `SA MODULE` 命令指定了模块
- RIPER Research 阶段定位到相关模块

## 原生命令

| 命令 | 用途 | 触发词 |
|------|------|--------|
| `specanchor_init` | 初始化 `.specanchor/` 目录和配置 | `SA INIT` / `初始化 SpecAnchor` |
| `specanchor_global` | 创建/全量更新 Global Spec | `SA GLOBAL <type>` / `全局规范 <类型>` |
| `specanchor_module` | 创建/全量更新 Module Spec | `SA MODULE <path>` / `模块规范 <路径>` |
| `specanchor_infer` | 从代码逆向推断 Module Spec 草稿 | `SA INFER <path>` / `推断规范 <路径>` |
| `specanchor_task` | 创建 Task Spec（含 SpecAnchor 元信息） | `SA TASK <name>` / `创建任务 <名称>` |
| `specanchor_load` | 手动加载指定 Spec 到上下文 | `SA LOAD <path>` / `加载规范 <路径>` |
| `specanchor_status` | 显示 Spec 加载状态和覆盖率 | `SA STATUS` / `规范状态` |
| `specanchor_check` | 运行 Spec-Commit 对齐检测 | `SA CHECK [task\|module\|global]` |

命令详细定义、参数、执行步骤：见 `references/specanchor-protocol.md`

## 推荐流程

### 首次使用

```text
SA INIT                              → 初始化目录结构
SA GLOBAL coding-standards           → 从代码推断编码规范
SA GLOBAL architecture               → 从代码推断架构约定
（开发时触碰模块）SA MODULE src/modules/auth  → 创建模块规范
```

### 日常任务

```text
SA TASK 登录页增加验证码                → 自动加载 Global + 相关 Module Spec
                                       → 如果加载了 SDD-RIPER-ONE → 进入 RIPER 流程
                                       → 如果未加载 → 使用简化 Task Spec 模板
```

### 检测

```text
SA CHECK task .specanchor/tasks/auth/2026-03-13_sms-login.spec.md --base=main
SA CHECK module --all
SA CHECK global
```

## 与 SDD-RIPER-ONE 的集成

SpecAnchor 在 RIPER 各阶段注入的行为：

| RIPER 阶段 | SpecAnchor 注入行为 |
|-----------|-------------------|
| Pre-Research | 自动加载 Global Spec + 定位并读取相关 Module Spec |
| Research | Module Spec 作为现状分析输入 |
| Plan | File Changes 与 Module Spec 的关键文件交叉校验 |
| Execute | 代码生成受 Global + Module Spec 约束 |
| Review | 检查 Module Spec 是否需要更新（接口变更/新增依赖） |

路径替换：RIPER 默认 `mydocs/specs/` → SpecAnchor 的 `.specanchor/tasks/<module>/`

## `.specanchor/` 不存在时

**报错并阻塞**。不自动创建目录。提示用户：

```
⛔ .specanchor/ 目录不存在。
   请运行 SA INIT 初始化 SpecAnchor。
   或手动创建目录结构，参考：references/specanchor-protocol.md §1
```

## Global Spec 约束

所有 Global Spec 文件**合计不超过 200 行**。这是 token 预算的硬约束。
如果内容超出，应拆分为 On-Demand 加载或精简措辞。

## Module Spec 更新策略

**全量重生成**：运行 `SA MODULE <path>` 时，即使 `MODULE.spec.md` 已存在，也全量重写。
- 保留 frontmatter 中的 `owner` / `reviewers` 字段
- `version` minor +1，`updated` 设为当前日期
- 建议用户通过 `git diff` 确认变更后提交

## 参考文件

- `references/specanchor-protocol.md`：核心协议（命令定义、加载规则、集成协议）
- `references/global-spec-template.md`：Global Spec 模板
- `references/module-spec-template.md`：Module Spec 模板
- `references/task-spec-template.md`：Task Spec 模板
- `references/commands-quickref.md`：命令速查表
