# Task Spec 模板

提供两个变体：**SDD-RIPER-ONE 模式**（集成写作协议时）和**简化模式**（独立运行时）。

## 变体 1：SDD-RIPER-ONE 模式

```markdown
---
specanchor:
  level: task
  task_name: "<任务名称>"
  author: "<@git_user>"
  assignee: "<@git_user>"
  reviewer: "<@git_user>"
  created: "<YYYY-MM-DD>"
  status: "draft"                     # draft | in_progress | review | done | archived
  related_modules:
    - "<module_path>/MODULE.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  sdd_phase: "RESEARCH"              # RESEARCH | INNOVATE | PLAN | EXECUTE | REVIEW | DONE
  branch: "<branch_name>"
---

# SDD Spec: <任务名称>

## 0. Open Questions
- [ ] None

## 1. Requirements (Context)
- **Goal**: ...
- **In-Scope**: ...
- **Out-of-Scope**: ...

## 1.1 Context Sources
- Requirement Source: `...`
- Design Refs: `...`
- Chat/Business Refs: `...`
- Extra Context: `...`

## 1.5 Codemap Used
- Codemap Mode: `feature` / `project`
- Codemap File: `...`

## 1.6 Context Bundle Snapshot
- Bundle Level: `Lite` / `Standard`
- Key Facts: ...

## 2. Research Findings
- 事实与约束: ...
- 风险与不确定项: ...

## 2.1 Next Actions
- ...

## 3. Innovate (Optional)
### Skip
- Skipped: true/false
- Reason: ...

## 4. Plan (Contract)
### 4.1 File Changes
- `path/to/file`: 变更说明

### 4.2 Signatures
- `fn/class signature`: ...

### 4.3 Implementation Checklist
- [ ] 1. ...
- [ ] 2. ...

## 5. Execute Log
- [ ] Step 1: ...

## 6. Review Verdict
- Spec coverage: PASS/FAIL
- Behavior check: PASS/FAIL
- Regression risk: Low/Medium/High
- Module Spec 需更新: Yes/No（如 Yes 列出原因）

## 7. Plan-Execution Diff
- Any deviation from plan: ...
```

## 变体 2：简化模式（无 SDD-RIPER-ONE）

```markdown
---
specanchor:
  level: task
  task_name: "<任务名称>"
  author: "<@git_user>"
  created: "<YYYY-MM-DD>"
  status: "draft"                     # draft | in_progress | done | archived
  related_modules:
    - "<module_path>/MODULE.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
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
| `task_name` | 是 | 任务中文名 |
| `author` | 是 | 创建者 |
| `assignee` | 否 | 执行者（SDD 模式） |
| `reviewer` | 否 | 审批人（SDD 模式） |
| `created` | 是 | 创建日期 |
| `status` | 是 | 任务状态 |
| `related_modules` | 否 | 关联 Module Spec 路径列表 |
| `related_global` | 否 | 引用的 Global Spec 路径列表 |
| `sdd_phase` | 否 | 当前 RIPER 阶段（仅 SDD 模式） |
| `branch` | 否 | 关联 git 分支名 |

## 路径规则

- 单模块任务 → `.specanchor/tasks/<module_name>/YYYY-MM-DD_<task>.spec.md`
- 跨模块任务 → `.specanchor/tasks/_cross-module/YYYY-MM-DD_<task>.spec.md`
- 完成后归档 → `.specanchor/archive/YYYY-MM/<module_name>/`
