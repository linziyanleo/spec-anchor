# SpecAnchor 核心协议

## §1 启动检查流程

Skill 激活时，按以下顺序执行。**首选方式**是运行 `scripts/specanchor-boot.sh` 脚本一次性完成所有检查（节省 60-90% token）；**降级方式**是逐步手动执行。

### §1.1 脚本化启动（首选）

```bash
# 在用户项目根目录运行
SPECANCHOR_SKILL_DIR="<skill_install_dir>" bash "<skill_install_dir>/scripts/specanchor-boot.sh"

# 可选格式：
#   --format=summary   精简摘要（默认）
#   --format=full      含 Global Spec 完整内容
#   --format=json      JSON 机器可读
```

脚本执行步骤 1-5 的全部检查，输出结构化摘要。Agent 读取摘要即可获得启动上下文。

如果需要 Global Spec 内容用于约束代码生成，使用 `--format=full`。

脚本出错时的行为：

- 配置文件缺失 → 输出 `⛔ 未找到 anchor.yaml 或 .specanchor/config.yaml` 并退出
- `.specanchor/` 目录缺失（full 模式）→ 输出 `⛔ mode 为 full 但 .specanchor/ 目录不存在` 并退出

`SPECANCHOR_SKILL_DIR` 环境变量指向 Skill 安装目录，用于查找内置 schemas。未设置时 fallback 到脚本自身上级目录。

### §1.1.1 其他脚本化命令

以下命令也有对应脚本，详见各命令定义文件：

| 命令 | 脚本 | 说明 |
|------|------|------|
| `specanchor_init` | `scripts/specanchor-init.sh` | 目录结构和 anchor.yaml 创建（半脚本化，Global Spec 生成仍由 Agent 完成） |
| `specanchor_status` | `scripts/specanchor-status.sh` | 状态/覆盖率报告（支持 summary/json 输出） |
| `specanchor_index` | `scripts/specanchor-index.sh` | 生成/更新 module-index.md（v2 格式） |
| `specanchor_check` | `scripts/specanchor-check.sh` | Spec-Code 对齐检测 |

### §1.2 手动启动（降级）

脚本不可用时，按以下顺序逐步执行：

```
1. 查找配置文件（root-first，支持 local overlay）
   ├─ 检查项目根目录 anchor.yaml
   │   ├─ 不存在 → 继续检查 .specanchor/config.yaml（向后兼容）
   │   └─ 存在 → 继续检查同目录下 anchor.local.yaml
   │       ├─ 存在 → 以 `anchor.yaml + anchor.local.yaml` 作为 resolved config
   │       │   - `sources`：local 追加到 base 之后
   │       │   - public scripts 读取的标量字段：local 优先，未声明时回退 base
   │       │   - 其他 YAML list/map：当前不做通用 deep merge
   │       └─ 不存在 → 直接使用 anchor.yaml
   ├─ 检查 .specanchor/config.yaml（向后兼容）
   │   └─ 存在 → 使用它，输出迁移提示：
   │       ⚠️ 检测到旧版配置 .specanchor/config.yaml，建议迁移到根目录 anchor.yaml
   │       继续步骤 2
   └─ 都不存在 → 报错阻塞，引导用户初始化

2. 读取 resolved config
   ├─ 格式错误 → 报错，提供默认配置模板
   └─ 合法 → 读取 mode 字段，继续步骤 3

3. 按 mode 分叉加载
   ├─ mode: full（默认）
   │   ├─ 检查 .specanchor/ 是否存在
   │   │   └─ 不存在 → 报错：⛔ mode 为 full 但 .specanchor/ 目录不存在
   │   ├─ 读取 .specanchor/global/ 下所有 .spec.md（合计 ≤ 200 行）
   │   │   └─ 目录为空 → 警告：无 Global Spec，建议生成
   │   └─ 继续步骤 4
   └─ mode: parasitic
       ├─ 跳过 .specanchor/ 检查和 Global/Module Spec 加载
       ├─ 读取 sources 段，检查各来源目录存在性
       └─ 继续步骤 4

4. 发现可用 Schema（Schema Discovery）
   ├─ mode: full
   │   ├─ 扫描 .specanchor/schemas/*/schema.yaml（项目自定义，标记为 [custom]，优先级更高）
   │   ├─ 扫描 references/schemas/*/schema.yaml（Skill 内置）
   │   ├─ 对每个 schema.yaml，读取 name、description、match.when（如有）
   │   ├─ 合并列表：自定义 Schema 在前，内置 Schema 在后
   │   └─ 无 Schema 目录或结果为空 → 使用 sdd-riper-one 作为唯一可用 Schema
   └─ mode: parasitic
       └─ Schema Discovery 不执行（parasitic 模式不创建 Task Spec）

5. 输出加载状态摘要
```

### §1.3 加载状态摘要格式

脚本和手动方式的输出格式一致。

full 模式：

```
SpecAnchor Boot [full]
  Config: anchor.yaml (v0.4.0-alpha.1, project: my-project)
  Global Specs: 3 files, 134 lines total
    - architecture.spec.md (51 lines)
    - coding-standards.spec.md (47 lines)
    - project-setup.spec.md (36 lines)
  Module Specs: 3 module(s) (按需加载)
  Module Index: v2 (structured) — 🟢2 🟡1 🟠0 🔴0
  Task Specs: 1 active, 0 archived
  Sources:
    ✓ mydocs/specs/ [mydocs]: stale_check=true, frontmatter_inject=false
  Available Schemas:
    sdd-riper-one (default) [strict]: SDD-RIPER-ONE 流程...
    bug-fix [strict]: Bug 修复流程...
    simple [fluid]: 轻量级 Task Spec...
```

parasitic 模式：

```
SpecAnchor Boot [parasitic]
  Config: anchor.yaml (v0.4.0-alpha.1, project: my-project)
  Sources:
    ✓ specs/ [spec-kit]: stale_check=true, frontmatter_inject=false
    ✓ .qoder/specs/ [qoder]: stale_check=true, frontmatter_inject=true
  Note: parasitic 模式仅提供治理能力（腐化检测 + 扫描），不支持创建 Spec
```

当 `anchor.local.yaml` 存在时，`Config:` 行显示为 `anchor.yaml + anchor.local.yaml`，用于显式提示当前运行时启用了 maintainer-local overlay。

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

### 3.2 On-Demand Load（按需加载，仅 mode: full）

触发条件（满足任一即触发）：

- 用户要求创建任务、模块规范或推断规范时指定了模块路径
- 用户提及的文件路径落在某个模块路径边界内（目录前缀匹配，或与单文件 `module_path` 精确匹配）
- RIPER Research 阶段发现相关模块

加载动作：

1. 通过 `module-index.md` 查找模块路径对应的 Module Spec 文件
2. 有 → 从 `.specanchor/modules/` 中读取并注入上下文
3. 无 → 提醒用户：`⚠️ 模块 <path> 无 Module Spec，建议先创建该模块的规范或从代码推断草稿`

### 3.3 加载顺序

```
anchor.yaml (+ anchor.local.yaml, if present) → Global Specs → Module Spec(s)（via module-index.md） → Project Codemap（如需要）
```

### 3.4 Assembly Trace（每轮必显式输出）

Agent 每轮都必须显式输出本轮的上下文装配结果，禁止仅靠隐式提示词或内部状态。

标准格式：

```text
Assembly Trace:
  - Global: summary|full|none|skipped -> <spec files or reason>
  - Module: summary|full|deferred|sources-only -> <spec files or reason>
```

规则：

1. 启动检查完成后立即输出一次 trace
2. 若后续触发 On-Demand Load，再输出一次更新后的 trace
3. `summary` 表示仅加载文件名/摘要/统计；`full` 表示已读取 Spec 正文
4. `deferred` 表示本轮尚未加载 Module Spec；`sources-only` 用于 parasitic 模式
5. 若无可加载 Global Spec，明确输出 `none`，不要省略该行

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
| `bug-fix` | strict（有门禁） | Bug 修复。Reproduce → Diagnose → Root Cause → Fix Plan → Fix → Verify |
| `refactor` | strict（有门禁） | 代码重构。Measure → Identify → Plan → Execute → Verify（行为不变） |
| `research` | strict（有门禁） | 技术调研。Question → Explore → Findings → Challenge → Conclusion |
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

1. **切换内置 Schema**：修改 `anchor.yaml` 的 `writing_protocol.schema`（如 `sdd-riper-one`、`openspec-compat`、`simple`）
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

**文件命名规则**：模块路径中的 `/` 替换为 `-`，生成 `<module-id>.spec.md`。`module_path` 可为目录或单文件路径。

```
模块路径                    → Module ID                → Spec 文件名
src/modules/auth           → src-modules-auth          → src-modules-auth.spec.md
src/components/LoginForm   → src-components-LoginForm  → src-components-LoginForm.spec.md
src/pages/home.tsx         → src-pages-home.tsx        → src-pages-home.tsx.spec.md
packages/shared/utils      → packages-shared-utils     → packages-shared-utils.spec.md
```

### 5.2 module-index.md 索引

`.specanchor/module-index.md` 是 Module Spec 的集中索引文件，记录每个 Module Spec 到真实模块路径的映射，同时包含每个模块的摘要和健康度状态。

**格式**：v2（YAML frontmatter + Markdown），详见 `references/commands/index.md`。

v2 格式的 YAML frontmatter 包含：
- `specanchor.type: module-index` — 格式标识
- `modules[]` — 结构化模块列表（path、spec、summary、health 等）
- `health_summary` — 按健康度分组的统计（fresh / drifted / stale / outdated）
- `uncovered[]` — 无 Spec 覆盖的模块列表

Markdown 正文是 frontmatter 的人类可读渲染，由 `specanchor_index` 自动生成。

**更新时机**：

- 创建或更新 Module Spec（`specanchor_module` / `specanchor_infer`）时自动更新
- 查看状态或更新索引（`specanchor_status` / `specanchor_index`）时自动更新
- `specanchor-check.sh` 执行时自动更新

**boot 脚本集成**：`specanchor-boot.sh` 启动时自动检测格式（v2 / legacy / missing），v2 时提取健康度统计展示在启动摘要中。

### 5.3 全量更新协议

当用户要求更新模块规范且 Module Spec 已存在时：

1. **读取 frontmatter**：提取 `version`、`owner`、`reviewers`、`created`
2. **扫描代码**：
   - `module_path` 为目录 → 全量扫描模块目录，分析导出接口、状态管理、依赖、代码模式
   - `module_path` 为单文件 → 扫描该文件本身，并以该文件作为模块边界分析代码模式
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

## §6 Sources 协议

当 resolved config 中配置了 `sources` 时，SpecAnchor 将外部 spec 体系的目录纳入治理范围。

详细规则见 `references/external-sources-protocol.md`。仅在 resolved config 中存在 `sources` 字段时需要读取该协议文件。

## 附录 A: anchor.yaml 默认模板

```yaml
specanchor:
  version: "0.4.0-alpha.1"
  project_name: "<project_name>"

  # === 运行模式 ===
  # full: 有 .specanchor/ 自有体系 + 可选外部来源
  # parasitic: 无 .specanchor/，纯治理已有 spec 体系（只读，不创建 spec）
  mode: "full"                         # full | parasitic

  # === 路径配置（mode=full 时生效）===
  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    module_index: ".specanchor/module-index.md"
    project_codemap: ".specanchor/project-codemap.md"

  # === 外部来源（可选）===
  # 详见 references/external-sources-protocol.md
  # sources:
  #   - path: "specs/"                    # 来源目录
  #     type: "spec-kit"                  # 类型（参考附录 B type registry）
  #     maps_to: module_specs             # 映射目标
  #     file_pattern: "**/*.spec.md"      # 文件匹配（type 有默认值，可覆盖）
  #     exclude: []                       # 排除路径
  #     governance:                       # 治理策略
  #       stale_check: true               # 纳入腐化检测
  #       frontmatter_inject: false       # 是否注入 SpecAnchor frontmatter
  #       scan_on_init: true              # init 时扫描并生成报告

  # === 写作协议配置（可选，默认 sdd-riper-one，mode=full 时生效）===
  # writing_protocol:
  #   schema: "sdd-riper-one"            # "sdd-riper-one" | "openspec-compat" | 自定义 schema 名
  #   schema_recommend: true             # 是否启用 Schema 智能推荐（默认 true）

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

## 附录 B: Type Registry

SpecAnchor 内置以下 spec 体系类型，用于 `specanchor_init` 自动检测和 `sources` 配置：

| type | 自动检测路径 | 默认 file_pattern | 默认 maps_to |
| ---- | ---- | ---- | ---- |
| `openspec` | `openspec/` | `**/spec.md` | `module_specs` |
| `spec-kit` | `specs/` | `**/*.spec.md` | `module_specs` |
| `mydocs` | `mydocs/specs/` | `**/*.md` | `task_specs` |
| `qoder` | `.qoder/specs/` | `**/*.md` | `module_specs` |
| `generic` | `docs/specs/` | `**/*.md` | `module_specs` |
| `custom` | （用户指定） | （用户指定） | （用户指定） |

- `specanchor_init` 时按此表自动扫描项目根目录，发现的来源展示给用户确认
- 用户可覆盖任何默认值（`file_pattern`、`maps_to`）
- `custom` 类型用于 registry 未覆盖的 spec 框架，所有字段需用户手动指定
- 新增 spec 框架支持：在此表中添加新行即可
