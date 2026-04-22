# Module Spec 模板

> 文件名格式为 `<module-id>.spec.md`，集中存放在 `.specanchor/modules/` 目录下。
> `module-id` 由模块路径生成，规则：路径分隔符替换为 `-`，例如 `src/modules/auth` → `src-modules-auth.spec.md`。
> `module_path` 可为目录或单文件路径。

```markdown
---
specanchor:
  level: module
  module_name: "<模块中文名>"
  module_path: "<模块相对路径>"
  version: "1.0.0"
  owner: "<@git_user>"
  author: "<@git_user>"
  reviewers: []
  created: "<YYYY-MM-DD>"
  updated: "<YYYY-MM-DD>"
  last_synced: "<YYYY-MM-DD>"
  last_change: "<最近一次变更的简要说明>"
  status: "draft"                    # draft | review | active | deprecated | archived
  depends_on:                        # 依赖的其他模块路径
    - "<path/to/dep1>"
    - "<path/to/dep2>"
---

# <模块中文名> (<English Name>)

## 1. 模块职责
- 职责 1
- 职责 2
- 职责 3

## 2. 业务规则
- 规则 1（附数值约束）
- 规则 2
- 规则 3

## 3. 对外接口契约

### 3.1 导出 API
| 函数/组件 | 签名 | 说明 |
|-----------|------|------|
| `functionName()` | `(args) => ReturnType` | 用途 |

### 3.2 内部状态
| Store/Context | 字段 | 说明 |
|---------------|------|------|
| `storeName` | `field: Type` | 用途 |

### 3.3 API 端点（如有）
| 方法 | 路径 | 用途 |
|------|------|------|
| GET | `/api/...` | 说明 |

## 4. 模块内约定
- 错误类型约定
- 存储约定
- 校验规则约定

## 5. 已知约束 & 技术债
- [ ] 约束/技术债 1（#issue-xxx）
- [ ] 约束/技术债 2

## 6. TODO
- [ ] 待办 1 @owner
- [x] 已完成项 @owner (日期)

## 7. 代码结构
- **入口**: `<path>/index.ts`（目录级）或 `<path>`（单文件级）
- **核心链路**: `A → B → C → D`
- **数据流**: `输入 → 处理 → 输出`
- **关键文件**:
  | 文件 | 职责 |
  |------|------|
  | `file1.ts` | 职责 |
  | `file2.ts` | 职责 |
- **外部依赖**: `dep1`、`dep2`
```

## Frontmatter 字段说明

| 字段 | 必须 | 说明 |
|------|------|------|
| `level` | 是 | 固定为 `module` |
| `module_name` | 是 | 模块中文名 |
| `module_path` | 是 | 模块相对路径边界（目录或单文件，从项目根开始） |
| `version` | 是 | 语义化版本，更新时 minor +1 |
| `owner` | 是 | 当前负责人（@ + git 用户名） |
| `author` | 是 | 创建者 |
| `reviewers` | 否 | 审批人列表 |
| `created` | 是 | 创建日期 |
| `updated` | 是 | 最后更新日期 |
| `last_synced` | 是 | 最后一次 Spec-代码同步日期 |
| `last_change` | 否 | 最近一次变更的简要说明（单行） |
| `status` | 是 | 生命周期状态 |
| `depends_on` | 否 | 依赖的其他模块路径列表 |

## Module ID 生成规则

模块路径 → Module ID → 文件名：

```
src/modules/auth       → src-modules-auth       → src-modules-auth.spec.md
src/components/LoginForm → src-components-LoginForm → src-components-LoginForm.spec.md
src/pages/home.tsx     → src-pages-home.tsx     → src-pages-home.tsx.spec.md
packages/shared/utils  → packages-shared-utils  → packages-shared-utils.spec.md
```

规则：将路径中的 `/` 替换为 `-`，保持大小写。

## Status 生命周期

```
Draft ──→ Review ──→ Active ──→ Deprecated ──→ Archived
  ↑          │
  └──────────┘
  (Review 未通过)
```
