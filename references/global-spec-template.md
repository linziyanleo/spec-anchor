# Global Spec 模板

> **约束**：所有 Global Spec 文件合计不超过 200 行。每个文件控制在 50 行内。

## coding-standards.spec.md

```markdown
---
specanchor:
  level: global
  type: coding-standards
  version: "1.0.0"
  author: "<git_user>"
  reviewers: []
  last_synced: "<today>"
  applies_to: "**/*.{ts,tsx,js,jsx}"
---

# 编码规范

## 技术栈
- 框架/语言/运行时：...
- 状态管理：...
- 样式方案：...
- 请求层：...

## 命名约定
- 组件/模块目录：...
- 文件命名：...
- 常量/类型：...

## 代码约定
- 组件编写规则：...
- 错误处理：...
- 副作用收敛：...

## Git 提交约定
- 格式：`<type>(<scope>): <subject>`
- type 枚举：...

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
```

## architecture.spec.md

```markdown
---
specanchor:
  level: global
  type: architecture
  version: "1.0.0"
  author: "<git_user>"
  reviewers: []
  last_synced: "<today>"
  applies_to: "**/*"
---

# 架构约定

## 目录结构约定
- 按功能/模块组织 vs 按技术层组织：...
- 入口文件约定：...

## 模块边界规则
- 模块间通信方式：...
- 禁止直接引用的路径：...

## 数据流约定
- 请求链路：...
- 状态管理边界：...

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
```

## design-system.spec.md

```markdown
---
specanchor:
  level: global
  type: design-system
  version: "1.0.0"
  author: "<git_user>"
  reviewers: []
  last_synced: "<today>"
  applies_to: "**/*.{tsx,jsx,css,scss}"
---

# 设计系统规则

## 色值
- 仅使用 Design Token：...

## 字号 & 间距
- 字号枚举：...
- 间距倍数：...

## 组件样式
- 圆角/阴影/边框规则：...

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
```

## api-conventions.spec.md

```markdown
---
specanchor:
  level: global
  type: api-conventions
  version: "1.0.0"
  author: "<git_user>"
  reviewers: []
  last_synced: "<today>"
  applies_to: "**/*.{ts,js}"
---

# API 设计约定

## 请求封装
- 统一请求函数/路径：...
- 禁止直接使用 fetch/axios：...

## 响应类型
- 类型定义存放位置：...
- 错误处理约定：...

## 接口命名
- RESTful 规则：...
- 版本策略：...

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
```
