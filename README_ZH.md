<div align="center">
  <img src="assets/SpecAnchor_logo.png" alt="SpecAnchor Logo" width="140" />
</div>

<h1 align="center">SpecAnchor</h1>

<p align="center">
  <em>规范为锚，代码为舟。</em>
</p>

<p align="center">
  <img src="assets/SpecAnchorHero_ZH.png" alt="SpecAnchor Hero — 规范为锚·真相为据" width="860" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" />
  <a href="https://github.com/linziyanleo/spec-anchor/actions/workflows/ci.yml">
    <img src="https://github.com/linziyanleo/spec-anchor/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
  <img src="https://img.shields.io/badge/version-0.4.0--beta.1-brightgreen.svg" alt="Version 0.4.0-beta.1" />
  <img src="https://img.shields.io/badge/Claude%20Code-%E2%9C%93-orange" alt="Claude Code" />
  <img src="https://img.shields.io/badge/Cursor-%E2%9C%93-1e90ff" alt="Cursor" />
  <img src="https://img.shields.io/badge/Codex-%E2%9C%93-lightgrey" alt="Codex" />
  <img src="https://img.shields.io/badge/Gemini-%E2%9C%93-blueviolet" alt="Gemini" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ZH.md">中文</a> ·
  <a href="WHY_ZH.md">为什么需要</a> ·
  <a href="docs/INSTALL.md">安装</a> ·
  <a href="CONTRIBUTING.md">贡献</a> ·
  <a href="SKILL.md">Skill</a>
</p>

---

## SpecAnchor 是什么

**SpecAnchor 是一套会自己加载自己的三层 Spec 系统**。它把团队的编码规则、模块契约、任务意图都放在 `.specanchor/` 下，在 AI 写代码之前自动把相关的那些加载进上下文；等代码写完，再回头检查代码是否还跟 Spec 对得上。

它**自带一整套 SDD（Spec-Driven Development，规范驱动开发）写作工具链**——默认 `sdd-riper-one` schema 提供 Research → Plan → Execute → Review 四段门禁——**所以你不需要先装 Spec-Kit 或 OpenSpec 才能用 SpecAnchor**。如果你的项目里已经有 OpenSpec 或自建的 spec 目录，`parasitic` 模式可以直接套上去不用迁移，让已有的写作流程保持原样，SpecAnchor 只补加载器和防腐层。

> **→ 想看设计思路和演进路线？读 [WHY_ZH.md](WHY_ZH.md)**

> **提示**
> SpecAnchor 会写入 `.specanchor/`，可能创建或更新 `anchor.yaml`，也可能修改 Markdown frontmatter。首次使用建议在干净分支上试。

---

## 实际跑起来长什么样

Claude Code 里一个典型的 Day-2 交互——重构订单模块以支持多地址分批发货（涉及 `orders`、`shipping`、`inventory` 三个模块）：

```text
You: 创建任务：重构订单模块，支持多地址分批发货（涉及 orders、shipping、inventory）

Claude: [routes to specanchor_task → specanchor-check.sh coverage]
  ✅ 已覆盖：src/orders/    (modules/orders.spec.md)
  ✅ 已覆盖：src/shipping/  (modules/shipping.spec.md)
  ⚠️  未覆盖：src/inventory/ → 自动推断 Module Spec 草稿
  [runs specanchor_infer]
  ✓ modules/inventory.spec.md  (status=draft，需人工 review)

  ✓ .specanchor/tasks/_cross-module/2026-04-23_split-shipping.spec.md

  Assembly Trace:
    - Global: full → coding-standards, architecture
    - Module: full → orders, shipping, inventory (draft)
    - Task:   tasks/_cross-module/2026-04-23_split-shipping.spec.md
    - Schema: sdd-riper-one | Workflow: standard Task Spec

  当前阶段：Research。Plan 未通过前 Execute 被阻塞。

... （Research → Plan → Execute 略）...

You: 检查 Spec 和代码对齐

Claude: [runs specanchor-check.sh alignment]
  ✅ orders.spec.md    — 对齐
  ⚠️  shipping.spec.md  — 检测到 drift：
      ShipmentPolicy.split() 签名 ≠ 代码（代码新增 `region` 参数）
      → 更新 spec 或 revert 代码
  ✅ inventory.spec.md (draft) — 草稿阶段允许 drift
```

这里发生的三件事，裸上 AI、Spec-Kit、OpenSpec 加起来也做不到：

1. **AI 动手前相关 Spec 就位** ——Global + 三份 Module Spec 按文件路径自动 resolve，以 Assembly Trace 形式汇报
2. **覆盖度缺口自动补** ——没覆盖的 `inventory/` 触发 `specanchor_infer` 生成草稿，系统不让自己掉队
3. **事后抓 Spec ↔ 代码 drift** ——`shipping.spec.md` 标出签名不一致，比较的对象不是另一份 spec 文件，而是真实源码

---

## 三层 Spec 模型

| 层级 | 装什么 | 谁来写 | 何时加载 |
|---|---|---|---|
| **Global Spec** | 架构、编码规范、项目 setup——团队级规则 | 核心工程师，按季度更新 | 永远加载，boot 时就位 |
| **Module Spec** | 某个模块的接口契约、设计约定、依赖边界 | 模块负责人，触碰即补 | 任务目标文件命中 `module_path` 时加载 |
| **Task Spec** | 一次具体改动的意图、文件清单、门禁 | 任务作者 | 每任务新建，完成后归档 |

每一层都是持久化的、可 review 的、git 版本化的 `.spec.md` 文件——不是运行时的临时字符串。

---

## 和类似工具的对比

| 能力 | 裸上 AI | Spec-Kit | OpenSpec | **SpecAnchor** |
|---|---|---|---|---|
| 自带写作工作流 | — | ✅ 6 个 slash 命令 | ✅ artifact DAG（自称 fluid-by-design）| ✅ 内置 `sdd-riper-one`，可切换 |
| **AI 动手前自动加载相关 Spec** | ❌ | ❌ 需要社区扩展 "Memory Loader" | ❌ 只在 `/opsx:*` 命令触发时装载 | ✅ Assembly Trace 每轮输出 |
| **Global 层是独立 spec 文件** | — | ✅ `constitution.md`（单份） | ⚠️ 只是 `config.yaml` 里的 `context:` 字符串 | ✅ `global/*.spec.md`（多份：architecture / coding-standards / project-setup，各自独立 review） |
| **持久化的 Module 层** | — | ❌ feature 是分支级瞬时概念，归档即消失 | ✅ `specs/<domain>/spec.md` | ✅ `modules/*.spec.md` + `module-index.md` 索引 |
| Task / Change 层 | ❌ | ✅ 每 feature 一个目录 | ✅ `changes/<id>/` | ✅ `tasks/<module>/YYYY-MM-DD_*.spec.md`（按模块归档） |
| Spec ↔ 源代码 drift 检测 | ❌ | ⚠️ `/speckit.analyze` 只比 spec↔plan↔tasks，不看代码 | ⚠️ `/opsx:verify` 是一次性可选检查 | ✅ `specanchor-check` 按目标文件持续检测 |
| 模块覆盖度追踪 | ❌ | ❌ | ❌ | ✅ `specanchor-check coverage` |
| 套在已有 spec 目录外 | — | ❌ 期望独占 `.specify/` | ❌ 期望独占 `openspec/` | ✅ `parasitic` 模式 |

上面这些工具其实都有某种"三段式"结构——项目级 context、持久化模块契约、每次变更的 proposal。真正的分水岭是**每一层是不是一份一等公民的 spec 文件**。Spec-Kit 有扎实的项目层和变更层，但缺持久化的 module 层（feature 是分支瞬时的）。OpenSpec 有扎实的 module 和 change 层，但项目层只是塞进 prompt 的一段 YAML 字符串，不是可以拆分、review、版本化的 spec 文件。SpecAnchor 让**三层都是一等公民、都能独立 author 和索引**——这也是为什么它能按"文件路径 + 任务意图"自动 resolve 到精确切片。

---

## 60 秒上手

SpecAnchor 的核心理念是用自然语言和 agent 对话——安装也一样，把仓库扔给任一胜任的 AI 代码 agent（Claude Code、Codex、Cursor、Gemini 等），让它自己装。

**1. Clone 仓库到本机任意位置**

```bash
git clone https://github.com/linziyanleo/spec-anchor.git
```

**2. 在目标项目里打开你的 agent，对它说：**

> 使用 `<刚才 clone 的 spec-anchor 路径>` 下的 SpecAnchor skill，以 `full` 模式安装到当前项目并 boot。

Agent 会读 `SKILL.md`，把 skill 复制到它所在平台的约定 skill 目录（`.claude/skills/specanchor/`、`.cursor/skills/specanchor/` 等），跑 `specanchor-init.sh --mode=full`，然后 boot。成功的标志是聊天里打印出 **Assembly Trace**：

```text
Assembly Trace:
  - Global: summary → architecture, coding-standards, project-setup
  - Module: none (nothing touched yet)
```

**3. 从现在开始用自然语言对话**——"创建任务：…"、"检查 Spec 和代码对齐"、"从当前代码推断编码规范"。不用再敲 shell 命令。

手动 `rsync` 安装、symlink 开发环境、各 agent 独有的 skill 目录约定，见 [`docs/INSTALL.md`](docs/INSTALL.md)。

---

## 初始化后项目会多出哪些文件

`specanchor-init.sh --mode=full` 跑完后，项目多出：

```
anchor.yaml
.specanchor/
├── global/
│   ├── architecture.spec.md        # 团队级设计约定
│   ├── coding-standards.spec.md    # 风格、模式、反模式
│   └── project-setup.spec.md       # 技术栈、环境、工具
├── modules/                         # 触碰即补（不要一次性铺满）
├── tasks/                           # 按任务、按模块归档的 spec
├── archive/                         # 完成的任务挪到这里
├── module-index.md                  # 路径 → module spec 查询表
└── project-codemap.md               # 高层代码地图
```

初始的 Global Spec 内容是刻意写得通用的——你第一个真正的用例就是拿实际代码去打磨它们。完整期望结构见 [`examples/minimal-full-project/`](examples/minimal-full-project/)。

---

## Day 2 — 怎么和它对话

SpecAnchor 的主用户接口是自然语言。常用 prompt 和背后的命令对应如下：

| 你说的话 | 实际跑的命令 | 产出 |
|---|---|---|
| *"从当前代码推断编码规范"* | `specanchor_global` | `.specanchor/global/coding-standards.spec.md` 被对着真实代码打磨 |
| *"创建任务：给订单列表加分页"* | `specanchor_task` | 覆盖度检测 → 必要时 auto-infer → Task Spec + Assembly Trace |
| *"检查 Spec 和代码对齐"* | `specanchor_check` | 每个 Module Spec 的 drift 报告 + 建议动作 |
| *"推断一下 `src/auth` 的模块 spec"* | `specanchor_infer` | 从代码生成 Module Spec 草稿，需人工 review |
| *"看看 Spec 覆盖率"* | `specanchor_status` | 覆盖率 % + 模块列表 + 陈旧时间戳 |

完整意图→命令映射见 [`references/commands-quickref.md`](references/commands-quickref.md)。

---

## 两种模式

- **`full` 模式** ——SpecAnchor 独占 `.specanchor/`，自带写作流，是唯一的真相源。适合新项目，或者没有现成 spec 系统的项目。示例：[`examples/minimal-full-project/`](examples/minimal-full-project/)
- **`parasitic` 模式** ——SpecAnchor 套在已有的 spec 目录上（比如 OpenSpec 的 `openspec/specs/`），只提供加载器 + 防腐层。已有写作工具继续负责写。示例：[`examples/parasitic-openspec-project/`](examples/parasitic-openspec-project/)

---

## 延伸阅读

- **[WHY_ZH.md](WHY_ZH.md)** ——设计哲学、演进路线、"编译 vs 检索"知识观
- [`docs/INSTALL.md`](docs/INSTALL.md) ——所有安装路径（Cursor / Claude Code / symlink / 其他工具）
- [`SKILL.md`](SKILL.md) ——运行时激活契约（AI 在 boot 时实际读的那份）
- [`docs/USAGE_PROOF.md`](docs/USAGE_PROOF.md) ——端到端安装验证
- [`docs/agent-reliability.md`](docs/agent-reliability.md) ——SpecAnchor 在 Claude Code / Cursor / Codex / Gemini 下的一致性
- [`examples/agent-walkthrough/`](examples/agent-walkthrough/) ——各 agent 的 prompt 模板
- [`FLOWCHART.md`](FLOWCHART.md) ——Skill 完整调用流程图

---

## 验证命令

从仓库根目录运行：

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
git diff --check
```

---

## 当前发布状态

当前已发布的预发布版本：`v0.4.0-beta.1`。

- Release note：[`docs/release/v0.4.0-beta.1.md`](docs/release/v0.4.0-beta.1.md)
- 变更记录：[`CHANGELOG.md`](CHANGELOG.md)

## 贡献

环境要求、验证命令、PR 范围见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

代码采用 [MIT](LICENSE)；仓库图片来源与授权说明见 [`assets/README.md`](assets/README.md)。
