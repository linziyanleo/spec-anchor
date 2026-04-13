# Harness Engineering 实战：用 SpecAnchor 驾驭 AI Agent 的三级 Spec 体系

> **Spec (Truth) + Harness (Constraint) + Agent (Execute) = Reliable Software**

---

## 一、模型越强，Harness 越重要

### 1.1 Vibe Coding 的三重困境

2025 年以来，大语言模型的代码能力突飞猛进。Claude Opus 4.x、GPT-5.x、Gemini 3.x 在 SWE-Bench 等基准测试中频频刷新纪录，单文件代码生成的准确率已逼近人类水平。但 Vibe Coding——将 90%+ 的开发过程交给 AI——被视为项目开发中的洪水猛兽。这并非模型能力不足，而是现有的使用方式存在结构性缺陷。

所谓 Vibe Coding，就是开发者通过自然语言对话直接指挥 AI 编写代码，中间没有任何结构化的约束。这在简单任务上表现出色，但面对复杂项目时会暴露三个致命问题：

**上下文腐烂（Context Decay）：** 随着对话轮次增加，模型的注意力逐渐涣散。你在第 3 轮告诉它的前置约束，到第 15 轮时它可能已完全遗忘，导致生成的代码与早期约定矛盾。对于动辄 20-30 轮对话的复杂重构任务，这几乎是必然发生的。

**审查瘫痪（Review Paralysis）：** 模型一分钟可以生成 500 行代码，但人类根本审查不过来。当你面对一个全是 AI 陌生代码的 PR 时，你实际上是在做"黑盒猜谜"——你无法确信这些代码真正做了你想要的事情。

**维护断层（Maintenance Gap）：** AI 生成的代码缺乏设计意图的记录。两周后回头看，你自己都不知道为什么代码是这样写的，更不敢轻易改动。代码变成了"一次性消耗品"。

### 1.2 根因分析：Agent 缺少 Harness

这三个问题的根因是同一个：**对话是短期记忆，而复杂工程需要长期记忆和结构化约束。**

2026 年初，OpenAI 的 Codex 团队做了一个实验：他们构建了一个超过 100 万行代码的生产应用，**零行代码由人类编写**。工程师的全部工作不是写代码，而是设计让 AI 可靠编码的系统——他们将此命名为 **Harness Engineering**。

更有说服力的是 LangChain 的数据：他们的编码 Agent 在 Terminal Bench 2.0 上从 52.8% 跳到 66.5%——从 Top 30 跃升至 Top 5。**他们没有换模型，只换了 Harness。** 同一个模型，不同的约束系统，结果天壤之别。

> 换模型，性能差 10-15%。换 Harness，决定系统是否能用。Harness 是 80% 的决定因素。

### 1.3 Harness Engineering：2026 年的回答

**Harness Engineering** 是围绕 AI Agent 设计约束、工具、反馈回路和可观测性基础设施的工程学科。它不是 Agent 本身，而是 Agent 运行的"缰绳和马鞍"。

它回答的核心问题是：**如何让一个强大但不可预测的 AI Agent，在复杂项目中可靠地工作？**

Harness 包含五个关键维度：

| 维度 | 含义 | 解决的问题 |
|------|------|-----------|
| **上下文工程** | Agent 每次行动前能"看到"什么 | 上下文腐烂 |
| **架构约束** | Agent 的行为边界和门禁机制 | 无约束的自主性风险 |
| **反馈回路** | 产出与规范的对齐检测 | 偏差累积 |
| **可观测性** | 人类能追踪 Agent 做了什么、为什么 | 审查瘫痪 |
| **垃圾回收** | 过期规范和腐化约束的清理 | 维护断层 |

OpenAI 在 Codex 实验中的做法印证了这一点：他们将"黄金原则"（Golden Principles）编码为仓库内的版本化文件，并构建了周期性清理流程。这些原则是机械的、有观点立场的规则——目的是让代码库对**下一次** Agent 运行保持可读和一致。

**SDD（Spec-Driven Development）是 Harness Engineering 的一个早期实践范式**——它在"上下文工程"和"架构约束"两个维度上提出了解法（Spec 文档 + RIPER 状态机）。而 SpecAnchor 则是 SDD 理念的完整 Harness 实现，覆盖了全部五个维度。

### 1.4 从 Vibe Coding 到 Harness Engineering

| **维度** | **Vibe Coding** | **Harness Engineering** |
|----------|-----------------|------------------------|
| 上下文管理 | 依赖对话历史，随轮次衰减 | 持久化 Spec 分层加载，每次从文档锚定上下文 |
| 行为约束 | 无约束，Agent 自由发挥 | 门禁机制 + Schema 状态机强制分步执行 |
| 审查方式 | 审 500 行 AI 代码（黑盒） | 审 2 页 Plan 文档（白盒），再逐步验收代码 |
| 偏差检测 | 全靠人眼 | 自动化对齐检测（Spec vs 代码 vs Git 历史） |
| 可维护性 | 代码即弃品，无设计意图记录 | Spec 即资产，代码是"编译产物" |
| 模型切换成本 | 换模型需重新"教"一遍上下文 | 换模型只需喂 Spec，即刻恢复 |

---

## 二、SpecAnchor：一个完整的 Harness 实现

### 2.1 设计哲学

> **Spec 是锚，代码是船。锚定住了，船才不会漂。**

SpecAnchor 继承了 SDD 的三条铁律，并将它们从"单文件协议"升级为"组织级治理体系"：

| SDD 铁律 | SpecAnchor 的演进 |
|----------|------------------|
| **文档即真理** | 从单一 Spec 文件 → 三级 Spec 层级化治理（Global/Module/Task） |
| **No Spec, No Code** | 从对话约束 → 门禁状态机（`📋 标准流程` 阻塞代码生成直到 Task Spec 创建） |
| **反向同步** | 从手动回写 → 自动化新鲜度检测（FRESH/DRIFTED/STALE/OUTDATED） |

SpecAnchor 的核心创新是：**它不仅管理单次开发的 Spec，更管理整个项目的 Spec 生态**——覆盖率、新鲜度、跨模块一致性。

### 2.2 三级 Spec 体系

SpecAnchor 将 Spec 分为三个层级，每个层级有不同的变更频率、审查机制和 Token 预算：

```
┌─────────────────────────────────────────────────────┐
│  L1: Global Spec（宪法级）                           │
│  .specanchor/global/                                │
│  编码规范 · 架构约定 · 项目配置                       │
│  变更频率: 季度 | Token 预算: ≤ 200 行 | 始终加载     │
├─────────────────────────────────────────────────────┤
│  L2: Module Spec（契约级）                           │
│  .specanchor/modules/                               │
│  接口契约 · 业务规则 · 代码结构约定                    │
│  变更频率: 每 Sprint | 按需加载（通过 module-index）   │
├─────────────────────────────────────────────────────┤
│  L3: Task Spec（执行级）                             │
│  .specanchor/tasks/<module>/                        │
│  单次变更目标 · 执行计划 · 执行日志 · 偏差记录         │
│  变更频率: 每任务 | 随用随建                          │
└─────────────────────────────────────────────────────┘
```

**为什么需要三级？**

单一 Spec 文件面对复杂项目有两个问题：一是 Token 爆炸——把所有规范塞进一个文件会撑爆上下文窗口；二是职责混淆——编码规范和具体任务的执行计划混在一起，维护成本极高。

三级体系的设计原则是**分层加载**：

- **Global Spec** 始终加载，因为它是"宪法"——Agent 的每一次行动都必须遵守。合计 ≤ 200 行的硬约束确保不会占用过多 Token。
- **Module Spec** 按需加载——只有当任务涉及某个模块时，才通过 `module-index.md` 定位并加载对应的 Module Spec。
- **Task Spec** 是当前任务的"施工图"，创建后全程在上下文中。

以下是一个真实项目的 Global Spec 示例（来自 SpecAnchor 自身项目）：

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

这份规范只有 ~50 行，但它为 AI Agent 设定了明确的编码"宪法"。无论哪个模型、哪个开发者启动任务，生成的代码都会遵循同样的命名、错误处理和提交规范。

> **📌 信息图位置 1**：一张三级 Spec 体系的架构图。展示 Global → Module → Task 的层级关系，标注每级的变更频率、Token 预算、加载时机。可以用"金字塔"或"洋葱圈"的视觉隐喻。

### 2.3 可插拔的 Schema 系统

不同类型的任务需要不同的开发流程。一个新功能开发需要完整的 Research → Plan → Execute → Review；但一个 Bug 修复需要的是 Reproduce → Diagnose → Fix → Verify。

SpecAnchor 通过 **Schema 系统** 解决了这个问题——每种任务类型对应一种"写作协议"，定义了 Task Spec 的模板、阶段和门禁规则：

| Schema | 适用场景 | 哲学 | 关键特征 |
|--------|---------|------|---------|
| **sdd-riper-one**（默认） | 新功能开发、功能增强 | strict | Research → Innovate → Plan ⏸️ → Execute → Review |
| **bug-fix** | Bug 修复 | strict | Reproduce → Diagnose → Root Cause → Fix → Verify |
| **refactor** | 代码重构 | strict | Measure → Identify → Plan → Execute → Verify（行为保持不变） |
| **research** | 技术调研 | fluid | Question → Explore → Findings → Challenge → Conclusion |
| **simple** | 轻量修改 | fluid | 无门禁，直接执行 |
| **openspec-compat** | 兼容已有 OpenSpec 项目 | fluid | Delta-spec 兼容模式 |

其中 ⏸️ 表示**门禁**——Agent 必须停下来等待人类确认（"Plan Approved"）才能继续。这是 `philosophy: strict` Schema 的核心机制，确保人类在关键决策点保持控制权。

Schema 以 YAML 声明式定义，下面是 SDD-RIPER-ONE 的核心结构：

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
    gate:                          # 👈 门禁声明
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

Schema 系统也支持自定义——团队可以在 `.specanchor/schemas/` 下创建自己的写作协议，SpecAnchor 会在启动时自动发现并提供推荐。

### 2.4 Harness 五维度在 SpecAnchor 中的映射

回到 Harness Engineering 的五个维度，SpecAnchor 如何逐一覆盖：

| Harness 维度 | SpecAnchor 实现 | 具体机制 |
|-------------|----------------|---------|
| **上下文工程** | 三级 Spec 分层按需加载 | Global 始终加载（≤200行）+ Module 通过 module-index.md 路径匹配按需加载 |
| **架构约束** | 门禁状态机 + 工作流选择 | Schema 声明 `gate`，`📋/⚡` 检查点，Plan Approved 阻塞 Execute |
| **反馈回路** | specanchor-check 对齐检测 | Task/Module/Global/Coverage 四种检测模式，Git 历史联动 |
| **可观测性** | YAML frontmatter 元数据追踪 | author / created / last_synced / status / sdd_phase 全链路可查 |
| **垃圾回收** | Spec 新鲜度状态机 | FRESH → DRIFTED → STALE（14天）→ OUTDATED（30天），自动检测并报警 |

> **📌 信息图位置 2**：Harness 五维度 × SpecAnchor 映射关系图。可以用"五角雷达图"或"环形仪表盘"展示每个维度的覆盖情况。

---

## 三、核心配置：anchor.yaml

每个使用 SpecAnchor 的项目，都有一个 `anchor.yaml` 作为单一配置入口。它定义了 Spec 的存放路径、运行模式、写作协议、覆盖率扫描范围和新鲜度检测阈值。

```yaml
# anchor.yaml —— SpecAnchor 单一配置入口
specanchor:
  version: "0.4.0"
  project_name: "my-project"

  # 运行模式：full（完整管理）| parasitic（仅治理已有 Spec 系统）
  mode: "full"

  # 路径配置
  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    module_index: ".specanchor/module-index.md"

  # 外部来源（可选）：治理已有的 Spec 系统
  sources:
    - path: "docs/superpowers/specs/"
      type: "custom"
      governance:
        stale_check: true            # 纳入新鲜度追踪
        frontmatter_inject: true     # 自动注入 SpecAnchor 元数据

  # 写作协议
  writing_protocol:
    schema: "sdd-riper-one"          # 默认 Schema
    schema_recommend: true           # 根据任务类型智能推荐

  # 覆盖率扫描
  coverage:
    scan_paths: ["src/**"]
    ignore_paths: ["src/test/**"]

  # 新鲜度检测阈值
  check:
    stale_days: 14                   # 14 天未同步 → STALE
    outdated_days: 30                # 30 天未同步 → OUTDATED
```

### Full 模式 vs Parasitic 模式

SpecAnchor 提供两种运行模式，适配不同的项目阶段：

| 维度 | Full 模式 | Parasitic 模式 |
|------|----------|---------------|
| 适用场景 | 新项目 / 需要完整 Spec 治理的项目 | 已有 Spec 系统的项目（OpenSpec / mydocs / qoder 等） |
| `.specanchor/` 目录 | 完整创建和管理 | 不创建 |
| Global/Module Spec | 创建和维护 | 不创建，仅治理外部 sources |
| Task Spec | 完整工作流 | 不可用 |
| 对齐检测 | 全部模式（task/module/global/coverage） | 仅 source 级扫描和新鲜度检测 |
| 接入成本 | 中等（需初始化 + 逐步补齐 Module Spec） | 极低（配置 sources 即可开始） |

Parasitic 模式的设计哲学是"**先治理，后迁移**"——团队不需要一步到位切换到 SpecAnchor 的完整体系，可以先对已有的 Spec 文件进行 frontmatter 注入和新鲜度追踪，等时机成熟再升级到 Full 模式。

---

## 四、实战案例：知识文档 Diff 生命周期重构

以下基于真实项目 Codify（一个 AI 知识管理工具）中的案例，展示 SpecAnchor + SDD-RIPER-ONE 的完整工作流。任务是：**重构 TopicDocument 组件的文档生命周期，从"展示/预览"升级为以 MarkdownDiffEditor 驱动的"版本迭代"交互。**

这是一个典型的"多文件重构 + 跨组件状态管理 + UI 交互变更"任务，涉及 7 个文件的改动。

### 4.1 启动：工作流选择

当开发者说"重构 TopicDocument 的文档 Diff 生命周期"时，SpecAnchor 执行工作流选择：

```
📋 sdd-riper-one — 多文件重构 + 跨组件状态管理变更，需要完整 RIPER 流程
🔧 specanchor_task — 创建 Task Spec
```

Agent 创建 Task Spec 后输出解锁检查点：

```
🔓 标准流程已激活 — Task Spec:
   .specanchor/tasks/src-app-bloom-knowledge-components-TopicDetail-TopicDocument/
   2026-03-17_topic-document-diff-lifecycle.spec.md
```

注意 Task Spec 的存放路径遵循 Module 路径映射规则（`/` → `-`），这让 Spec 文件与代码模块自然关联。

### 4.2 Research：消除信息差

Agent 自动加载了两份 Module Spec 作为调研输入：

```yaml
related_modules:
  - ".specanchor/modules/src-app-bloom-knowledge-components-TopicDetail.spec.md"
  - ".specanchor/modules/src-components-MarkdownDiffEditor.spec.md"
```

加上 Global Spec 中的编码规范和架构约定，Agent 带着完整的上下文进入 Research 阶段。调研结果写入 Spec 的 `§2. Research Findings`：

**架构现状发现：**

- TopicDetail 三列布局，`useTopicLibraryState` 在 TopicLibrary 内部管理
- `templateOverlay` 使用 `position: absolute` 相对于 `.panelContent`，无法覆盖 header
- mock 数据内嵌在组件文件中（违反关注点分离）

**核心设计洞察——Diff 生命周期状态机：**

```
[空文档] ──传入 diffNewContent──→ [首版 doc]
  (自动: diffNewContent → diffOldContent, 无 diff 显示)

[首版 doc] ──AI 对话输出新 diffNewContent──→ [非首版 diff 模式]
  (diffNewContent vs diffOldContent 做 diff)
  (禁止 TopicChat 继续对话)

  ├── 撤销 → 恢复 diffOldContent, 解锁对话
  └── 应用修改 → diffNewContent 成为 diffOldContent, 解锁对话
```

Research 阶段的关键价值：**它把模糊的"重构文档生命周期"需求，锚定为 5 个精确状态（empty → templateSelection → generating → viewing → diffPending）的状态机设计。**

> **📌 信息图位置 3**：Diff 生命周期状态机流转图。展示 5 个状态之间的转换条件和数据流（diffOldContent / diffNewContent / currentContent）。

### 4.3 Innovate：架构决策

Research 发现一个关键问题：TopicLibrary 的勾选资料数需要传递给 TopicDocument 显示"基于 N 篇来源"，同时 diffPending 状态需要锁定 TopicChat 的输入框。这是跨组件状态共享问题。

Agent 分析后提出方案并记录决策：

**Decision**: 创建 `TopicDetail/context.tsx`，使用 `useReducer` 管理跨组件共享状态。

```typescript
type TopicDetailSharedState = {
    docViewState: DocViewState        // 文档状态
    currentContent: string            // 已确认的版本内容
    diffOldContent: string            // diff 基准
    diffNewContent: string            // AI 或用户编辑的新内容
    checkedSourceCount: number        // TopicLibrary 勾选的资料数
    diffChangeCount: number           // diff 变更数
}
```

这个决策让三个子组件（TopicLibrary / TopicDocument / TopicChat）通过 Context 通信，而非 prop drilling——Module Spec 中定义的接口契约保持清晰。

### 4.4 Plan：施工蓝图 + 门禁

Plan 阶段产出了精确到文件路径和函数签名的实施蓝图：

| 文件 | 变更说明 |
|------|---------|
| `TopicDetail/context.tsx` | **新建**：TopicDetailContext + useReducer |
| `TopicDocument/mockConfig.ts` | **新建**：抽取所有 mock 数据 |
| `TopicDocument/index.tsx` | 重构：改用 Context 驱动状态机 |
| `TopicDocument/index.module.css` | overlay 覆盖整个 panel + 色调变更 |
| `TopicDetail/index.tsx` | 引入 Provider 包裹三列面板 |
| `TopicLibrary/index.tsx` | 通过 Context dispatch 上报勾选数 |

以及一份 15 项原子 Checklist，每一项都是可独立验证的最小单元。

此时 Agent 输出门禁检查点：

```
⏸️ Plan 已就绪，请确认后回复「Plan Approved」继续执行
```

**这就是 Harness 的价值所在。** 你审查的不是 500 行代码，而是一份结构清晰的 Plan 文档——7 个文件的变更说明、类型签名、15 项 Checklist。审查成本从"读懂所有代码"降低为"确认设计意图是否正确"。

### 4.5 Execute：按图施工

收到 `Plan Approved` 后，Agent 按照 Checklist 逐步实施。执行过程中的每一步都记录在 `§5. Execute Log` 中：

```
- [x] Step 1-2: 创建 mockConfig.ts + 重构状态机
- [x] Step 3-5: MarkdownDiffEditor 替换只读编辑器 + diff 生命周期
- [x] Step 6-7: overlay 覆盖范围修复
- [x] Step 8-10: 跨组件资料计数同步
- [x] Step 11-14: 色调 + footer + CSS 清理
- [x] Step 15: Lint 检查
```

执行阶段的铁律：**只实现 Plan 中的内容。** 如果遇到编译错误可以最小修复，但任何逻辑变更必须回退到 Plan 阶段。

### 4.6 Review：对齐检测 + 反向同步

Review 阶段是整个流程的收束。Agent 执行 Spec-Code 对齐检查，并记录 Review Verdict：

```
- Spec coverage: ✅
- Behavior check: ✅
- Regression risk: Medium（状态机重构 + 跨组件数据流变更）
- Module Spec 需更新: Yes
  - TopicDetail.spec.md（新增 checkedSourceCount/isDiffPending 接口）
  - MarkdownDiffEditor.spec.md（更新 TODO 状态）
```

注意最后一项——**Review 不仅检查代码是否符合 Task Spec，还检查 Module Spec 是否需要更新**。这就是三级 Spec 体系的闭环：Task 级变更反哺 Module 级契约，确保团队知识不会因为一次重构而丢失。

> **📌 信息图位置 4**：完整的 Task Spec 文件截图（或关键章节截图），展示从 frontmatter → Open Questions → Research → Innovate → Plan → Execute Log → Review Verdict → Plan-Execution Diff 的完整结构。

### 4.7 案例复盘：Harness 带来了什么

| 如果没有 Harness | 有 SpecAnchor Harness |
|-----------------|----------------------|
| Agent 直接开始改代码，遗漏 overlay 覆盖问题 | Research 阶段发现 positioned ancestor 问题，写入 Spec |
| 跨组件状态方案在对话中"口头决定"，下次忘记 | Innovate 决策持久化，Context 方案可追溯 |
| 15 项改动混在一起，审查时不知从何下手 | Plan 的原子 Checklist 逐项可验证 |
| 改完代码不知道影响了哪些模块接口 | Review 主动标记 Module Spec 需更新 |
| 两周后回来，不知道当时为什么这样设计 | Task Spec 完整记录了决策链和执行日志 |

---

## 五、从零落地：SpecAnchor 实操指南

### 5.1 冷启动：初始化项目

```bash
# 第一步：初始化 SpecAnchor
# Agent 执行 specanchor_init，自动检测已有 Spec 系统
$ specanchor_init

⚙️ 检测到以下已有 Spec 来源：
  - docs/specs/ (OpenSpec 格式)
  - mydocs/ (SDD-RIPER 格式)
是否纳入治理？ [Y/n]

✅ 已创建 anchor.yaml
✅ 已创建 .specanchor/global/（空模板）
✅ 已创建 .specanchor/modules/
✅ 已创建 .specanchor/module-index.md
```

```bash
# 第二步：生成 Global Spec（AI 扫描代码库后提取规范）
$ specanchor_global

🔍 扫描项目代码风格...
✅ 已生成 .specanchor/global/coding-standards.spec.md
✅ 已生成 .specanchor/global/architecture.spec.md
```

### 5.2 渐进式覆盖：Touch-to-Document

SpecAnchor 不要求一次性写全所有 Module Spec。它采用"**触碰即文档化**"策略：

1. 开发者说"开始做 XX 功能"
2. SpecAnchor 检查目标文件是否被 Module Spec 覆盖
3. **如果未覆盖**，自动执行 `specanchor_infer` 从代码逆向推断 Module Spec 草稿
4. 开发者审查并确认后，Module Spec 入库

这意味着 Module Spec 的覆盖率会随着开发自然增长：

| 时间节点 | 预期覆盖率 | 驱动方式 |
|---------|-----------|---------|
| Month 1 | 10-20% | 只覆盖活跃开发的模块 |
| Month 3 | 40-60% | 随 Sprint 任务逐步扩展 |
| Month 6+ | 70%+ | 核心模块基本覆盖 |

### 5.3 对齐检测：specanchor-check

SpecAnchor 提供了 Shell 脚本 `specanchor-check.sh` 进行自动化对齐检测，支持四种模式：

```bash
# $SA_SKILL_DIR = Skill 安装目录（见 SKILL.md「脚本调用约定」）

# Task Spec 检测：检查 Task Spec 的 Checklist 执行情况
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" task <spec-file>

# Module Spec 检测：检查 Module Spec 与代码的新鲜度
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" module <spec-file>
# 输出: FRESH / DRIFTED / STALE / OUTDATED

# Global 概览：全项目 Spec 健康度报告
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" global

# Coverage 检测：哪些代码目录没有 Module Spec 覆盖
bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" coverage
```

新鲜度状态机：

```
FRESH ──(代码变更但 Spec 未更新)──→ DRIFTED
DRIFTED ──(14 天未同步)──→ STALE
STALE ──(30 天未同步)──→ OUTDATED
```

这可以集成到 CI/CD 流程中，作为 MR 合入的门禁条件——确保每次代码变更都有对应的 Spec 更新。

### 5.4 工具链集成

SpecAnchor 是纯文本协议（Markdown + YAML + Shell），不绑定任何特定 IDE：

| 工具 | 集成方式 | 说明 |
|-----|---------|------|
| **Claude Code** | Skill 安装（推荐） | `anchor.yaml` + `.specanchor/` 目录，Skill 自动激活 |
| **Cursor / Windsurf** | `.cursorrules` 引用 | 将 SKILL.md 内容注入 IDE 规则文件 |
| **GitHub Copilot** | `.github/copilot-instructions.md` | 协议内容作为指令注入 |
| **CI/CD** | `specanchor-check.sh` | 作为 MR 门禁脚本集成 |

> **📌 信息图位置 5**：工具链集成架构图。展示 anchor.yaml 作为中心，连接 IDE（Cursor/Claude Code）、CI/CD（specanchor-check.sh 门禁）、Git（frontmatter 追踪）的关系。

---

## 六、与原始 SDD-RIPER 及行业方案的对比

### 6.1 从 SDD-RIPER-ONE 到 SpecAnchor 的演进

| 维度 | SDD-RIPER-ONE（原始协议） | SpecAnchor |
|------|-------------------------|-----------|
| 关注点 | 单任务开发流程 | Spec 生态治理（覆盖率 + 新鲜度 + 多级层次） |
| Spec 层级 | 单一 Spec 文件 | 三级层次化（Global / Module / Task） |
| 上下文管理 | 全量加载协议全文 | 分层按需加载 + Token 预算硬约束（≤200 行 Global） |
| 覆盖率度量 | 无 | coverage 指标 + 自动化报告 |
| 新鲜度追踪 | 无 | frontmatter + Git 历史联动检测 |
| 工作流 | 固定 RIPER 五步 | 可插拔 Schema（6 种内置 + 自定义） |
| 外部系统兼容 | 无 | Parasitic 模式 + sources 配置 |
| 团队标准化 | 手动复制 .cursorrules | `anchor.yaml` 版本化 + Skill 统一分发 |

SpecAnchor **并非替代** SDD-RIPER-ONE，而是将其**纳入为默认 Schema**。RIPER 的五步状态机和门禁机制被完整保留，但运行在一个更大的治理框架中。

### 6.2 与行业方案的定位差异

**vs Cursor Rules / .cursorrules**

- Cursor Rules 是单层约束，等价于 SpecAnchor 的 Global Spec 层
- SpecAnchor 额外提供 Module/Task 两级 + 新鲜度追踪 + 覆盖率度量

**vs CLAUDE.md / AGENTS.md**

- 这些是工具级的"系统指令"文件，通常是静态的、单文件的
- SpecAnchor 是动态的、分层的、有生命周期管理的

**vs OpenAI Codex 的 Harness 实践**

- 理念高度一致——都是将"黄金原则"编码为仓库内的版本化文件
- OpenAI 的实践是内部的、特定于 Codex 的；SpecAnchor 是开源的、工具无关的
- SpecAnchor 提供了现成的脚本工具（check / frontmatter-inject），降低了实操门槛

---

## 七、团队推广路径与常见误区

### 7.1 推荐的渐进式路径

| 阶段 | 时间 | 动作 | 底线 |
|------|------|------|------|
| **启动期** | Week 1-2 | `specanchor_init` + Global Spec + 2-3 个核心模块的 Module Spec | 所有新任务必须创建 Task Spec |
| **爬坡期** | Month 1-2 | 随 Sprint 任务逐步补齐 Module Spec，开始运行 `specanchor_check` | PR 中必须包含 Task Spec 链接 |
| **成熟期** | Month 3+ | `specanchor_check` 接入 CI 门禁，覆盖率目标 > 60% | STALE/OUTDATED Spec 必须在 Sprint 内修复 |

核心原则：**工具会过时，但协议永存**——不强制统一 IDE，但强制统一交付物标准。

### 7.2 常见误区

**误区 1：试图一次性写全所有 Module Spec**

正确做法是"Touch-to-Document"——只在模块首次被修改时创建 Module Spec。渐进式覆盖的成本远低于一次性全量编写，而且基于真实开发场景产出的 Spec 质量更高。

**误区 2：把 Global Spec 写成百科全书**

Global Spec 有 ≤ 200 行的硬约束，因为它每次对话都会加载。它应该是"宪法"而非"法典"——只写最核心的、所有代码都必须遵守的规则。详细的模块级规范应该下沉到 Module Spec。

**误区 3：忽略 Spec 新鲜度**

代码改了但 Spec 没更新，是最常见的腐化模式。`specanchor-check` 的新鲜度检测正是为此设计——14 天未同步标记为 STALE，30 天标记为 OUTDATED。建议将检测接入 CI，让"Spec 腐化"像"测试失败"一样可见。

**误区 4：把 SpecAnchor 视为"文档负担"**

SpecAnchor 的核心观点是 **审 Plan 代替审 Code**。你花 10 分钟审一份 Plan 文档，省下的是花 1 小时审 500 行 AI 生成的代码。Spec 不是额外负担，而是审查效率的倍增器。

---

## 八、总结与展望

### 8.1 核心论点

如果 2025 年的关键词是"AI 能写代码了"，那么 2026 年的关键词就是：

> **Agent 不是难点，Harness 才是。**

SpecAnchor 作为 Harness Engineering 在 Spec 治理维度的落地工具，提供了一套完整的解法：

- **三级 Spec 体系**解决上下文工程——让 Agent 在每次行动前都能"看到"正确的约束
- **可插拔 Schema**解决架构约束——让不同类型的任务走不同的流程，保留人类在关键节点的控制权
- **对齐检测**解决反馈回路——让 Spec 与代码的偏差像测试失败一样可见
- **frontmatter 追踪**解决可观测性——让每份 Spec 的来源、作者、更新时间完整可查
- **新鲜度状态机**解决垃圾回收——让过期 Spec 自动浮出水面

### 8.2 角色进化

Harness Engineering 正在催生一种新的工程角色。你的核心竞争力不再是"写代码的速度"，而是：

- **定义意图的清晰度**——能否用 Spec 精确表达你想要什么
- **设计约束的严谨度**——能否构建让 Agent 可靠工作的 Harness
- **维护 Spec 体系的纪律性**——能否让 Spec 始终与代码保持同步

> **像指挥军团一样指挥 AI，而不是像保姆一样修补代码。**

---

*SpecAnchor 仓库地址：[点这里](https://code.alibaba-inc.com/aone-open-skill/spec-anchor/branches)*
*SpecAnchor Aone 一键安装：[点这里](https://open.aone.alibaba-inc.com/skill/spec-anchor)*
*参考资料：*

- *[Harness engineering: leveraging Codex in an agent-first world | OpenAI](https://openai.com/index/harness-engineering/)*
- *[Harness Engineering | Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)*
- *[Skill Issue: Harness Engineering for Coding Agents | HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents)*
