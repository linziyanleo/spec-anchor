# OpenSpec 兼容 Task Spec 模板

此模板为使用 OpenSpec 风格（Fluid 哲学）的用户提供 Task Spec 格式。支持 Delta Specs 增量变更表达。

与 SDD-RIPER-ONE 模板的核心区别：
- 无 RIPER 状态机和阶段门禁
- 使用 Proposal / Delta Specs / Design / Tasks 四段结构
- Delta Specs 用 ADDED / MODIFIED / REMOVED 描述增量变更
- Artifact 之间的依赖关系作为提示，不作为硬性约束

## 模板

```markdown
---
specanchor:
  level: task
  task_name: "<任务名称>"
  author: "<@git_user>"
  created: "<YYYY-MM-DD>"
  status: "draft"                     # draft | in_progress | done | archived
  last_change: "<最近一次变更的简要说明>"
  related_modules:
    - ".specanchor/modules/<module-id>.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "openspec-compat"
  branch: "<branch_name>"
---

# Change: <任务名称>

## Proposal

### Why
<!-- 为什么要做这个变更——背景、动机、用户痛点 -->

### What's Changing
<!-- 变更的范围——影响哪些模块、哪些功能 -->

### Context Sources
- Requirement: `...`
- Design: `...`
- Related: `...`

## Delta Specs

### ADDED Requirements

#### Requirement: <名称>
<使用 SHALL / MUST 规范语描述新增需求>

##### Scenario: <场景名>
- **GIVEN** <前置条件>
- **WHEN** <操作>
- **THEN** <期望结果>

### MODIFIED Requirements

#### Requirement: <名称>
<新的描述>
_(Previously: <旧描述>)_

##### Scenario: <更新的场景名>
- **GIVEN** <前置条件>
- **WHEN** <操作>
- **THEN** <新的期望结果>

### REMOVED Requirements

#### Requirement: <名称>
_(Reason: <移除原因>)_

## Design

### Technical Approach
<!-- 技术方案——架构选型、数据流、关键设计决策 -->

### File Changes
| File | Change |
|------|--------|
| `path/to/file` | 变更说明 |

### Dependencies
<!-- 新增或变更的依赖 -->

## Tasks

- [ ] 1. ...
- [ ] 2. ...
- [ ] 3. ...

## Completion

- [ ] Delta Specs 已验证（ADDED/MODIFIED/REMOVED 均已实现）
- [ ] 代码符合 Global Spec
- [ ] Module Spec 已同步更新（如有变更）
- [ ] 测试覆盖
```

## Delta Specs 使用指南

Delta Specs 是 OpenSpec 的核心概念——用增量方式表达变更，而非重写整个 Spec。

**三个标记的含义**：
- `ADDED`：全新的需求/功能，之前不存在
- `MODIFIED`：对现有需求的修改，必须标注 _(Previously: ...)_ 说明原来是什么
- `REMOVED`：不再需要的需求，必须标注移除原因

**与 Module Spec 的关系**：
- Task 完成后，Delta Specs 中的变更应该反映到关联的 Module Spec 中
- ADDED → 追加到 Module Spec 的对应章节
- MODIFIED → 替换 Module Spec 中的旧描述
- REMOVED → 从 Module Spec 中删除

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
| `writing_protocol` | 否 | 固定为 "openspec-compat" |
| `branch` | 否 | 关联 git 分支名 |
