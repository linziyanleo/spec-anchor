# Task Spec 模板

> **⚠️ DEPRECATED**：本文件已废弃。Task Spec 模板现由 Schema 系统管理：
>
> - SDD-RIPER-ONE 模板 → `references/schemas/sdd-riper-one/template.md`
> - 简化模板 → `references/schemas/simple/template.md`
> - Schema 系统说明 → `references/specanchor-protocol.md` §4.1
>
> 本文件保留仅供历史参考，不再被 `specanchor_task` 使用。

提供两个变体：**SDD-RIPER-ONE 模式**（默认）和**简化模式**（独立运行时）。

## 变体 1：SDD-RIPER-ONE 模式（默认）

基于 SDD-RIPER-ONE spec-template.md，增加 SpecAnchor frontmatter。

### 单项目模板

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
  branch: "<branch_name>"
---

# SDD Spec: <任务名称>

> Current RIPER Phase: RESEARCH

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
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: Yes/No
  - 新发现的项目规则: ...（如有，建议写入哪个 Global Spec）
  - 值得记录的反模式: ...（如有）
- Follow-ups: ...

## 7. Plan-Execution Diff
- Any deviation from plan: ...
```

### 多项目模板（`mode=multi_project` 时使用）

```markdown
---
specanchor:
  level: task
  task_name: "<任务名称>"
  author: "<@git_user>"
  assignee: "<@git_user>"
  reviewer: "<@git_user>"
  created: "<YYYY-MM-DD>"
  status: "draft"
  last_change: "<最近一次变更的简要说明>"
  related_modules:
    - ".specanchor/modules/<module-id>.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  branch: "<branch_name>"
---

# SDD Spec: <任务名称>

> Current RIPER Phase: RESEARCH

## 0. Open Questions
- [ ] None

## 0.1 Project Registry
| project_id | project_path | project_type | marker_file |
|---|---|---|---|
| web-console | ./web-console | typescript | package.json |
| api-service | ./api-service | java | pom.xml |

## 0.2 Multi-Project Config
- **workdir**: `./`
- **active_project**: `web-console`
- **active_workdir**: `./web-console`
- **change_scope**: `local`
- **related_projects**: `api-service`

## 1. Requirements (Context)
- **Goal**: ...
- **In-Scope**: ...
- **Out-of-Scope**: ...

## 1.1 Context Sources
- Requirement Source: `...`
- Design Refs: `...`
- Chat/Business Refs: `...`
- Extra Context: `...`

## 1.5 Codemap Used (Per-Project Index)
### web-console
- Codemap File: `mydocs/codemap/YYYY-MM-DD_hh-mm_web-console项目总图.md`
- Key Index: ...

### api-service
- Codemap File: `mydocs/codemap/YYYY-MM-DD_hh-mm_api-service项目总图.md`
- Key Index: ...

## 1.6 Context Bundle Snapshot (Lite/Standard)
- Bundle Level: `Lite` / `Standard`
- Bundle File: `mydocs/context/YYYY-MM-DD_hh-mm_<task>_context_bundle.md`
- Key Facts: ...
- Open Questions: ...

## 2. Research Findings
- 事实与约束: ...
- 风险与不确定项: ...
- 跨项目依赖关系: ...

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
### 4.1 File Changes (grouped by project)
#### [web-console]
- `src/pages/release.tsx`: 变更说明

#### [api-service]
- `src/main/java/.../ReleaseController.java`: 变更说明

### 4.2 Signatures (grouped by project)
#### [web-console]
- `function triggerRelease(config: ReleaseConfig): Promise<Result>`: ...

#### [api-service]
- `public ResponseEntity<Result> release(ReleaseRequest req)`: ...

### 4.3 Implementation Checklist (grouped by project, dependency order)
#### [api-service] (provider first)
- [ ] 1. ...
- [ ] 2. ...

#### [web-console] (consumer second)
- [ ] 3. ...
- [ ] 4. ...

### 4.4 Contract Interfaces (cross-project only)
| Provider | Interface / API | Consumer(s) | Breaking Change? | Migration Plan |
|---|---|---|---|---|
| api-service | `POST /api/release` | web-console | No | N/A |

## 5. Execute Log (grouped by project)
#### [api-service]
- [ ] Step 1: ...

#### [web-console]
- [ ] Step 2: ...

## 6. Review Verdict
- Spec coverage: PASS/FAIL
- Behavior check: PASS/FAIL
- Regression risk (per project):
  - web-console: Low/Medium/High
  - api-service: Low/Medium/High
- Cross-project consistency: PASS/FAIL
- Module Spec 需更新: Yes/No（如 Yes 列出原因）
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: Yes/No
  - 新发现的项目规则: ...（如有，建议写入哪个 Global Spec）
  - 值得记录的反模式: ...（如有）
- Follow-ups: ...

## 6.1 Touched Projects
| project_id | Files Changed | Reason |
|---|---|---|
| api-service | `ReleaseController.java` | 新增发布接口 |
| web-console | `release.tsx` | 对接发布接口 |

## 7. Plan-Execution Diff
- Any deviation from plan: ...
- Orphan changes (files outside registered projects): None
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
  last_change: "<最近一次变更的简要说明>"
  related_modules:
    - ".specanchor/modules/<module-id>.spec.md"
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
| `last_change` | 否 | 最近一次变更的简要说明（单行） |
| `related_modules` | 否 | 关联 Module Spec 路径列表 |
| `related_global` | 否 | 引用的 Global Spec 路径列表 |
| `branch` | 否 | 关联 git 分支名 |

SDD 模式当前 RIPER 阶段写在正文 marker 中：`> Current RIPER Phase: RESEARCH`。

## 路径规则

- 单模块任务 → `.specanchor/tasks/<module_name>/YYYY-MM-DD_<task>.spec.md`
- 跨模块任务 → `.specanchor/tasks/_cross-module/YYYY-MM-DD_<task>.spec.md`
- 完成后归档 → `.specanchor/archive/YYYY-MM/<module_name>/`

## 写作协议替换说明

SpecAnchor 默认内置 SDD-RIPER-ONE 作为 Task Spec 的写作模板。如需替换为其他写作协议（如 SPECLAN、IntentSpec 等），只需：

1. 将变体 1 的正文部分（`---` 之后）替换为目标协议的模板格式
2. 保留 SpecAnchor 的 YAML frontmatter（`specanchor:` 部分）不变
3. 在 SKILL.md 中更新写作协议的引用说明
