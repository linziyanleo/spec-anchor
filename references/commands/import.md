# specanchor_import

从外部 SDD 框架（当前支持 OpenSpec）扫描配置和目录结构，自动生成 SpecAnchor 的 `sources` 映射配置。

**用户可能这样说**: "导入 OpenSpec 配置" / "兼容 OpenSpec" / "从 OpenSpec 迁移" / "把 openspec 的文件接入 SpecAnchor"

## 参数

- `source_type`（必须，从用户意图推断）: 目前仅支持 `openspec`
- `source_dir`（可选）: 来源目录路径，默认根据 `source_type` 推断（OpenSpec 默认 `openspec/`）

## 执行

1. **扫描来源目录**
   - 检查 `<source_dir>` 是否存在。不存在 → 报错：`目录 <source_dir> 不存在`
   - 读取来源配置文件（OpenSpec: `<source_dir>/config.yaml`）

2. **分析来源结构**（source_type = openspec 时）
   - 读取 `openspec/config.yaml`
     - 提取 `schema` 字段 → 记录使用的工作流（如 `spec-driven`）
     - 提取 `context` 字段 → 准备转译为 Global Spec
     - 提取 `rules` 字段 → 准备合并建议
   - 扫描 `openspec/specs/` → 统计模块数量和名称列表
   - 扫描 `openspec/changes/` → 统计变更数量，区分活跃变更和已归档变更
   - 尝试将 spec 目录名与 `coverage.scan_paths` 中的模块路径匹配

3. **输出分析报告**

   ```
   🔧 specanchor_import — 从 OpenSpec 导入配置

   检测到 OpenSpec 配置：
     目录: openspec/
     Schema: spec-driven
     Specs: 5 个模块（auth, payments, ui, search, orders）
     Changes: 15 个变更（12 active, 3 archived）
     Context: 有（约 200 字）
     Rules: 2 条
   ```

4. **生成 sources 配置建议**

   ```
   建议的 anchor.yaml 变更：
   ┌──────────────────────────────────────────────────────┐
   │ sources:                                              │
   │   - path: "openspec/specs"                            │
   │     type: "openspec"                                  │
   │     maps_to: module_specs                             │
   │     file_pattern: "**/spec.md"                        │
   │     governance:                                       │
   │       stale_check: true                               │
   │       frontmatter_inject: false                       │
   │       scan_on_init: true                              │
   │                                                       │
   │   - path: "openspec/changes"                          │
   │     type: "openspec"                                  │
   │     maps_to: task_specs                               │
   │     file_pattern: "*"                                 │
   │     exclude: ["archive"]                              │
   │     governance:                                       │
   │       stale_check: true                               │
   │       frontmatter_inject: false                       │
   │       scan_on_init: true                              │
   └──────────────────────────────────────────────────────┘
   ```

5. **确认写入**
   - 询问用户：`是否将以上配置写入 anchor.yaml？`
   - 用户确认 → 追加 `sources` 到 anchor.yaml
   - 用户拒绝 → 提示可手动编辑 anchor.yaml

6. **可选：转译 context 为 Global Spec**
   - 询问用户：`是否将 OpenSpec 的 context 转译为 Global Spec？`
   - 用户确认 → 执行以下步骤：
     - 解析 `context` 字段的自由文本
     - 按 `references/global-spec-template.md` 的 `project-setup` 类型结构化
     - 将 `rules` 字段的内容合并到 `coding-standards.spec.md`（如果已存在则追加建议章节）
     - 输出草稿供用户 Review，不直接写入

7. **更新 module-index.md**
   - 将外部来源的模块信息追加到 `module-index.md`（标注 `来源: source:openspec`）

## OpenSpec context 转译示例

**输入**（OpenSpec config.yaml 的 context）：

```yaml
context: |
  Project: E-commerce Platform
  Stack: React 18, Node.js 20, PostgreSQL 16
  Style: TailwindCSS 3.4
  State: Zustand for client, React Query for server state
  API: REST, all endpoints under /api/v1
  Auth: JWT with refresh tokens
```

**输出**（Global Spec 草稿）：

```markdown
---
specanchor:
  level: global
  type: project-setup
  version: "1.0.0"
  author: "@imported-from-openspec"
  last_synced: "2026-03-19"
---

# 项目配置 (Project Setup)

## 1. 项目信息
- 名称：E-commerce Platform
- 技术栈：React 18 + Node.js 20 + PostgreSQL 16

## 2. 技术栈约定
- 框架：React 18
- 样式方案：TailwindCSS 3.4
- 状态管理：Zustand（客户端状态）/ React Query（服务端状态）
- API 风格：REST，所有端点在 /api/v1 下
- 认证方案：JWT + Refresh Token

## 变更日志
| 日期 | 变更 | 作者 |
|------|------|------|
| 2026-03-19 | 从 OpenSpec context 转译生成 | @imported-from-openspec |
```
