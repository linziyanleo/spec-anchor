---
specanchor:
  level: task
  task_name: "spec-pipeline-analysis"
  author: "@fanghu"
  created: "2026-04-14"
  status: "done"
  last_change: "用户确认 Action Items 1/2，门禁暂不考虑"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "research"
  research_phase: "EXPLORE"
  branch: "main"
---

# Research: SpecAnchor Spec 链路检查 — 脚本驱动 vs 模型驱动分析

## 1. Research Question
- **核心问题**: 当前 SpecAnchor 项目中，Spec 生命周期的哪些环节由脚本自动化完成，哪些依赖大模型（LLM）阅读和输出？两者的边界是否清晰？
- **调研范围**: 覆盖 Spec 生命周期全链路——创建 → 更新 → 索引 → 检测 → 加载 → 渲染
- **范围边界**: 不评估 Skill 在其他项目中的使用方式，仅分析 Skill 仓库自身的实现
- **成功标准**: 产出一张完整的链路矩阵表，标注每个环节的驱动方式（脚本 / 模型 / 混合），并识别可进一步自动化的机会

## 2. Explore

### 2.1 调研方法
- 代码分析：遍历 `scripts/` 目录所有脚本，分析其输入输出和触发条件
- 命令定义分析：遍历 `references/commands/*.md`，分析每个命令的执行方式
- Skill 协议分析：分析 `SKILL.md` 和 `references/specanchor-protocol.md` 中的流程定义

### 2.2 调研过程

#### 方向 1: 脚本层（scripts/）

| 脚本 | 功能 | 驱动方式 | 输入 | 输出 |
|------|------|----------|------|------|
| `specanchor-boot.sh` | 启动检查：扫描配置、Global Spec、Module Spec、Schema | **纯脚本** | anchor.yaml, .specanchor/ | 结构化摘要（stdout） |
| `specanchor-check.sh` | Spec-Code 对齐检测（task/module/global/coverage） | **纯脚本** | Module Spec frontmatter, git history | 健康度报告（stdout） |
| `specanchor-index.sh` | 生成/更新 module-index.md (v2) | **纯脚本** | .specanchor/modules/*.spec.md, anchor.yaml | .specanchor/module-index.md |
| `frontmatter-inject.sh` | 注入 SpecAnchor YAML frontmatter | **纯脚本** | 任意 .md 文件 | 修改后的 .md 文件 |
| `frontmatter-inject-and-check.sh` | 注入 + 对齐检测组合 | **纯脚本** | .md 文件 | 修改后的文件 + 检测报告 |

**关键发现**: 所有 5 个脚本都是纯脚本驱动，不依赖大模型。它们处理的是结构化数据（YAML frontmatter、git 日期、文件扫描）。

#### 方向 2: 命令层（references/commands/）

| 命令 | 功能 | 驱动方式 | 脚本支撑 | 模型职责 |
|------|------|----------|----------|----------|
| `specanchor_init` | 初始化 .specanchor/ 目录 | **模型** | 无 | 创建目录结构、写入模板文件 |
| `specanchor_global` | 创建/更新 Global Spec | **模型** | 无 | 分析代码 → 编写 Spec 内容 |
| `specanchor_module` | 创建/更新 Module Spec | **混合** | `specanchor-index.sh`（索引更新） | 分析代码 → 编写 Spec 内容 → 调用脚本刷新索引 |
| `specanchor_infer` | 从代码逆向推断 Module Spec | **混合** | `specanchor-index.sh`（索引更新） | 代码阅读 → 推断 → 生成草稿 → 调用脚本刷新索引 |
| `specanchor_task` | 创建 Task Spec | **模型** | 无 | 选择 Schema → 填充模板 → 写入文件 |
| `specanchor_load` | 加载 Spec 到上下文 | **模型** | 无 | 读取文件 → 注入上下文 |
| `specanchor_status` | 显示状态和覆盖率 | **混合** | `specanchor-check.sh`（可选） | 汇总信息 → 格式化输出 |
| `specanchor_check` | Spec-Commit 对齐检测 | **脚本优先** | `specanchor-check.sh` | 调用脚本 → 解读结果 |
| `specanchor_index` | 更新模块索引 | **脚本优先** | `specanchor-index.sh` | 调用脚本 → 确认结果 |
| `specanchor_import` | 从外部框架导入 | **模型** | 无 | 分析外部格式 → 转译 → 生成配置 |

**关键发现**: 
- 纯模型驱动：init、global、task、load、import（5/10）
- 脚本优先：check、index（2/10）
- 混合：module、infer、status（3/10）

#### 方向 3: Skill 协议层

| 协议环节 | 驱动方式 | 说明 |
|----------|----------|------|
| 启动检查 | **脚本优先** | `specanchor-boot.sh` 完成 80% 工作，模型解读输出 |
| Schema Discovery | **脚本** | boot 脚本自动扫描 |
| 工作流选择 | **模型** | 根据任务描述选择 ⚡ 或 📋 |
| 门禁执行 | **模型** | 模型自律，无脚本强制 |
| 上下文加载 | **模型** | Always Load + On-Demand |
| Frontmatter 注入 | **脚本** | `frontmatter-inject.sh` |
| 对齐检测 | **脚本** | `specanchor-check.sh` |
| 索引更新 | **脚本** | `specanchor-index.sh` |
| Spec 内容编写 | **模型** | 代码分析 → Spec 生成 |
| Spec 内容更新 | **模型** | 全量重写 Module Spec |

## 3. Findings

### 3.1 关键事实

1. **脚本层覆盖完整**：5 个脚本覆盖了启动检查、对齐检测、索引生成、Frontmatter 注入四大自动化场景，均为纯脚本实现
2. **模型负责「内容生成」**：Spec 的正文内容（规范描述、架构分析、代码约束）完全由模型生成，这是合理的——脚本无法理解代码语义
3. **模型负责「流程控制」**：工作流选择、门禁执行、阶段推进都由模型自律完成，无脚本强制
4. **混合模式清晰**：module 和 infer 命令中，模型写内容 + 脚本刷索引，职责分明
5. **module-index.md 已完成脚本化**：本轮开发新增的 `specanchor-index.sh` 消除了最后一个需要模型手动维护的结构化数据文件

### 3.2 驱动方式矩阵

| 类别 | 纯脚本 | 脚本优先 | 混合 | 纯模型 |
|------|--------|----------|------|--------|
| scripts/ (5 个) | 5 | — | — | — |
| commands/ (10 个) | — | 2 | 3 | 5 |
| 协议环节 (10 个) | 4 | 1 | — | 5 |

### 3.3 脚本 vs 模型的边界原则

当前项目形成了一个清晰的分工模式：

| 维度 | 脚本驱动 | 模型驱动 |
|------|----------|----------|
| **数据类型** | 结构化（YAML frontmatter、日期、路径） | 非结构化（代码语义、规范描述） |
| **操作类型** | 读取/提取/计算/写入 | 分析/推理/生成 |
| **确定性** | 高（相同输入→相同输出） | 低（上下文依赖） |
| **典型场景** | 健康度计算、索引扫描、格式检测 | 代码分析、Spec 编写、工作流决策 |

### 3.4 潜在改进方向

1. **`specanchor_init` 可半脚本化**：目录结构创建和模板文件复制是确定性操作，可以用脚本完成，只留配置确认给模型
2. **门禁执行缺乏强制手段**：当前完全依赖模型自律。如果模型"忘记"门禁，没有脚本可以阻止。可考虑在 `frontmatter-inject.sh` 中增加门禁状态检查
3. **`specanchor_status` 可完全脚本化**：当前是混合模式，但它的输出（统计数据、覆盖率）都是结构化的，完全可以用脚本实现

### 3.5 未解决的问题
- `specanchor_import` 的转译逻辑是否可以部分模板化？
- 门禁的脚本化强制是否值得引入？（需要权衡灵活性 vs 严格性）

## 4. Challenge & Follow-up

### 4.1 Agent 追问
1. **init 脚本化**：`specanchor_init` 中的目录创建和模板复制是否值得抽成一个 `specanchor-init.sh` 脚本？考虑到 init 只执行一次，ROI 是否足够？
2. **status 脚本化**：如果 `specanchor_status` 完全由脚本实现，那它和 `specanchor-check.sh global` 的区别是什么？是否会导致功能重叠？
3. **门禁强制**：你是否希望引入脚本层面的门禁检查（比如在 frontmatter-inject 时检测 Task Spec 的 status 字段）？还是认为当前模型自律的方式足够？

### 4.2 用户反馈
- `specanchor_init` 半脚本化和 `specanchor_status` 脚本化值得做
- 门禁脚本化暂不考虑

## 5. Conclusion

### 5.1 当前状态评估

SpecAnchor 项目的脚本/模型驱动边界已经相当清晰：

- **脚本层（5 个脚本）**：覆盖所有结构化数据操作（启动、检测、索引、注入），质量成熟，有 81 个 bats 测试覆盖
- **模型层**：负责代码语义分析和 Spec 内容生成，这是 LLM 的核心价值区
- **混合层**：module/infer/status 命令中，模型 + 脚本各司其职

### 5.2 脚本覆盖率

```
Spec 生命周期脚本覆盖率:

创建        [模型] ████████████████████ 100%  (init/global/module/task 内容)
更新        [混合] ████████████░░░░░░░░  60%  (内容=模型, 索引=脚本)
索引        [脚本] ████████████████████ 100%  (specanchor-index.sh ✅)
检测        [脚本] ████████████████████ 100%  (specanchor-check.sh ✅)
启动加载    [脚本] ████████████████████ 100%  (specanchor-boot.sh ✅)
Frontmatter [脚本] ████████████████████ 100%  (frontmatter-inject.sh ✅)
流程控制    [模型] ████████████████████ 100%  (工作流选择/门禁/阶段推进)
```

### 5.3 Action Items
- [x] 1. `specanchor_init` 半脚本化 → 创建 `specanchor-init.sh`
- [x] 2. `specanchor_status` 脚本化 → 创建 `specanchor-status.sh`
- [ ] ~~3. 门禁脚本化~~ → 用户决定暂不引入
