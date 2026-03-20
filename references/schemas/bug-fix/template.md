# Bug-Fix Task Spec 模板

此模板由 Schema 系统自动引用。适用于 bug 修复任务。

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
  writing_protocol: "bug-fix"
  bugfix_phase: "REPRODUCE"          # REPRODUCE | DIAGNOSE | ROOT_CAUSE | FIX_PLAN | FIX | VERIFY | DONE
  branch: "<branch_name>"
---

# Bug Fix: <任务名称>

## 0. Bug Report
- **报告来源**: （用户反馈 / 测试发现 / 监控告警 / 自测发现）
- **严重程度**: （Critical / High / Medium / Low）
- **影响范围**: ...

## 1. Reproduce
- **复现步骤**:
  1. ...
  2. ...
  3. ...
- **环境**: （浏览器/OS/版本/依赖版本）
- **预期行为**: ...
- **实际行为**: ...
- **复现率**: （必现 / 偶现 / 特定条件下）

## 2. Diagnose
### 2.1 诊断策略
- 添加的日志/print 位置和目的:
  - `path/to/file:line` — 检查 xxx 变量的值
  - `path/to/file:line` — 检查 xxx 函数是否被调用

### 2.2 诊断代码
- 添加的诊断代码清单（修复后需清理）:
  - [ ] `path/to/file` — console.log / print 描述

### 2.3 用户反馈的控制台输出
```
（粘贴用户运行后的控制台输出）
```

### 2.4 证据分析
- 从控制台输出中发现: ...
- 关键线索: ...

## 3. Root Cause
- **根因**: ...
- **证据链**: 
  - 复现步骤 → 诊断输出 → 根因推断
- **相关代码**: `path/to/file:line`
- **为什么之前正常（如回归）**: ...

## 4. Fix Plan
### 4.1 Fix Checklist
- [ ] 1. ...
- [ ] 2. ...
- [ ] 3. ...

### 4.2 File Changes
- `path/to/file`: 变更说明

### 4.3 Risk Assessment
- **回归风险**: Low/Medium/High
- **影响的其他功能**: ...
- **需要额外测试的场景**: ...

## 5. Fix Log
- [ ] Step 1: ...
- [ ] Step 2: ...

## 6. Verify
- [ ] Bug 已修复（按复现步骤验证）
- [ ] 无回归（相关功能正常）
- [ ] 诊断代码已清理（§2.2 中添加的 console.log/print 已移除）
- [ ] Module Spec 是否需更新: Yes/No
- **Follow-ups**: ...
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
| `writing_protocol` | 否 | 写作协议名称（此模板为 "bug-fix"） |
| `bugfix_phase` | 否 | 当前修复阶段 |
| `branch` | 否 | 关联 git 分支名 |
