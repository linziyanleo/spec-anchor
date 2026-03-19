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
4. 输出加载状态摘要
```

加载状态摘要格式：

```
SpecAnchor 已加载
  Global Specs: coding-standards (v1.2), architecture (v1.0)
  Module Specs: (按需加载)
  Config: .specanchor/config.yaml
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

Skill 被引用时立即执行：

1. 读取 `.specanchor/config.yaml`
2. 读取 `.specanchor/global/` 下所有 `.spec.md` 文件

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

**Schema 查找顺序**（首个命中即使用）：

1. `.specanchor/schemas/<name>/schema.yaml` — 项目自定义 Schema
2. `references/schemas/<name>/schema.yaml` — Skill 内置 Schema
3. `references/task-spec-template.md` — 无 Schema 配置时的 fallback

**读取 config.yaml 中的 `writing_protocol.schema` 字段**：

- 有值 → 按查找顺序定位 Schema，读取 `schema.yaml` + `template.md`
- 无值或未配置 → 使用默认值 `sdd-riper-one`
- 值为 `simple` → 使用 `references/task-spec-template.md` 的简化模板

**内置 Schema**：

| Schema 名称 | 哲学 | 说明 |
|-------------|------|------|
| `sdd-riper-one` | strict（有门禁） | 默认。Research → Plan（需 Plan Approved）→ Execute → Review |
| `openspec-compat` | fluid（无门禁） | OpenSpec 兼容。Proposal → Delta Specs → Design → Tasks |

**Schema 的 `philosophy` 字段决定 Agent 行为**：

- `strict`：artifact 之间的 `requires` 和 `gate` 是硬性约束。未满足依赖或门禁时 Agent 必须阻止推进
- `fluid`：artifact 之间的 `requires` 是建议性的。Agent 提示用户建议的顺序，但不阻止跳过

**用户自定义 Schema**：用户可以在 `.specanchor/schemas/<name>/` 下创建自定义 Schema（包含 `schema.yaml` + `template.md`），然后在 `config.yaml` 中设置 `writing_protocol.schema: <name>` 启用。

**Schema 只在创建 Task Spec 时加载**——不影响启动检查流程，符合 Progressive Disclosure。

### 4.2 集成模式下的行为注入

| RIPER 阶段 | SpecAnchor 注入行为 |
|-----------|-------------------|
| Pre-Research | 自动执行 Always Load；根据 task 描述 On-Demand 加载 Module Spec |
| Research | Module Spec 的 §2 业务规则、§3 对外接口 作为现状分析输入 |
| Plan | `§4.1 File Changes` 列出的文件必须与 Module Spec `§7 关键文件` 交叉校验 |
| Execute | 代码生成必须遵循 Global Spec 的编码规范 + Module Spec 的接口契约 |
| Review | 检查是否需要更新 Module Spec（新增导出 API / 变更依赖 / 修改业务规则） |

### 4.3 路径替换

集成模式下，SDD-RIPER-ONE 的 Task Spec 默认路径替换：

- 原路径：`mydocs/specs/YYYY-MM-DD_hh-mm_<TaskName>.md`
- 新路径：`.specanchor/tasks/<module>/YYYY-MM-DD_<task>.spec.md`

### 4.4 写作协议可替换性

SpecAnchor 通过 Schema 系统实现写作协议的声明式替换。三种方式（由简到繁）：

1. **切换内置 Schema**：修改 `config.yaml` 的 `writing_protocol.schema` 为 `sdd-riper-one` 或 `openspec-compat`
2. **创建自定义 Schema**：在 `.specanchor/schemas/<name>/` 下创建 `schema.yaml` + `template.md`，然后在 config 中引用
3. **直接替换模板**（向后兼容）：替换 `references/task-spec-template.md` 的内容，保留 SpecAnchor YAML frontmatter 格式不变

所有方式都保留 SpecAnchor 的 YAML frontmatter（`specanchor:` 命名空间），这是 SpecAnchor 治理能力（覆盖率、腐化检测、状态追踪）的基础。

### 4.6 标准流程门禁协议

当复杂度评估输出 `📋 标准流程` 时，Agent 进入门禁状态，直到 Task Spec 创建完成才解锁。

**门禁规则**：

```
触发: 输出 📋 标准流程
状态: GATED（门禁中）
├─ 禁止: 读取源代码进行实现分析（Spec/配置文件不受限）
├─ 禁止: 编写或修改源代码
├─ 禁止: 在对话中口头执行 RIPER 阶段
└─ 唯一允许: 执行 specanchor_task 创建 Task Spec

解锁: Task Spec 文件写入成功
输出: 🔓 标准流程已激活 — Task Spec: <路径>
状态: UNLOCKED（已解锁）→ 进入 RIPER 流程
```

**设计动机**：

此门禁填补 L1（复杂度评估）与 L2（RIPER 阶段门禁）之间的断层。没有此门禁时，Agent 会将 RIPER 作为心智模型在对话中"口头执行"（"让我先研究…""开始实现…"），绕过 Task Spec 的创建，导致：
- RIPER 的 Plan Approved 门禁因 Task Spec 不存在而从未激活
- Research/Plan 产出未持久化，不可追溯
- 规范驱动开发的核心价值被架空

**RIPER 阶段文件化要求**：

解锁后，RIPER 的每个阶段产出必须写入 Task Spec 文件对应章节，不得仅在对话中口头执行：
- Research 结论 → 写入 §2
- Plan 契约 → 写入 §4（需经 Plan Approved 门禁）
- Execute 日志 → 写入 §5
- Review 结论 → 写入 §6

### 4.5 独立模式

用户明确要求简化模式时：

- 创建任务时使用简化 Task Spec 模板（见 `references/task-spec-template.md` 的简化版）
- 无 RIPER 状态机约束
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

### 附录 B: check 配置字段说明

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `stale_days` | 14 | Module Spec 上次同步后超过此天数，且模块代码有新提交 → 标记为 STALE |
| `outdated_days` | 30 | Module Spec 上次同步后超过此天数，且模块代码有新提交 → 标记为 OUTDATED（比 STALE 更严重） |
| `warn_recent_commits_days` | 14 | 无 Spec 覆盖的模块在最近此天数内有代码提交 → 发出警告 |
| `task_base_branch` | main | 检测 task 对齐时的默认 git 基准分支 |
