# SpecAnchor 核心协议

## §1 启动检查流程

Skill 激活时，按以下顺序执行：

```
1. 检查 .specanchor/ 是否存在
   ├─ 不存在 → 报错阻塞，引导用户初始化
   └─ 存在 → 继续
2. 读取 .specanchor/config.yaml
   ├─ 不存在 / 格式错误 → 报错，提供默认配置模板
   └─ 合法 → 继续
3. 读取 .specanchor/global/ 下的所有 .spec.md 文件
   ├─ 目录为空 → 警告：无 Global Spec，建议用户生成全局规范
   └─ 有文件 → 全量加载（合计 ≤ 200 行）
4. 发现可用 Schema（Schema Discovery）
   ├─ 扫描 .specanchor/schemas/*/schema.yaml（项目自定义，标记为 [custom]，优先级更高）
   ├─ 扫描 references/schemas/*/schema.yaml（Skill 内置）
   ├─ 对每个 schema.yaml，读取 name、description、match.when（如有）
   ├─ 合并列表：自定义 Schema 在前，内置 Schema 在后
   └─ 无 Schema 目录或结果为空 → 使用 sdd-riper-one 作为唯一可用 Schema
5. 输出加载状态摘要
```

加载状态摘要格式：

```
SpecAnchor 已加载
  Global Specs: coding-standards (v1.2), architecture (v1.0)
  Module Specs: (按需加载)
  Config: .specanchor/config.yaml
  Available Schemas:
    [custom] <name>: "<description 或 match.when 首条>"
    <name> (default): "<description 或 match.when 首条>"
    <name>: "<description 或 match.when 首条>"
```

## §2 命令定义（按需读取）

所有命令的详细定义已拆分为独立文件，Agent 根据用户意图按需读取对应文件：

```
references/commands/
├── init.md       ← specanchor_init: 初始化
├── global.md     ← specanchor_global: Global Spec 创建/更新
├── module.md     ← specanchor_module: Module Spec 创建/更新
├── infer.md      ← specanchor_infer: 从代码逆向推断 Module Spec
├── task.md       ← specanchor_task: 创建 Task Spec
├── load.md       ← specanchor_load: 手动加载 Spec
├── status.md     ← specanchor_status: 查看状态和覆盖率
├── check.md      ← specanchor_check: Spec-Commit 对齐检测
├── index.md      ← specanchor_index: 更新 Module Spec 索引
└── import.md     ← specanchor_import: 从外部 SDD 框架导入配置
```

自然语言意图映射：见 `references/commands-quickref.md`。

## §3 自动加载规则

### 3.1 Always Load（每次对话）

见 §1 启动检查流程（步骤 2-4 自动执行）。

### 3.2 On-Demand Load（按需加载）

触发条件（满足任一即触发）：

- 用户要求创建任务、模块规范或推断规范时指定了模块路径
- 用户提及的文件路径位于某模块目录下（通过 `module-index.md` 或 `config.yaml` 的 `scan_paths` 匹配）
- RIPER Research 阶段发现相关模块

加载动作：

1. 通过 `module-index.md` 查找模块路径对应的 Module Spec 文件
2. 有 → 从 `.specanchor/modules/` 中读取并注入上下文
3. 无 → 提醒用户：`⚠️ 模块 <path> 无 Module Spec，建议先创建该模块的规范或从代码推断草稿`

### 3.3 加载顺序

```
config.yaml → Global Specs → Module Spec(s)（via module-index.md） → Project Codemap（如需要）
```

## §4 与 SDD-RIPER-ONE 集成协议

### 4.1 写作协议选择（Schema 系统）

SpecAnchor 通过声明式 Schema 系统管理写作协议。每个 Schema 定义了 Artifact DAG（依赖关系图）、模板和流程哲学。

**所有可用 Schema 在 §1 启动检查时发现**（步骤 4 Schema Discovery）。自定义 Schema（`.specanchor/schemas/`）优先级高于内置 Schema（`references/schemas/`）。

**Schema 查找顺序**（首个命中即使用）：

1. `.specanchor/schemas/<name>/schema.yaml` — 项目自定义 Schema（优先）
2. `references/schemas/<name>/schema.yaml` — Skill 内置 Schema
3. 查找失败 → fallback 到默认 Schema（`sdd-riper-one`）

**内置 Schema**：

| Schema 名称 | 哲学 | 说明 |
|-------------|------|------|
| `sdd-riper-one` | strict（有门禁） | 默认。Research → Plan（需 Plan Approved）→ Execute → Review |
| `openspec-compat` | fluid（无门禁） | OpenSpec 兼容。Proposal → Delta Specs → Design → Tasks |
| `simple` | fluid（无门禁） | 轻量级 Task Spec。目标 → 改动计划 → Checklist → 完成确认 |

**Schema 的 `philosophy` 字段决定 Agent 行为**：

- `strict`：artifact 之间的 `requires` 和 `gate` 是硬性约束。未满足依赖或门禁时 Agent 必须阻止推进
- `fluid`：artifact 之间的 `requires` 是建议性的。Agent 提示用户建议的顺序，但不阻止跳过

**Schema 的 `match` 段（可选）**：

用于智能推荐。Agent 在工作流选择时（见 SKILL.md "工作流选择"段），参考启动时发现的所有 Schema 的 `match.when` 列表，与任务描述做语义匹配，推荐最合适的 Schema。

```yaml
match:
  when:                                # 结构化列表，每项是一条自然语言场景描述
    - "场景描述 1"                     # 模型做语义匹配（非字符匹配）
    - "场景描述 2"
```

推荐逻辑完全由模型的语义理解能力驱动——没有分数、没有关键词匹配、没有排序算法。没有 `match` 段的 Schema 仍可手动选择，但不参与自动推荐。

### 4.1.1 两层锁模型

SpecAnchor 的门禁分为两层，分别在不同阶段生效：

```
Layer 1 — Spec 级锁（SKILL.md 管）
  适用于所有 Schema
  📋 标准流程 → 禁止操作 → specanchor_task 创建 Task Spec → 🔓 解锁
  这是"有没有 Task Spec"的门禁

Layer 2 — Schema 级锁（schema.yaml 的 gate 定义管）
  每个 Schema 自定义自己的门禁点
  由 schema.yaml 的 philosophy + gate 字段决定
```

Layer 1 是所有 Schema 共享的基础设施（§4.6），Layer 2 是每个 Schema 独立定义的。两者协同工作：

- Layer 1 保证"Task Spec 必须存在"——没有载体就没有流程
- Layer 2 保证"Schema 定义的关键检查点被执行"——每个 Schema 有不同的门禁需求

### 4.2 集成模式下的行为注入

RIPER 各阶段的 SpecAnchor 注入行为见 SKILL.md "与 SDD-RIPER-ONE 的集成"表格。核心原则：每个阶段都受 Global + Module Spec 约束，Review 阶段检查是否需要更新 Module Spec。

### 4.3 路径替换

集成模式下，SDD-RIPER-ONE 的 Task Spec 默认路径替换：

- 原路径：`mydocs/specs/YYYY-MM-DD_hh-mm_<TaskName>.md`
- 新路径：`.specanchor/tasks/<module>/YYYY-MM-DD_<task>.spec.md`

### 4.4 写作协议可替换性

SpecAnchor 通过 Schema 系统实现写作协议的声明式替换：

1. **切换内置 Schema**：修改 `config.yaml` 的 `writing_protocol.schema`（如 `sdd-riper-one`、`openspec-compat`、`simple`）
2. **创建自定义 Schema**：在 `.specanchor/schemas/<name>/` 下创建 `schema.yaml` + `template.md`，启动时自动发现

所有 Schema 的模板必须保留 SpecAnchor 的 YAML frontmatter（`specanchor:` 命名空间），这是治理能力（覆盖率、腐化检测、状态追踪）的基础。

### 4.6 标准流程门禁协议

当工作流选择输出 `📋 <schema>` 时，Agent 进入门禁状态，直到 Task Spec 创建完成才解锁。

```
触发: 输出 📋 <schema>
状态: GATED（门禁中）
├─ 禁止: 读取源代码进行实现分析（Spec/配置文件不受限）
├─ 禁止: 编写或修改源代码
├─ 禁止: 在对话中口头执行 RIPER 阶段
└─ 唯一允许: 执行 specanchor_task 创建 Task Spec

解锁: Task Spec 文件写入成功
输出: 🔓 标准流程已激活 — Task Spec: <路径>
状态: UNLOCKED（已解锁）→ 按 Schema 定义的流程推进
```

解锁后，RIPER 的每个阶段产出必须写入 Task Spec 文件对应章节，不得仅在对话中口头执行。

**Schema gate 主动确认协议**（仅 `philosophy: strict`）：

Schema 中声明了 `gate` 的阶段转换，Agent 必须主动向用户请求确认，不得自行通过。`philosophy: fluid` 的 Schema 中 gate 仅作提示，不阻塞。

### 4.5 独立模式

用户明确要求简化模式时：

- 使用 `simple` Schema 创建轻量 Task Spec（无 RIPER 流程、无门禁）
- 仅管理 Global / Module Spec 的 CRUD 和加载

## §5 Module Spec 管理协议

### 5.1 集中存放

所有 Module Spec 文件集中存放在 `.specanchor/modules/` 目录下，不在模块目录中就近放置。

**文件命名规则**：模块路径中的 `/` 替换为 `-`，生成 `<module-id>.spec.md`。

```
模块路径                    → Module ID                → Spec 文件名
src/modules/auth           → src-modules-auth          → src-modules-auth.spec.md
src/components/LoginForm   → src-components-LoginForm  → src-components-LoginForm.spec.md
packages/shared/utils      → packages-shared-utils     → packages-shared-utils.spec.md
```

### 5.2 module-index.md 索引

`.specanchor/module-index.md` 是 Module Spec 的集中索引文件，记录每个 Module Spec 到真实模块路径的映射。

**更新时机**：

- 创建或更新 Module Spec（`specanchor_module` / `specanchor_infer`）时自动更新
- 查看状态或更新索引（`specanchor_status` / `specanchor_index`）时自动更新
- `specanchor-check.sh` 执行时自动更新

### 5.3 全量更新协议

当用户要求更新模块规范且 Module Spec 已存在时：

1. **读取 frontmatter**：提取 `version`、`owner`、`reviewers`、`created`
2. **扫描代码**：全量扫描模块目录，分析导出接口、状态管理、依赖、代码模式
3. **全量重生成正文**：§1-§7 全部章节基于当前代码重写
4. **更新 frontmatter**：
   - `version`: minor +1（如 2.1.0 → 2.2.0）
   - `updated`: 当前日期
   - `last_synced`: 当前日期
   - `last_change`: 简述本次变更
   - `owner` / `reviewers` / `created`: 保持不变
5. **写入文件**：覆盖旧内容
6. **更新索引**：更新 `.specanchor/module-index.md`
7. **输出建议**：`Module Spec 已全量更新。建议运行 git diff .specanchor/modules/<module-id>.spec.md 确认变更后提交。`

## §6 External Sources Protocol

当 `config.yaml` 中配置了 `external_sources` 时，SpecAnchor 将外部 SDD 框架（如 OpenSpec）的目录映射为 SpecAnchor 三级体系的一部分。

详细规则见 `references/external-sources-protocol.md`。仅在 config.yaml 中存在 `external_sources` 字段时需要读取该协议文件。

## 附录 A: config.yaml 默认模板

```yaml
specanchor:
  version: "0.3.0"
  project_name: "<project_name>"

  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    module_index: ".specanchor/module-index.md"
    project_codemap: ".specanchor/project-codemap.md"

  # 写作协议配置（可选，默认 sdd-riper-one）
  # writing_protocol:
  #   schema: "sdd-riper-one"          # "sdd-riper-one" | "openspec-compat" | 自定义 schema 名
  #   schema_recommend: true           # 是否启用 Schema 智能推荐（默认 true）
  #                                    # true: specanchor_task 时根据任务描述推荐最佳 Schema
  #                                    # false: 始终使用 schema 字段指定的 Schema

  # 外部来源映射（可选，用于兼容 OpenSpec 等外部 SDD 框架）
  # 详见 references/external-sources-protocol.md
  # external_sources:
  #   - source: "openspec/specs"
  #     maps_to: module_specs
  #     format: "openspec"
  #     file_pattern: "**/spec.md"
  #   - source: "openspec/changes"
  #     maps_to: task_specs
  #     format: "openspec"
  #     file_pattern: "*"
  #     exclude: ["archive"]

  coverage:
    scan_paths:
      - "src/modules/**"
      - "src/components/**"
    ignore_paths:
      - "src/components/ui/**"
      - "src/**/*.test.*"
      - "src/**/*.stories.*"

  check:
    stale_days: 14                    # Module Spec 同步后超过 N 天，且模块代码有新提交 → STALE
    outdated_days: 30                 # Module Spec 同步后超过 N 天，且模块代码有新提交 → OUTDATED
    warn_recent_commits_days: 14      # 无 Spec 的模块在最近 N 天内有代码提交 → 发出警告
    task_base_branch: "main"          # 检测 task 对齐时的默认 git 基准分支

  sync:
    auto_check_on_mr: true
    sprint_sync_reminder: true
```

