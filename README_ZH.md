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
  <img src="https://img.shields.io/badge/version-0.5.0--beta.1-brightgreen.svg" alt="Version 0.5.0-beta.1" />
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

**SpecAnchor 是一套 Agent 在 boot 时加载的三层 Spec 系统**。它把团队的编码规则、模块契约、任务意图都放在 `.specanchor/` 下，Agent 在写代码之前把相关的那些加载进上下文；等代码写完，再回头检查代码是否还跟 Spec 对得上。

它更像是面向 AI coding agent 的 **Context Construction System**（上下文构建系统）：把工程上下文显式分为四类——**Spec / Decision / Evidence / Finding**——编译成有边界、可审计、可沉淀的 *Context Bundle*，每个 Agent 在写代码前装载；用 *Alignment Surface*（对齐面）检测 Spec 与代码的漂移；通过 *Sediment Proposal*（沉淀提案）把高价值 finding 在人 review 后沉淀回长期 Spec（**永不自动 apply**）；并通过 *handoff packet* 支持跨 session 接手。即使同 session 内反复激活，上下文也保持 bounded：boot 是每 session 一次的 preflight、已加载的 spec 不重复打印、超大 spec 降级 summary。**SpecAnchor 不拥有 agent 执行循环**——`sdd-riper-one` 等 workflow schema 是 opt-in integration，不是默认骨架。

它**自带一套 SDD（Spec-Driven Development，规范驱动开发）工作流作为 opt-in 集成**——`sdd-riper-one` schema 提供 Research → Plan → Execute → Review 四段门禁，需要严格 workflow 时启用——**所以你不需要先装 Spec-Kit 或 OpenSpec 才能用 SpecAnchor**。如果你的项目里已经有 OpenSpec 或自建的 spec 目录，`parasitic` 模式可以直接套上去不用迁移，让已有的写作流程保持原样，SpecAnchor 只补加载器和防腐层。

### 四类 Context（v0.6 新增 Finding）

| 类别 | 来源 | 典型工件 | 生命周期 |
|---|---|---|---|
| **Spec Context (cold)** | 团队/模块/任务的契约 | `.specanchor/global/`、`modules/`、`tasks/`、Assembly Trace | 静态——git 版本化 |
| **Decision Context (hot)** | checkpoint 上的人工反馈 | Task Spec §5.2 Checkpoint Decisions Log；hot/cold 视图 | 动态——每个 checkpoint 沉淀，hot 段自动收敛 |
| **Evidence Context (hot)** | 验收证据与命令输出 | Task Spec §6.2 Evidence Ledger；acceptance criteria 自动 pin | 动态——通过 handoff packet 暴露验收状态 |
| **Finding Context (hot, v0.6+)** | agent 在 execute / review 中的发现 | `.specanchor/findings/F-*.md`，含 `visibility` 字段 | 动态——跨任务/跨会话；通过 Sediment Proposal 人审后沉淀 |

Decision 和 Evidence 沉淀在 Task Spec；Finding 是独立 artifact（跨任务可复用）。四者由 `specanchor-assemble.sh --bundle-schema=context_bundle.v1` 或 `specanchor-boot.sh --agent --intent="..."` 装配成 **Context Bundle v1** JSON（`specanchor.context_bundle.v1`）。

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
  ⚠️  未覆盖：src/inventory/ → agent 按 specanchor_infer 协议推断 Module Spec 草稿
  [agent 执行 specanchor_infer — 扫描代码，写出草稿]
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
  ✅ orders.spec.md    — 对齐（sha 最新）
  ⚠️  shipping.spec.md  — 陈旧：模块代码在上次 spec 同步后有变更
      → 对照当前代码审查 spec，必要时更新
  ✅ inventory.spec.md  — 对齐（sha 最新，刚创建）
```

这里发生的三件事，裸上 AI、Spec-Kit、OpenSpec 加起来也做不到：

1. **AI 动手前相关 Spec 就位** ——Global + 三份 Module Spec 按文件路径自动 resolve，以 Assembly Trace 形式汇报
2. **覆盖度缺口由 agent 按协议补** ——没覆盖的 `inventory/` 触发 `specanchor_infer` 协议，agent 扫描代码写出 Module Spec 草稿
3. **事后抓模块新鲜度漂移** ——`shipping.spec.md` 被标为陈旧，因为模块代码在上次 spec 同步后有变更——触发审查提示

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
| **持久化的 Module 层** | — | ❌ feature 是分支级瞬时概念，归档即消失 | ✅ `specs/<domain>/spec.md` | ✅ `modules/*.spec.md` + `spec-index.md` 索引 |
| Task / Change 层 | ❌ | ✅ 每 feature 一个目录 | ✅ `changes/<id>/` | ✅ `tasks/<module>/YYYY-MM-DD_*.spec.md`（按模块归档） |
| Spec ↔ 源代码 drift 检测 | ❌ | ⚠️ `/speckit.analyze` 只比 spec↔plan↔tasks，不看代码 | ⚠️ `/opsx:verify` 是一次性可选检查 | ✅ `specanchor-check` — 命令触发的模块新鲜度 + 文件变更对齐 + 覆盖度检查 |
| 模块覆盖度追踪 | ❌ | ❌ | ❌ | ✅ `specanchor-check coverage` |
| **Checkpoint 决策捕获 & hot/cold 过滤** | ❌ | ❌ | ❌ | ✅ Decision Log §5.2 + 懒计算 hot/cold 视图 |
| **Evidence Ledger 一等公民** | ❌ | ❌ | ❌ | ✅ Evidence Ledger §6.2 + acceptance criteria 自动 pin |
| 套在已有 spec 目录外 | — | ❌ 期望独占 `.specify/` | ❌ 期望独占 `openspec/` | ✅ `parasitic` 模式 |

上面这些工具其实都有某种"三段式"结构——项目级 context、持久化模块契约、每次变更的 proposal。真正的分水岭是**每一层是不是一份一等公民的 spec 文件**。Spec-Kit 有扎实的项目层和变更层，但缺持久化的 module 层（feature 是分支瞬时的）。OpenSpec 有扎实的 module 和 change 层，但项目层只是塞进 prompt 的一段 YAML 字符串，不是可以拆分、review、版本化的 spec 文件。SpecAnchor 让**三层都是一等公民、都能独立 author 和索引**——这也是为什么它能按"文件路径 + 任务意图"自动 resolve 到精确切片。

---

## 60 秒上手

### 方式 A：Claude Code 插件安装（推荐）

以插件形式安装可启用 **SessionStart hook 自动注入**——在含 `anchor.yaml` 或 `.specanchor/` 的项目中，agent 会在 session 启动时自动加载 spec 上下文，无需手动触发。

```bash
# 开发测试（仅当前 session，不持久化）
claude --plugin-dir /path/to/spec-anchor

# 永久安装（通过自建 marketplace）
/plugin marketplace add <你的 git 仓库地址>
/plugin install spec-anchor@spec-anchor
```

安装后，打开任何含 `anchor.yaml` 或 `.specanchor/` 的项目，插件会在 session 启动时注入上下文，`spec-anchor` skill 自动被发现。

### 方式 B：Skill 安装（适用于所有 agent）

适用于 Cursor、Codex、Gemini 或不使用插件系统的 Claude Code：

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

**3. 从现在开始用自然语言对话**——"创建任务：…"、"检查 Spec 和代码对齐"、"从当前代码推断编码规范"。Agent 在内部处理脚本调用。

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
├── spec-index.md                  # 路径 → module spec 查询表
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
| *"把这个任务交给新 chat 继续"* | `specanchor_handoff` | handoff packet（hot 决策 + 验收状态 + 推荐读取列表）——粘进新 session 即可接手 |

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

当前已发布的预发布版本：`v0.5.0-beta.1`。

- Release note：[`docs/release/v0.5.0-beta.1.md`](docs/release/v0.5.0-beta.1.md)
- 变更记录：[`CHANGELOG.md`](CHANGELOG.md)

## 贡献

环境要求、验证命令、PR 范围见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

代码采用 [MIT](LICENSE)；仓库图片来源与授权说明见 [`assets/README.md`](assets/README.md)。
