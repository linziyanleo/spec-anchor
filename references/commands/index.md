# specanchor_index

更新 Module Spec 索引文件 `module-index.md`。索引是 Agent 快速定位模块 Spec 的关键。

**用户可能这样说**: "更新一下模块索引" / "刷新 module-index" / "重新生成模块规范索引"

## 执行

**首选方式**：运行 `scripts/specanchor-index.sh` 脚本一次性完成全部步骤：

```bash
bash "<skill_install_dir>/scripts/specanchor-index.sh"

# 可选参数：
#   --config=<path>    指定配置文件（默认自动查找 anchor.yaml）
#   --output=<path>    指定输出路径（默认 .specanchor/module-index.md）
```

脚本自动执行以下步骤：

1. 扫描 `.specanchor/modules/` 下所有 `.spec.md` 文件
2. 读取每个文件的 frontmatter（提取 `module_path`、`summary`、`status`、`version`、`last_synced`、`owner`）
3. 根据 `anchor.yaml` 的 `check.stale_days` / `check.outdated_days` 和 git 历史计算每个模块的健康度
4. 生成/覆盖 `.specanchor/module-index.md`（v2 格式）

Agent 也可在创建/更新 Module Spec 后直接调用此脚本刷新索引，而非手动编辑 `module-index.md`。

## 输出格式（v2 — YAML frontmatter + Markdown）

v2 格式采用 YAML frontmatter 存储结构化数据，Markdown 正文作为人类可读的渲染视图。脚本读写 frontmatter，人类阅读 Markdown 表格。

```markdown
---
specanchor:
  type: module-index
  generated_at: "2026-04-14T16:00:00"
  module_count: 2
  covered_count: 2
  uncovered_count: 0
  health_summary:
    fresh: 1
    drifted: 1
    stale: 0
    outdated: 0

modules:
  - path: "src/modules/auth"
    spec: "src-modules-auth.spec.md"
    summary: "用户认证与鉴权"
    source: native
    status: active
    version: "2.1.0"
    last_synced: "2026-03-10"
    owner: "@zhangsan"
    health: FRESH

  - path: "src/modules/order"
    spec: "src-modules-order.spec.md"
    summary: "订单生命周期管理"
    source: native
    status: active
    version: "1.0.0"
    last_synced: "2026-02-15"
    owner: "@lisi"
    health: DRIFTED

uncovered:
  - path: "src/modules/payment"
    recent_commits: 12
---

# Module Spec 索引

<!-- 以下由 specanchor_index 从 frontmatter 自动渲染，请勿手动编辑 -->

**统计**: 2 个模块 | 2 已覆盖 | 0 未覆盖 | 健康度: 🟢 1 FRESH 🟡 1 DRIFTED

| 模块路径 | 摘要 | 状态 | 健康度 | 版本 | 最后同步 |
|----------|------|------|--------|------|---------|
| src/modules/auth | 用户认证与鉴权 | ✅ active | 🟢 FRESH | 2.1.0 | 2026-03-10 |
| src/modules/order | 订单生命周期管理 | ✅ active | 🟡 DRIFTED | 1.0.0 | 2026-02-15 |

## 无 Spec 覆盖的模块

| 模块路径 | 近 30 天提交数 | 建议 |
|---------|-------------|------|
| src/modules/payment | 12 | 建议为此模块创建规范 |
```

### 字段说明

**frontmatter 顶层（`specanchor:` 命名空间下）**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | string | 固定值 `module-index`，用于格式识别 |
| `generated_at` | ISO 8601 | 索引生成/更新时间 |
| `module_count` | int | 总模块数（已覆盖 + 未覆盖） |
| `covered_count` | int | 有 Module Spec 的模块数 |
| `uncovered_count` | int | 无 Module Spec 的模块数 |
| `health_summary` | object | 按健康度分组的计数 |

**`modules[]` 数组（每个已覆盖模块一项）**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `path` | string | 模块在项目中的相对路径 |
| `spec` | string | Module Spec 文件名（在 `.specanchor/modules/` 下） |
| `summary` | string | 模块一句话摘要（来自 Module Spec frontmatter） |
| `source` | string | `native`（SpecAnchor 原生）或 `external`（外部来源） |
| `status` | string | Module Spec 状态（`active` / `deprecated`） |
| `version` | string | Module Spec 版本号 |
| `last_synced` | date | 最后一次代码-Spec 同步日期 |
| `owner` | string | 模块负责人 |
| `health` | enum | 健康度：`FRESH` / `DRIFTED` / `STALE` / `OUTDATED` |

**`uncovered[]` 数组（每个未覆盖模块一项）**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `path` | string | 模块路径 |
| `recent_commits` | int | 近 30 天提交数（用于优先级排序） |

### 健康度计算

| 健康度 | 条件 | 图标 |
|--------|------|------|
| `FRESH` | `last_synced` 后模块代码无新提交 | 🟢 |
| `DRIFTED` | `last_synced` 后有新提交，且距今 < `stale_days` | 🟡 |
| `STALE` | 距 `last_synced` ≥ `stale_days` 且 < `outdated_days`，且有新提交 | 🟠 |
| `OUTDATED` | 距 `last_synced` ≥ `outdated_days`，且有新提交 | 🔴 |

阈值来自 `anchor.yaml` 的 `check.stale_days`（默认 14）和 `check.outdated_days`（默认 30）。

### boot 脚本集成

`specanchor-boot.sh` 在启动检查时自动识别 `module-index.md` 的格式：

- **v2 格式**（有 YAML frontmatter 且 `type: module-index`）：提取 `health_summary` 并在启动摘要中展示健康度统计
- **legacy 格式**（纯 Markdown 表格）：识别为旧格式，提示用户运行 `specanchor_index` 迁移
- **不存在**：输出警告，建议创建

### 向后兼容（迁移指南）

如果项目中存在旧格式（纯 Markdown 表格）的 `module-index.md`，运行 `specanchor_index` 会自动迁移到 v2 格式。迁移是无损的——旧格式中的所有模块信息会被保留，并补充 `summary`（从 Module Spec frontmatter 读取）和 `health`（自动计算）。

迁移后 `specanchor-boot.sh` 的启动摘要会从 `legacy (Markdown table)` 变为 `v2 (structured)`，并显示健康度统计。
