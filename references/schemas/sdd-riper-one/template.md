# SDD-RIPER-ONE Task Spec 模板

此模板由 Schema 系统自动引用。与 `references/task-spec-template.md` 变体 1 内容一致。

## 单项目模板

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
  last_change: "<最近一次变更的简要说明>"
  related_modules:
    - ".specanchor/modules/<module-id>.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  flow_type: "standard"               # standard (📋 标准流程) | light (⚡ 轻量流程)
  writing_protocol: "sdd-riper-one"
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

## 1.5 Codemap Used (Feature/Project Index)
- Codemap Mode: `feature` / `project`
- Codemap File: `mydocs/codemap/YYYY-MM-DD_hh-mm_<name>.md`
- Key Index:
  - Entry Points / Architecture Layers: ...
  - Core Logic / Cross-Module Flows: ...
  - Dependencies / External Systems: ...

## 1.6 Context Bundle Snapshot (Lite/Standard)
- Bundle Level: `Lite` / `Standard`
- Bundle File: `mydocs/context/YYYY-MM-DD_hh-mm_<task>_context_bundle.md`
- Key Facts: ...
- Open Questions: ...

## 2. Research Findings
- 事实与约束: ...
- 风险与不确定项: ...

## 2.1 Next Actions
- 下一步动作 1 ...
- 下一步动作 2 ...

## 3. Innovate (Optional: Options & Decision)
### Option A
- Pros: ...
- Cons: ...
### Option B
- Pros: ...
- Cons: ...
### Decision
- Selected: ...
- Why: ...
### Skip (for small/simple tasks)
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
- [ ] 3. ...

## 5. Execute Log
- [ ] Step 1: ...
- [ ] Step 2: ...

## 6. Review Verdict
- Spec coverage: PASS/FAIL
- Behavior check: PASS/FAIL
- Regression risk: Low/Medium/High
- Module Spec 需更新: Yes/No（如 Yes 列出原因）
- Follow-ups: ...

## 7. Plan-Execution Diff
- Any deviation from plan: ...
```

## 多项目模板

多项目模板与单项目模板的差异在于增加 `§0.1 Project Registry`、`§0.2 Multi-Project Config`、`§4.4 Contract Interfaces`、`§6.1 Touched Projects` 等段落。使用 `mode=multi_project` 时自动切换。

详见 `references/task-spec-template.md` 中的多项目模板。

## Frontmatter 字段说明

| 字段 | 必须 | 说明 |
|------|------|------|
| `level` | 是 | 固定为 `task` |
| `task_name` | 是 | 任务中文名 |
| `author` | 是 | 创建者 |
| `assignee` | 否 | 执行者 |
| `reviewer` | 否 | 审批人 |
| `created` | 是 | 创建日期 |
| `status` | 是 | 任务状态 |
| `last_change` | 否 | 最近一次变更的简要说明 |
| `related_modules` | 否 | 关联 Module Spec 路径列表 |
| `related_global` | 否 | 引用的 Global Spec 路径列表 |
| `writing_protocol` | 否 | 写作协议名称（默认 "sdd-riper-one"） |
| `sdd_phase` | 否 | 当前 RIPER 阶段 |
| `branch` | 否 | 关联 git 分支名 |
