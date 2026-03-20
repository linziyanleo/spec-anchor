# Research Task Spec 模板

此模板由 Schema 系统自动引用。适用于技术调研、方案评估、可行性研究等不产出代码的调研任务。

## 模板

```markdown
---
specanchor:
  level: task
  task_name: "<任务名称>"
  author: "<@git_user>"
  created: "<YYYY-MM-DD>"
  status: "draft"                     # draft | in_progress | review | done | archived
  last_change: "<最近一次变更的简要说明>"
  related_modules:
    - ".specanchor/modules/<module-id>.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "research"
  research_phase: "QUESTION"         # QUESTION | EXPLORE | FINDINGS | CHALLENGE | CONCLUSION | DONE
  branch: "<branch_name>"
---

# Research: <任务名称>

## 1. Research Question
- **核心问题**: ...
- **调研范围**: ...
- **范围边界（不调研什么）**: ...
- **成功标准（什么算调研完成）**: ...
- **决策背景**: ...

## 2. Explore
### 2.1 调研方法
- （文档阅读 / 代码分析 / 原型实验 / 竞品对比 / 专家咨询 / ...）

### 2.2 调研过程
#### 方向 1: <名称>
- 调研内容: ...
- 关键发现: ...
- 数据/证据: ...

#### 方向 2: <名称>
- 调研内容: ...
- 关键发现: ...
- 数据/证据: ...

### 2.3 实验/原型（如有）
- 实验目的: ...
- 实验方法: ...
- 实验结果: ...

## 3. Findings
### 3.1 关键事实
1. ...
2. ...
3. ...

### 3.2 对比分析（如有多方案）
| 维度 | 方案 A | 方案 B | 方案 C |
|------|--------|--------|--------|
| ... | ... | ... | ... |

### 3.3 Trade-offs
- **方案 A**: Pros: ... / Cons: ...
- **方案 B**: Pros: ... / Cons: ...

### 3.4 未解决的问题
- ...

## 4. Challenge & Follow-up
> 此环节由 Agent 向用户追问，目的是激活用户思路、发现盲区、修正调研方向。

### 4.1 Agent 追问
- 追问 1: ...
- 追问 2: ...
- 追问 3: ...

### 4.2 用户反馈
- 反馈 1: ...
- 反馈 2: ...

### 4.3 方向调整（基于追问）
- 需要补充调研的方向: ...
- 需要修正的结论: ...

## 5. Conclusion
### 5.1 Action Items
- [ ] 1. ...
- [ ] 2. ...

### 5.2 最终建议
- **推荐方案**: ...
- **推荐理由**: ...
- **风险提示**: ...
- **下一步**: （如启动实现，建议使用 sdd-riper-one Schema 创建新的 Task Spec）
```

## Frontmatter 字段说明

| 字段 | 必须 | 说明 |
|------|------|------|
| `level` | 是 | 固定为 `task` |
| `task_name` | 是 | 任务名称 |
| `author` | 是 | 创建者 |
| `created` | 是 | 创建日期 |
| `status` | 是 | 任务状态 |
| `last_change` | 否 | 最近一次变更的简要说明 |
| `related_modules` | 否 | 关联 Module Spec 路径列表 |
| `related_global` | 否 | 引用的 Global Spec 路径列表 |
| `writing_protocol` | 否 | 写作协议名称（此模板为 "research"） |
| `research_phase` | 否 | 当前调研阶段 |
| `branch` | 否 | 关联 git 分支名 |
