# Simple Task Spec 模板

此模板由 Schema 系统自动引用。适用于简单任务的轻量级 Spec 记录。

## 单项目模板

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
  writing_protocol: "simple"
  branch: "<branch_name>"
---

# Task: <任务名称>

## 目标
...

## 范围
- **In-Scope**: ...
- **Out-of-Scope**: ...

## 改动计划
| 文件 | 变更说明 |
|------|---------|
| `path/to/file1` | 说明 |
| `path/to/file2` | 说明 |

## Checklist
- [ ] 1. ...
- [ ] 2. ...

## 完成确认
- [ ] 代码符合 Global Spec
- [ ] Module Spec 已同步更新（如有变更）
- [ ] 测试覆盖

## 备注
...
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
| `writing_protocol` | 否 | 写作协议名称（此模板为 "simple"） |
| `branch` | 否 | 关联 git 分支名 |
