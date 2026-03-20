# Refactor Task Spec 模板

此模板由 Schema 系统自动引用。适用于代码重构任务。

**核心约束：外部行为必须保持不变。**

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
  writing_protocol: "refactor"
  refactor_phase: "MEASURE"          # MEASURE | IDENTIFY | PLAN | EXECUTE | VERIFY | DONE
  branch: "<branch_name>"
---

# Refactor: <任务名称>

> ⚠️ 核心约束：外部行为必须保持不变

## 0. Refactor Motivation
- **动机**: （技术债 / 可维护性 / 可测试性 / 性能 / 架构演进）
- **触发原因**: ...

## 1. Measure
### 1.1 当前代码指标
- **复杂度**: （圈复杂度 / 函数长度 / 类大小）
- **重复代码**: ...
- **耦合度**: ...
- **代码气味**: ...

### 1.2 测试覆盖现状
- **已有测试**: ...
- **覆盖率**: ...
- **可作为行为基准的测试**: ...

## 2. Identify
### 2.1 重构目标
| 目标代码 | 问题 | 预期改善 |
|----------|------|----------|
| `path/to/file` | 描述 | 描述 |

### 2.2 重构策略
- **重构类型**: （提取函数 / 拆分类 / 消除重复 / 简化条件 / 引入设计模式 / ...）
- **重构范围**: ...
- **不动的部分**: ...

## 3. Refactor Plan
### 3.1 Refactor Checklist
- [ ] 1. ...（每步应可独立验证行为不变）
- [ ] 2. ...
- [ ] 3. ...

### 3.2 File Changes
- `path/to/file`: 变更说明

### 3.3 Behavior Preservation Strategy
- **验证方式**: （现有测试 / 手动验证 / 新增测试）
- **回滚策略**: ...

## 4. Execute Log
- [ ] Step 1: ...
  - 行为验证: PASS/FAIL
- [ ] Step 2: ...
  - 行为验证: PASS/FAIL

## 5. Verify
### 5.1 行为不变确认
- [ ] 所有现有测试通过
- [ ] 手动验证关键路径正常
- [ ] 无外部行为变更

### 5.2 指标改善对比
| 指标 | 重构前 | 重构后 | 改善 |
|------|--------|--------|------|
| ... | ... | ... | ... |

### 5.3 Module Spec 更新
- Module Spec 是否需更新: Yes/No
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
| `writing_protocol` | 否 | 写作协议名称（此模板为 "refactor"） |
| `refactor_phase` | 否 | 当前重构阶段 |
| `branch` | 否 | 关联 git 分支名 |
