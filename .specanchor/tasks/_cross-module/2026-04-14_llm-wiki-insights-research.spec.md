---
specanchor:
  level: task
  task_name: "LLM Wiki 模式对 SpecAnchor 的启示研究"
  author: "@fanghu"
  created: "2026-04-14"
  status: "done"
  last_change: "全部 Action Items 已执行：叙事更新 + module-index 增强 + co-evolve 备忘"
  related_modules:
    - ".specanchor/modules/references.spec.md"
    - ".specanchor/modules/scripts.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "research"
  research_phase: "DONE"
  branch: "main"
---

# Research: LLM Wiki 模式对 SpecAnchor 的启示研究

## 1. Research Question

- **核心问题**: Karpathy 的 LLM Wiki 模式中哪些概念对 SpecAnchor 有实际价值？哪些可以落地到当前 Skill 仓库？
- **调研范围**: LLM Wiki 原文 + 社区评论中的关键延伸（Entity Registry、Caveman 压缩、Spec-to-Spec Lint）
- **范围边界（不调研什么）**: 不调研 RAG/向量搜索等基础设施层面的实现；不调研 Obsidian 集成
- **成功标准**: 产出 ≤ 3 个可落地的 Action Item，每个有明确的实现路径和 ROI 评估
- **决策背景**: SpecAnchor v0.4.0 处于功能稳定期，需要评估是否值得引入新概念扩展能力边界

## 2. Explore

### 2.1 调研方法
- 文档分析：精读 Karpathy LLM Wiki 原文
- 社区反馈分析：筛选评论中有实质性工程洞察的条目
- 架构对比：LLM Wiki 三层架构 vs SpecAnchor 四层架构

### 2.2 调研过程

#### 方向 1: 架构模式对比

**LLM Wiki 三层架构：**

| 层级 | LLM Wiki | SpecAnchor 对应 | 匹配度 |
|------|----------|-----------------|--------|
| Raw Sources | 不可变的原始文档 | 源代码（不可变的分析输入） | 高 |
| Wiki | LLM 生成/维护的结构化 Markdown | `.specanchor/` 下的 Global/Module/Task Spec | 高 |
| Schema | 告诉 LLM 如何维护 Wiki 的配置 | `SKILL.md` + `references/schemas/` | 高 |

**关键差异：**
- LLM Wiki 的 Wiki 层是**开放增长**的（页面数量不受限），SA 的 Spec 层有 token 预算约束（Global ≤ 200 行）
- LLM Wiki 的 Schema 鼓励**人机共同演化**，SA 的 Schema 是**预定义的写作协议**
- LLM Wiki 不区分 Spec 层级（所有页面平等），SA 严格分层（Global > Module > Task）

#### 方向 2: 操作模式对比

| 操作 | LLM Wiki | SpecAnchor 对应 | 差距 |
|------|----------|-----------------|------|
| **Ingest** — 新源 → 更新 Wiki | 读取源文档，提取关键信息，更新多个 Wiki 页面 | `specanchor_infer` — 从代码逆向推断 Module Spec | SA 只更新单个 Spec 文件，不做跨 Spec 级联更新 |
| **Query** — 查询并可回写 | 搜索 Wiki → 合成答案 → 好答案可变成新页面 | `specanchor_load` + on-demand 加载 | SA 无"回写"机制 — 开发对话中的洞察无法流回 Spec |
| **Lint** — 健康检查 | 查矛盾、查孤页、查缺失交叉引用、查过期声明 | `specanchor_check` — 仅 code↔spec 对齐 | SA 缺 spec↔spec 一致性检查 |

#### 方向 3: 社区延伸中的有价值洞察

**wiki-kb 的 Entity Registry（@SonicBotMan）：**
- 问题：LLM 容易为同一概念创建多个略有不同的页面
- 方案：JSON Registry 追踪所有实体的 canonical name + alias
- SA 启示：`module-index.md` 可以强化为类似角色 — 目前只是路径映射表，缺少概念去重和冲突检测

**Caveman 压缩（@JuliusBrussee）：**
- 问题：LLM 产出的 Markdown 有大量 fluff，浪费 token
- 方案：压缩工具剥离冗余词，保留核心语义
- SA 启示：与 SA 的 200 行 token 预算约束高度相关 — 但 SA 已经通过"精写 Global Spec"间接解决此问题，无需额外工具

**Cortex 的 OWL-RL 推理（@abbacusgroup）：**
- 问题：纯文本 Wiki 无法做传递性推理
- 方案：用形式化知识图谱 + SPARQL 做确定性推理
- SA 启示：过于重型，不适合 SA 的"纯 Markdown + Shell"技术栈定位

### 2.3 Karpathy 原文的核心洞察提取

> "The tedious part of maintaining a knowledge base is not the reading or the thinking — it's the bookkeeping."

这句话精准命中了 SpecAnchor 存在的理由。但 SA 目前的"bookkeeping"只覆盖了 code↔spec，没有覆盖 spec↔spec。

> "Good answers can be filed back into the wiki as new pages."

这是 SA 最大的缺口：开发过程中产生的架构决策、trade-off 分析、调试发现，都散落在 Agent 对话历史中，从未回写到 Spec 体系。

> "Lint: contradictions between pages, stale claims, orphan pages, missing cross-references."

SA 的 `specanchor_check` 覆盖了 stale 检测，但缺少：矛盾检测、孤立 Spec 检测、交叉引用完整性检测。

## 3. Findings

### 3.1 关键事实

1. **SpecAnchor 和 LLM Wiki 本质上是同一模式的不同领域实例化** — "Compiled Knowledge" vs "Retrieved Knowledge"。SA 在开发规范领域做到了 Karpathy 在个人知识管理领域提倡的事情。这不是需要"引入"的新概念，而是对 SA 定位的外部验证。

2. **SA 的三个缺口与 LLM Wiki 的三个操作精确对应：**
   - Ingest 级联更新 → SA 缺少跨 Spec 级联（`specanchor_infer` 只写单个文件）
   - Query 回写 → SA 缺少开发洞察回流机制
   - Lint spec↔spec → SA 的 `specanchor_check` 只做 code↔spec

3. **社区工程实践中最有价值的是结构约束（structural invariants），而非自由文本增长。** wiki-kb 的 Entity Registry + Schema Validation 比纯 Markdown 更抗退化。SA 的 YAML frontmatter 已经提供了部分结构约束，可以进一步强化。

### 3.2 对比分析

| 维度 | 原样保持 SA | 引入 LLM Wiki 概念 |
|------|------------|-------------------|
| 系统复杂度 | 低，当前 4 层清晰 | 中等增长，需新增 lint 子命令和 log 文件 |
| 维护成本 | 现有脚本足够 | 需扩展 `specanchor-check.sh` |
| 用户价值 | 已有核心功能可用 | 显著提升 Spec 体系的自洽性和可追溯性 |
| Scope 风险 | 无 | 需严格限定，避免从 Spec 工具膨胀为知识管理平台 |

### 3.3 Trade-offs

**可落地方案 A — Spec Lint（spec↔spec 健康检查）：**
- Pros: 直接填补 SA 最大的功能缺口；与现有 `specanchor_check` 架构天然兼容（加子命令即可）；不改变 SA 的核心定位
- Cons: 需要定义"spec 之间的矛盾"在代码规范领域意味着什么（比知识库领域更难定义）
- ROI: **高** — 实现量小（~100 行 shell），价值大

**可落地方案 B — Activity Log（`.specanchor/log.md`）：**
- Pros: 零侵入（新增一个文件 + 在现有命令中 append 一行）；解决"这个 Spec 是什么时候被谁改的"问题
- Cons: 如果不自动化，依赖 Agent 纪律性 append；如果自动化，需改动所有命令定义
- ROI: **中** — frontmatter 的 `last_change` 已经部分解决，增量价值有限

**可落地方案 C — Decision Capture（开发决策回写）：**
- Pros: 解决"对话中的好洞察散落丢失"问题；LLM Wiki 模式中最有区分度的特性
- Cons: 需要在 RIPER Review 阶段增加门禁逻辑；定义"什么值得回写"是设计难题；可能导致 Spec 膨胀
- ROI: **中低** — 设计复杂度高，短期收益不明确

### 3.4 未解决的问题

1. "Spec 之间的矛盾"在开发规范领域如何定义？（如：Module A 的 Spec 说用 REST，Module B 的 Spec 说用 gRPC，这算矛盾还是正常的技术选型差异？）
2. Activity Log 是否应该由脚本自动生成（从 git log + frontmatter 推算），还是由 Agent 主动 append？
3. Decision Capture 的触发时机和粒度如何控制？

## 4. Challenge & Follow-up
> 此环节由 Agent 向用户追问，目的是激活用户思路、发现盲区、修正调研方向。

### 4.1 Agent 追问

- **追问 1**: 你在实际使用 SA 时，最痛的"bookkeeping"问题是什么？是发现 Module Spec 之间不一致（对应方案 A），还是回顾不了"为什么当时这样设计"（对应方案 B/C），还是其他我没提到的问题？

- **追问 2**: 你对 SA 的定位边界在哪里？如果引入 Decision Capture（方案 C），SA 就不再是纯粹的"规范管理"工具，而是开始涉足"项目记忆"。这个越界你能接受到什么程度？

- **追问 3**: LLM Wiki 的 index.md 是 LLM 导航 Wiki 的核心入口（先读 index → 再深入具体页面）。SA 当前的 `module-index.md` 只是一个路径映射表，缺少一行摘要。是否值得增强 module-index 使其更像 LLM Wiki 的 index？

### 4.2 用户反馈

- **反馈 1（针对追问 1 — Spec Lint）**: "既然真源是 code，为什么要做 spec↔spec 健康检查，而不是继续遵守原先的 code↔spec 健康检查？如无必要，勿增实体。"

  **分析**: 这是一个精准的奥卡姆剃刀。如果每个 Module Spec 都与其对应的代码对齐（code↔spec），那么 Spec 之间的一致性是**派生属性**——它应该被 code↔spec 对齐自然保证，而不需要额外的 spec↔spec 检测层。唯一的例外是 Global Spec 中的规范性声明（"应该用 X 风格"）被 Module Spec 违反，但这更像是 code↔global-spec 的问题，而不是 spec↔spec。**结论：方案 A 被否决，理由充分。**

- **反馈 2（针对追问 2 — Activity Log）**: "Activity Log 现在有 YAML 头进行记录，是不是其实当前 Skill 也已经包含了？"

  **分析**: 确实如此。YAML frontmatter 的 `last_change` + `last_synced` + `version` 已经在每个 Spec 文件内部记录了变更历史。集中式的 `log.md` 要提供增量价值，唯一场景是"跨文件的时间线视图"——但 `git log` 已经提供了。**结论：方案 B 被否决，功能已被现有机制覆盖。**

### 4.3 方向调整（基于追问）

**原 Findings 的三个方案中两个被否决。** 需要重新审视：LLM Wiki 对 SA 的真正价值是什么？

重新思考后，LLM Wiki 对 SA 最有启示的不是"缺什么功能"，而是以下两个维度：

**维度 1 — 叙事定位（Narrative Positioning）**

Karpathy 的文章给了 SA 一个极好的外部叙事框架："Compiled Knowledge vs Retrieved Knowledge"。SA 一直在做的事情——把代码洞察编译为持久化 Spec——就是 Karpathy 说的"the wiki is a persistent, compounding artifact"在开发规范领域的实例。这不是需要"引入"的概念，而是可以用来**重新阐述 SA 的价值主张**的框架。

**维度 2 — module-index.md 增强（低成本、高收益）**

LLM Wiki 的 index.md 是 LLM 导航系统的核心入口："each page listed with a link, a one-line summary"。SA 当前的 `module-index.md` 只有路径映射，缺少一行摘要。增强后可以让 Agent 在启动时更快地定位相关模块，不改变任何架构边界。

**维度 3 — Schema 共演化理念**

LLM Wiki 强调 Schema 应该由"你和 LLM 共同演化"（co-evolve）。SA 的 Schema 当前是预定义的写作协议。虽然已经有 6 个内置 Schema + 用户可扩展，但缺少"基于使用反馈自动调优 Schema"的理念。这可以作为未来演进方向的思考输入，但不需要立即实现。

## 5. Conclusion

### 5.1 Action Items

- [ ] **1. 更新 WHY.md / README.md 的叙事框架**：引入"Compiled vs Retrieved"概念，将 SA 定位为"在 AI 辅助开发领域实现了 LLM Wiki 所倡导的 Compiled Knowledge 模式"。这是纯文档工作，零风险，但能显著提升 SA 对外传达的清晰度。
- [ ] **2. 增强 module-index.md**：在 `specanchor_module` / `specanchor_infer` / `specanchor_index` 命令中，要求输出包含一行摘要（当前只有路径 + 来源 + 状态）。改动范围：命令定义文件 + module-spec-template 中增加 `summary` 字段。
- [ ] **3. 在 mydocs/idea.md 中记录 Schema 共演化理念**：作为未来 v0.5 的探索方向备忘，不立即实现。

### 5.2 最终建议

- **推荐方案**: 仅执行 Action Item 1 和 2，不引入新的架构概念。SA 的核心价值在于"锚定"——保持精简是锚的本质属性。
- **推荐理由**: Karpathy 文章对 SA 的最大价值不是功能启发，而是叙事验证和微调优化。用户的奥卡姆剃刀质疑证明了 SA 当前架构的完备性——该有的都有了（code↔spec 检测、frontmatter 追踪），不该有的不应该硬加。
- **风险提示**: 如果未来 SA 管理的模块数量显著增长（>20），module-index 的一行摘要将成为 Agent 导航效率的关键——届时可以考虑更丰富的索引结构（类似 LLM Wiki 的 index.md）。
- **下一步**: 如需执行 Action Item 1 或 2，建议使用 `simple` Schema 创建轻量 Task Spec。
