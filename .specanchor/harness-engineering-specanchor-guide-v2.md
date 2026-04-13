# 基于 SDD 的上下文治理 —— SpecAnchor : 做 Harness Engineering 的落地实践

2025 年以来，Claude Opus 4.x、GPT-5.x、Gemini 3.x 在 SWE-Bench 上轮番刷分，单文件代码生成的准确率已经很高了。但把 90% 以上的开发过程交给 AI 对话——也就是 Vibe Coding——在复杂项目里仍然不好使。问题不在模型能力，在使用方式。

---

## 一、为什么需要 Spec 治理

### 1.1 Vibe Coding 的问题

Vibe Coding 在简单任务上没问题。复杂项目里会遇到三个麻烦：

**上下文腐烂。** 对话轮次增加，模型注意力衰减。第 3 轮说的前置约束，到第 15 轮可能已经丢了。20-30 轮的重构任务，这几乎必然发生。

**审查瘫痪。** 模型一分钟生成 500 行代码，人审不过来。面对一个全是 AI 写的 PR，你其实是在猜它做的对不对。

**维护断层。** AI 生成的代码没有设计意图记录。两周后回来，不知道为什么是这样写的，不敢改。

三个问题的共同根源：对话是短期记忆，复杂工程需要长期记忆和结构化约束。

### 1.2 Harness Engineering 的思路

2025 年底到 2026 年初，Harness Engineering 这个概念开始在业界被讨论。OpenAI 的 Codex 团队在一篇博客中描述了他们的内部实验：用 AI Agent 构建了一个超过百万行代码的应用，工程师不直接写代码，而是设计 Agent 的约束系统。他们把约束规则编码为仓库内的版本化文件，称之为 Golden Principles，并强调这些规则需要周期性清理以避免腐化。

LangChain 也发表过类似观点。他们的编码 Agent 在 Terminal Bench 2.0 上从 52.8% 提升到 66.5%，提升手段是改进 prompt、tools 和 middleware 的组合，而非换模型。他们把这类改进统称为 harness 优化。

Martin Fowler 在其网站上也对 Harness Engineering 做了阐述，将其定义为围绕 AI Agent 设计约束、工具、反馈回路和可观测性基础设施的工程实践。

这些讨论指向一个共识：Agent 的能力上限不只取决于模型本身，还取决于它运行时的约束和上下文环境。Harness 通常包含几个方面：

- **上下文工程**：Agent 每次行动前能看到什么信息
- **架构约束**：Agent 的行为边界和检查点
- **反馈回路**：产出与规范之间的偏差检测
- **可观测性**：人类能追踪 Agent 的行为和决策
- **垃圾回收**：过期约束的清理

SpecAnchor 是 harness 体系中 Spec 治理这一块的落地工具。它集中处理上下文工程（分层 Spec 加载）和架构约束（Schema 门禁），同时在反馈回路（对齐检测脚本）和可观测性（frontmatter 追踪）上提供了基础能力。它不是一个全栈 harness 平台。

---

## 二、一次真实的多文件重构

看一个实际案例。下面的任务来自 [Fizz](https://fizz.alibaba-inc.com/)（AI 知识创意平台，可以在上面查资料、速读播客、把知识库凝练成文档）。任务是重构 TopicDocument 组件的文档生命周期，从展示/预览升级为 MarkdownDiffEditor 驱动的版本迭代交互。涉及 7 个文件、跨组件状态管理、UI 交互变更。

这个案例中 Agent 跑的是一套 Research → Innovate → Plan → Execute → Review 的开发流程，能力主要来自 @无岳 老师的 SDD-RIPER-ONE 规范。当前 SpecAnchor 可以自定义写作 schema，也可以使用默认内置的 SDD-RIPER-ONE 规范。这里想展示的是 SpecAnchor 在 Spec 写作之外做的事情：上下文怎么来的、Spec 落在哪里、任务结束后知识怎么沉淀。

### 2.1 任务开始前：上下文从哪来

我给模型的提示词是「重构 TopicDocument 的文档 Diff 生命周期」。SpecAnchor 做了三件事：

1. 创建一份 Task Spec，存放在 `.specanchor/tasks/` 下，路径按模块映射（`/` → `-`），和代码目录天然对应
2. 从 `module-index.md` 定位到两份相关的 Module Spec 并加载到上下文
3. Global Spec（编码规范、架构约定）已经在 Skill 启动时加载好了

Agent 进入 Research 阶段时，它已经知道 TopicDetail 的三列布局结构、MarkdownDiffEditor 的接口契约、项目的命名和错误处理规范。这些不是 Agent 自己翻代码翻出来的，而是 Spec 体系提前准备好的上下文。

Research 把模糊需求锚定为一个 5 状态的状态机：

```text
[空文档] ──传入 diffNewContent──→ [首版 doc]
  (自动: diffNewContent → diffOldContent, 无 diff 显示)

[首版 doc] ──AI 对话输出新 diffNewContent──→ [非首版 diff 模式]
  (diffNewContent vs diffOldContent 做 diff, 禁止 TopicChat 继续对话)

  ├── 撤销 → 恢复 diffOldContent, 解锁对话
  └── 应用修改 → diffNewContent 成为 diffOldContent, 解锁对话
```

> **📌 信息图位置 1**：Diff 生命周期状态机流转图，展示 5 个状态之间的转换条件和数据流。

### 2.2 任务进行中：决策写在文件里，不在对话里

Research 暴露了跨组件状态共享问题。三个兄弟组件需要共享状态，最终决策是创建 `TopicDetail/context.tsx`，用 `useReducer` 管理。

这个决策写进了 Task Spec 的 Innovate 章节。Plan 阶段的变更清单和 15 项 Checklist 也写进 Task Spec。Agent 停下来等人工确认 Plan，确认之后才进入执行。

关键点是：这些产出全部落在 `.specanchor/tasks/` 下的文件里，不是散落在一次对话的上下文中。换一个 Agent session、换一个模型，只要读这份 Task Spec 就能接上进度。对话可以丢，Spec 不会丢。

### 2.3 任务结束后：知识回流

Review 阶段做了两件事。一是检查代码是否按 Plan 完成，二是检查 Module Spec 是否需要更新。这次重构给 TopicDetail 新增了 `checkedSourceCount` 和 `isDiffPending` 两个接口，Review 标记了对应的 Module Spec 需要同步。

这就是三级 Spec 体系的闭环：Task 级的结论回流到 Module 级契约。下次有人改 TopicDetail 相关的代码，Agent 加载的 Module Spec 里已经包含了这次重构的接口变更。团队知识不会因为一次对话结束而消失。

> **📌 信息图位置 2**：Task Spec 文件的关键章节截图，展示 frontmatter → Research → Innovate → Plan → Execute Log → Review Verdict 的完整结构。

### 2.4 SpecAnchor 在这个案例里做了什么

总结一下，和开发流程本身（怎么拆需求、怎么写 Plan、怎么设门禁）无关的，SpecAnchor 做了这些：

- **任务开始前**：自动加载 Global + Module Spec，Agent 不用从零翻代码来了解项目规范
- **任务进行中**：所有阶段产出落在 Task Spec 文件里，不依赖对话上下文的持久性
- **任务结束后**：Review 触发 Module Spec 更新检查，Task 级结论回流到 Module 级
- **之后的任何时间**：frontmatter 记录了 Spec 的创建时间、作者、同步状态；`specanchor-check.sh` 可以检测这份 Spec 是否过期

这些能力和你用什么开发流程无关。不管是 RIPER 五步、简单的 Plan → Execute，还是团队自定义的流程，SpecAnchor 管理的是 Spec 的存放、加载、生命周期和跨层级一致性。流程是可插拔的（通过 Schema 系统切换），治理层是固定的。

---

## 三、SpecAnchor 的设计

### 3.1 三级 Spec 体系

SpecAnchor 把 Spec 分三层，核心考虑是 token 预算和加载时机。

```text
┌─────────────────────────────────────────────────────┐
│  L1: Global Spec                                    │
│  .specanchor/global/                                │
│  编码规范 · 架构约定 · 项目配置                       │
│  变更频率: 季度 | Token 预算: ≤ 200 行 | 始终加载     │
├─────────────────────────────────────────────────────┤
│  L2: Module Spec                                    │
│  .specanchor/modules/                               │
│  接口契约 · 业务规则 · 代码结构约定                    │
│  变更频率: 每 Sprint | 按需加载（通过 module-index）   │
├─────────────────────────────────────────────────────┤
│  L3: Task Spec                                      │
│  .specanchor/tasks/<module>/                        │
│  单次变更目标 · 执行计划 · 执行日志 · 偏差记录         │
│  变更频率: 每任务 | 随用随建                          │
└─────────────────────────────────────────────────────┘
```

为什么分层？单一 Spec 文件面对复杂项目有两个问题。Token 爆炸：所有规范塞进一个文件会撑爆上下文窗口。职责混淆：编码规范和具体任务的执行计划混在一起，维护成本高。

Global Spec 始终加载，合计不超过 200 行，这样的硬约束是为了只保留最核心的编码规范、架构约定、项目配置。Module Spec 按需加载，只有任务涉及某个模块时才通过 `module-index.md` 定位。Task Spec 是当前任务的施工文档，创建后全程在上下文中。

下面是一个 Global Spec 的例子，来自 SpecAnchor 自身项目：

```yaml
# .specanchor/global/coding-standards.spec.md（节选）
---
specanchor:
  level: global
  type: coding-standards
  version: "2.0.0"
  author: "@fanghu"
  last_synced: "2026-04-02"
---

# 编码规范

## 技术栈
- Shell 脚本：Bash 4+，`set -euo pipefail` 强制
- 文档：Markdown (YAML frontmatter)
- 配置：YAML (`anchor.yaml`, `schema.yaml`)

## Shell 脚本约定
- 首行 shebang：`#!/usr/bin/env bash`
- 颜色输出：TTY 检测 `[[ -t 1 ]]`，非终端时静默
- 错误退出：`die()` 函数统一错误输出到 stderr
- 临时文件：`mktemp` 创建，cleanup 函数中统一清理

## 命名约定
- 脚本文件：kebab-case（`specanchor-check.sh`）
- 命令名：snake_case（`specanchor_init`）
- Spec 文件：`<module-id>.spec.md`

## Git 提交约定
- 格式：`<type>(<scope>): <subject>`
- type：feat / fix / docs / refactor / test / chore
```

大概 50 行。不管哪个模型、哪个开发者启动任务，生成的代码都会遵循同样的命名和错误处理规范。

> **📌 信息图位置 3**：三级 Spec 体系的架构图，展示 Global → Module → Task 的层级关系，标注变更频率、Token 预算、加载时机。

### 3.2 可插拔的 Schema 系统

不同类型的任务需要不同的流程。新功能开发需要 Research → Plan → Execute → Review，Bug 修复需要 Reproduce → Diagnose → Fix → Verify。SpecAnchor 通过 Schema 系统处理这个问题，每种任务类型对应一种写作协议，定义 Task Spec 的模板、阶段和门禁规则。

内置 Schema：

| Schema | 适用场景 | philosophy | 关键特征 |
|--------|---------|------------|---------|
| **sdd-riper-one**（默认） | 新功能、功能增强 | strict | Research → Innovate → Plan ⏸️ → Execute → Review |
| **bug-fix** | Bug 修复 | strict | Reproduce → Diagnose → Root Cause → Fix → Verify |
| **refactor** | 代码重构 | strict | Measure → Identify → Plan → Execute → Verify |
| **research** | 技术调研 | strict | Question → Explore → Findings ⏸️ → Challenge → Conclusion |
| **simple** | 轻量修改 | fluid | 无门禁，直接执行 |
| **openspec-compat** | 兼容已有 OpenSpec 项目 | fluid | Delta-spec 兼容模式 |

⏸️ 表示门禁：Agent 停下来等人类确认才能继续。`philosophy: strict` 的 Schema 都有门禁，`fluid` 没有。research schema 是 strict 的，它在 Findings 阶段有一个 Findings Reviewed 门禁，确认调研结论后才能进入 Challenge。

Schema 用 YAML 声明式定义。SDD-RIPER-ONE 的核心结构：

```yaml
# references/schemas/sdd-riper-one/schema.yaml
name: sdd-riper-one
philosophy: strict

artifacts:
  - id: research
    section: "## 2. Research Findings"
    requires: []

  - id: plan
    section: "## 4. Plan (Contract)"
    requires: [research]
    gate:
      type: approval
      phrase: "Plan Approved"
      blocks: [execute]

  - id: execute
    section: "## 5. Execute Log"
    requires: [plan]

  - id: review
    section: "## 6. Review Verdict"
    requires: [execute]
```

团队也可以在 `.specanchor/schemas/` 下自定义写作协议。

### 3.3 anchor.yaml 配置

每个项目有一个 `anchor.yaml` 作为配置入口，定义 Spec 存放路径、运行模式、写作协议、覆盖率扫描范围和新鲜度阈值。

```yaml
specanchor:
  version: "0.6.0"
  project_name: "my-project"

  mode: "full"   # full（完整管理）| parasitic（仅治理已有 Spec 系统）

  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    module_index: ".specanchor/module-index.md"

  sources:        # 可选：治理已有的 Spec 系统
    - path: "docs/superpowers/specs/"
      type: "custom"
      governance:
        stale_check: true
        frontmatter_inject: true

  writing_protocol:
    schema: "sdd-riper-one"
    schema_recommend: true

  coverage:
    scan_paths: ["src/**"]
    ignore_paths: ["src/test/**"]

  check:
    stale_days: 14    # 14 天未同步 → STALE
    outdated_days: 30  # 30 天未同步 → OUTDATED
```

如果项目已经有了Spec文件结构怎么办？不用担心，SpecAnchor 支持 parasitic 模式，只做 frontmatter 注入和新鲜度追踪，对已有 Spec 文件做最轻量的治理。团队不用一步到位，可以只做新鲜度追踪。

### 3.4 脚本工具：对齐检测与 Frontmatter 注入

SpecAnchor 的治理能力不只停留在协议层面，它附带了三个可以直接跑的 Bash 脚本，是目前最成熟的落地资产。

**specanchor-check.sh** 是对齐检测的核心工具，支持四种模式：

```bash
# $SA_SKILL_DIR = Skill 安装目录（见 SKILL.md「脚本调用约定」）

# Task 检测：检查 Checklist 完成情况，比对 Plan 和实际执行的偏差
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" task path/to/task.spec.md

# Module 检测：联动 Git 历史，判断 Module Spec 的新鲜度
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" module path/to/module.spec.md

# Global 概览：扫描全项目，输出 Spec 健康度报告
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" global

# Coverage 检测：传入文件路径，检查是否被 Module Spec 覆盖
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" coverage src/modules/auth/index.ts src/modules/auth/types.ts
```

Module 检测的工作方式：脚本读取 Spec 的 frontmatter 中的 `last_synced` 时间戳，再用 `git log` 查询该模块目录下的最近提交时间，两者比对得出新鲜度状态。DRIFTED 表示代码变了但 Spec 没更新，STALE 表示超过 14 天未同步，OUTDATED 表示超过 30 天。阈值在 `anchor.yaml` 中可配。

这个脚本可以直接集成到 CI/CD。在 MR 合入前跑一次 `specanchor-check.sh global`，就能发现哪些 Spec 开始腐化了——效果类似于测试覆盖率报告，只不过检测的是 Spec 和代码之间的同步状态。

**frontmatter-inject.sh** 解决的是存量 Spec 的接入问题。项目里已有的 Markdown Spec 文件通常没有 SpecAnchor 的 YAML frontmatter，这个脚本可以自动推断并注入 `author`、`created`、`branch`、`task_name`、`sdd_phase`、`status` 等字段。支持单文件和整目录批量注入，幂等安全——已有 `specanchor:` frontmatter 的文件会自动跳过。

```bash
# 预览：看看会注入什么，不实际修改文件
bash "$SA_SKILL_DIR/scripts/frontmatter-inject.sh" --dir docs/specs/ --dry-run

# 执行注入
bash "$SA_SKILL_DIR/scripts/frontmatter-inject.sh" --dir docs/specs/
```

**frontmatter-inject-and-check.sh** 是前两者的组合：先注入 frontmatter，再自动运行新鲜度检测。适合首次接入时一步完成。

三个脚本的共同特点：纯 Bash 实现，不依赖 Node/Python 运行时；遵循 `set -euo pipefail`，错误处理严格；macOS 和 Linux 双平台兼容。它们可以脱离 Agent 环境独立运行，这也是 SpecAnchor 在「协议优先」设计下给模型的即开即用工具能力。

### 3.5 SpecAnchor 在 Harness 维度上的覆盖

| Harness 维度 | SpecAnchor 的覆盖 | 具体机制 |
|-------------|------------------|---------|
| 上下文工程 | 三级 Spec 分层按需加载 | Global 始终加载 + Module 按需加载 |
| 架构约束 | 门禁状态机 + 工作流选择 | Schema gate 声明，Plan Approved 阻塞 Execute |
| 反馈回路 | specanchor-check 对齐检测 | Task/Module/Global/Coverage 四种检测模式 |
| 可观测性 | YAML frontmatter 元数据 | author / created / last_synced / status 可查 |
| 垃圾回收 | Spec 新鲜度状态机 | FRESH → DRIFTED → STALE → OUTDATED |

上下文工程和架构约束是最成熟的部分。反馈回路有可用的脚本工具。

### 3.6 工具链集成

SpecAnchor 是纯文本协议（Markdown + YAML + Shell），不绑定 IDE：

| 工具 | 集成方式 |
|-----|---------|
| **Claude Code** | Skill 安装，anchor.yaml + .specanchor/ 目录触发自动激活 |
| **Cursor / Windsurf** | 将 SKILL.md 内容注入 .cursorrules |
| **GitHub Copilot** | 协议内容注入 .github/copilot-instructions.md |
| **CI/CD** | specanchor-check.sh 作为 MR 门禁脚本 |

> **📌 信息图位置 4**：工具链集成架构图，展示 anchor.yaml 作为中心，连接 IDE、CI/CD、Git 的关系。

---

## 四、和行业方案的定位

如果把行业内成熟的 Spec 方案用最直白的话来区分，可以分成两类：

- **Spec Kit / OpenSpec / Kiro** 更像“怎么把一次需求写成 spec，并把它推进到实现”的工作流方案。
- **SpecAnchor** 更像“团队的 spec 越来越多之后，长期怎么管理它们”的治理方案。

| 方案 | 更像什么 | 最擅长什么 | 一眼看出的差别 |
|------|----------|------------|----------------|
| **SpecAnchor** | spec 的“档案馆 + 调度系统” | 分层存放、按需加载、跟踪新鲜度、检查覆盖率 | 不强绑定某个 IDE，也不限制你只能用哪一种 spec 写法 |
| **Spec Kit** | 一套完整的 spec 开发手册 | 从想法到 plan、tasks、implement 的整套步骤 | 更强调“把一个需求一步步写清楚，再推进下去” |
| **OpenSpec** | 轻量的变更提案框架 | 用 `proposal / design / tasks` 描述一次改动，适合存量项目渐进演化 | 更轻、更灵活，重点是把“这次变更”讲清楚 |
| **Kiro** | 自带界面的 spec 工作台 | 在 IDE / CLI 里直接跑 requirements → design → tasks 的流程 | 更像产品化体验，工作流和工具界面是一体的 |

如果只记一句话：

- **Spec Kit / OpenSpec / Kiro** 主要回答的是：**这次需求，怎么写成 spec 并推进实现？**
- **SpecAnchor** 主要回答的是：**项目的 spec 变多之后，怎么组织、加载、同步和治理？**

---

## 五、常见误区

**一次性写全所有 Module Spec。** 没必要。只在模块首次被修改时创建。渐进式覆盖的成本低，而且基于真实场景产出的 Spec 质量更高。

**把 Global Spec 写成百科全书。** Global Spec 有 200 行硬约束，因为每次对话都加载。只写最核心的规则，详细规范下沉到 Module Spec。

**忽略 Spec 新鲜度。** 代码改了 Spec 没更新，是最常见的腐化模式。建议把 specanchor-check 接入 CI，让 Spec 腐化像测试失败一样可见。

**把 SpecAnchor 当成文档负担。** 核心逻辑是审 Plan 代替审 Code。花 10 分钟审一份 Plan，省下花 1 小时审 500 行 AI 生成的代码。

---

## 六、一个可能不太合时宜的猜想

当前的工程实践是代码为先、Spec 跟进。写完代码再补文档，或者边写边补。SpecAnchor 也是在这个前提下设计的——它治理的是“已经存在或即将被创建的 Spec”，而不是试图取代代码本身。

但模型能力的进化速度值得保持一点敬畏。

如果有一天，Agent 生成的代码质量稳定到人类不再需要逐行 review——就像我们今天不会逐行 review 编译器的汇编输出——那时候 Spec 的地位会发生根本变化。写 Spec 本身会变成「编程」，代码变成编译产物。开发者的日常工作不再是写代码和审代码，而是写 Spec、审 Spec、维护 Spec 之间的一致性。

到那个阶段，Spec 的治理问题会比今天复杂得多。Spec 之间的依赖关系、版本冲突、合并策略，可能需要类似 Git 的专用工具来管理。两个人同时修改同一个 Module Spec 的不同部分，怎么 merge？一个 Task Spec 的执行结果和另一个 Task Spec 的前提假设冲突了，怎么检测？这些问题今天还不突出，因为 Spec 的量级和变更频率远不及代码。但如果 Spec 成为一等公民，它们就会有代码今天面临的所有协作问题。

SpecAnchor 现在做的事情——和 Spec 内容本身无关的上下文管理、新鲜度追踪、覆盖率度量、跨层级的一致性检测——在那个未来里反而可能是更有价值的基础设施。它不规定你的 Spec 长什么样、用什么格式、遵循什么方法论，它只管理 Spec 的生命周期和加载策略。这个定位是刻意的。

当然，这个猜想可能太远了。眼下更实际的问题还是：怎么让 Agent 在当前的能力水平下，少犯错、可追溯、能协作。Harness Engineering 留下了这个命题，未来仍交给我们持续跟进前沿 AI 实践的布道师们继续探索。

---

*SpecAnchor 仓库地址：[spec-anchor](https://code.alibaba-inc.com/aone-open-skill/spec-anchor/branches)*
*Aone 一键安装：[安装链接](https://open.aone.alibaba-inc.com/skill/spec-anchor)*

参考资料：

- [Harness engineering: leveraging Codex in an agent-first world | OpenAI](https://openai.com/index/harness-engineering/)
- [Improving Deep Agents with Harness Engineering | LangChain](https://blog.langchain.com/improving-deep-agents-with-harness-engineering/)
- [Harness Engineering | Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [Skill Issue: Harness Engineering for Coding Agents | HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)
- [Cursor Rules Documentation](https://docs.cursor.com/en/context/rules)
- [How Claude remembers your project | Claude Code Docs](https://code.claude.com/docs/en/memory)
- [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)
- [Spec Kit Documentation](https://github.github.com/spec-kit/)
- [Getting Started with OpenSpec](https://openspec.pro/getting-started/)
- [Kiro Specs Documentation](https://kiro.dev/docs/specs/)
