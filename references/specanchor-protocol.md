# SpecAnchor 核心协议

## §1 启动检查流程

Skill 激活时，按以下顺序执行：

```
1. 检查 .specanchor/ 是否存在
   ├─ 不存在 → 报错阻塞，引导 SA INIT
   └─ 存在 → 继续
2. 读取 .specanchor/config.yaml
   ├─ 不存在 / 格式错误 → 报错，提供默认配置模板
   └─ 合法 → 继续
3. 读取 .specanchor/global/ 下的所有 .spec.md 文件
   ├─ 目录为空 → 警告：无 Global Spec，建议运行 SA GLOBAL
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

## §2 命令详细定义

### 2.1 specanchor_init

**触发词**: `SA INIT` / `初始化 SpecAnchor`

**参数**:

- `project_name`（可选，默认取当前目录名）
- `scan`（可选，`true` 表示扫描项目自动生成 Global Spec 草稿）

**执行步骤**:

1. 检查 `.specanchor/` 是否已存在 → 已存在则报错：`目录已存在，如需重新初始化请先手动删除`
2. 创建目录结构：

   ```
   .specanchor/
   ├── config.yaml
   ├── global/
   ├── modules/                ← Module Spec 集中存放
   ├── tasks/
   │   └── _cross-module/
   ├── archive/
   ├── module-index.md         ← Module Spec 索引（自动生成）
   └── project-codemap.md      (空文件占位)
   ```

3. 生成 `config.yaml` 默认配置（参考附录 A）
4. 如果 `scan=true`：扫描项目生成 Global Spec 草稿
5. 输出完成信息

**输出**: 目录结构 + `config.yaml`

### 2.2 specanchor_global

**触发词**: `SA GLOBAL <type>` / `全局规范 <类型>`

**参数**:

- `type`（必须）: `coding-standards` / `architecture` / `design-system` / `api-conventions` / 自定义名称
- `scan`（可选）: 指定扫描路径，不指定则自动推断

**执行步骤**:

1. 确定扫描范围：
   - `coding-standards`: 读取 `package.json` / `tsconfig.json` / `.eslintrc` / `.prettierrc`，采样 5-10 个代码文件的模式
   - `architecture`: 读取顶层目录结构、路由配置、中间件层
   - `design-system`: 读取 CSS/Tailwind 配置、组件库、主题文件
   - `api-conventions`: 读取 API 路由定义、请求/响应类型、中间件
2. 从扫描结果推断规范内容
3. 如果文件已存在 → 全量重生成（version minor +1, updated = 今天）
4. 如果不存在 → 新建（version = 1.0.0）
5. 写入 `.specanchor/global/<type>.spec.md`
6. **检查**: 全部 Global Spec 合计是否 ≤ 200 行，超出则警告并建议精简

**输出**: `.specanchor/global/<type>.spec.md`

### 2.3 specanchor_module

**触发词**: `SA MODULE <path>` / `模块规范 <路径>`

**参数**:

- `path`（必须）: 模块目录路径（如 `src/modules/auth`）
- `scan`（可选）: 额外扫描路径（如依赖模块）

**执行步骤**:

1. 检查 `<path>` 目录是否存在 → 不存在则报错
2. 生成 Module ID：将路径中的 `/` 替换为 `-`（如 `src/modules/auth` → `src-modules-auth`）
3. 扫描模块目录下所有代码文件
4. 确定 Spec 文件路径：`.specanchor/modules/<module-id>.spec.md`
5. 如果 Spec 文件已存在（更新模式）：
   - 读取 frontmatter，保留 `owner` / `reviewers`
   - 全量重生成正文（§1-§7 全部章节）
   - `version` minor +1，`updated` = 当前日期，`last_synced` = 当前日期
6. 如果 Spec 文件不存在（创建模式）：
   - 从代码推断所有章节内容
   - `version` = 1.0.0，`status` = draft
   - `module_path` = 用户指定的路径
7. 写入 `.specanchor/modules/<module-id>.spec.md`
8. 更新 `.specanchor/module-index.md`
9. 建议用户 `git diff` 确认变更

**输出**: `.specanchor/modules/<module-id>.spec.md`

### 2.4 specanchor_infer

**触发词**: `SA INFER <path>` / `推断规范 <路径>`

**参数**:

- `path`（必须）: 模块目录路径

**与 specanchor_module 的区别**:

- `infer` 纯粹从代码逆向推断，不需要人工描述输入
- `module` 可以结合用户口述的业务规则和设计意图
- `infer` 产出的 `status` 始终为 `draft`，需要 CR 后手动改为 `active`

**执行步骤**:

1. 扫描 `<path>` 下所有代码文件
2. 生成 Module ID
3. 分析导出接口、内部状态、依赖关系、代码模式
4. 推断业务规则（基于代码逻辑和命名）
5. 生成 `.specanchor/modules/<module-id>.spec.md`（status = draft）
6. 明确标记"由代码推断，待人工确认"的章节
7. 更新 `.specanchor/module-index.md`

**输出**: `.specanchor/modules/<module-id>.spec.md` (status: draft)

### 2.5 specanchor_task

**触发词**: `SA TASK <name>` / `创建任务 <名称>`

**参数**:

- `name`（必须）: 任务名称
- `modules`（可选）: 关联模块路径列表，不指定则从任务描述自动推断

**执行步骤**:

1. 确定关联模块（用户指定或自动推断）
2. 读取关联模块的 Module Spec（On-Demand 加载，从 `.specanchor/modules/` 中查找）
3. 确定存储路径：
   - 单模块 → `.specanchor/tasks/<module_name>/YYYY-MM-DD_<task>.spec.md`
   - 多模块 → `.specanchor/tasks/_cross-module/YYYY-MM-DD_<task>.spec.md`
   - 目录不存在 → 自动创建子目录
4. 生成 Task Spec：
   - 默认使用 SDD-RIPER-ONE Task Spec 模板（含完整 RIPER 段）
   - 如果用户明确要求简化模式 → 使用简化 Task Spec 模板
5. 填充 SpecAnchor frontmatter（level, task_name, related_modules, related_global, sdd_phase）
6. 写入文件

**输出**: `.specanchor/tasks/<module>/YYYY-MM-DD_<task>.spec.md`

### 2.6 specanchor_load

**触发词**: `SA LOAD <path>` / `加载规范 <路径>`

**参数**:

- `path`（必须）: Spec 文件路径（支持单文件或 glob）

**执行步骤**:

1. 读取指定文件内容
2. 注入当前对话上下文
3. 报告已加载的 Spec

### 2.7 specanchor_status

**触发词**: `SA STATUS` / `规范状态`

**参数**: 无

**执行步骤**:

1. 列出当前已加载的 Spec（Global + Module）
2. 扫描 `.specanchor/modules/` 目录，统计 Module Spec 覆盖率
3. 统计活跃/归档 Task Spec 数量
4. 自动更新 `.specanchor/module-index.md`
5. 输出简洁摘要

**输出格式**:

```
SpecAnchor Status
  Loaded: coding-standards (v1.2), architecture (v1.0), auth/MODULE (v2.1)
  Coverage: 3/4 modules (75%)
  Tasks: 2 active, 15 archived
```

### 2.8 specanchor_check

**触发词**: `SA CHECK [task|module|global]`

**参数**:

- `level`（必须）: `task` / `module` / `global`
- `spec`（task/module 级必须，global 级可选）: Spec 文件路径，或 `--all`
- `base`（task 级可选，默认 `main`）: git 基准分支
- `stale-days`（module 级可选，默认 30）: 过期天数阈值

**执行步骤**:

- 调用 `scripts/specanchor-check.sh` 并传递参数
- 或在无脚本时，由 Agent 直接执行等效的 git 命令

**详细逻辑见脚本文档**: `scripts/specanchor-check.sh`

### 2.9 specanchor_index

**触发词**: `SA INDEX` / `更新索引`

**参数**: 无

**执行步骤**:

1. 扫描 `.specanchor/modules/` 下所有 `.spec.md` 文件
2. 读取每个文件的 frontmatter 信息
3. 扫描 `config.yaml` 中 `scan_paths` 下的模块目录
4. 生成/更新 `.specanchor/module-index.md`

**输出**: `.specanchor/module-index.md`

**module-index.md 格式**:

```markdown
# Module Spec Index
<!-- 由 SA INDEX / SA STATUS 自动生成，请勿手动编辑 -->
<!-- 生成时间: YYYY-MM-DD HH:MM -->

| 模块名 | 模块路径 | Spec 文件 | 状态 | 版本 | 最后同步 | Owner |
|--------|---------|----------|------|------|---------|-------|
| 用户认证 | src/modules/auth | src-modules-auth.spec.md | active | 2.1.0 | 2026-03-10 | @zhangsan |
| 订单管理 | src/modules/order | src-modules-order.spec.md | active | 1.5.0 | 2026-03-08 | @lisi |

## 无 Spec 覆盖的模块

| 模块路径 | 近 30 天提交数 | 建议 |
|---------|-------------|------|
| src/modules/payment | 12 | 建议运行 SA INFER src/modules/payment |
| src/modules/search | 8 | 建议运行 SA INFER src/modules/search |
```

## §3 自动加载规则

### 3.1 Always Load（每次对话）

Skill 被引用时立即执行：

1. 读取 `.specanchor/config.yaml`
2. 读取 `.specanchor/global/` 下所有 `.spec.md` 文件

### 3.2 On-Demand Load（按需加载）

触发条件（满足任一即触发）：

- `SA TASK` / `SA MODULE` / `SA INFER` 命令指定了模块路径
- 用户提及的文件路径位于某模块目录下（通过 `module-index.md` 或 `config.yaml` 的 `scan_paths` 匹配）
- RIPER Research 阶段发现相关模块

加载动作：

1. 通过 `module-index.md` 查找模块路径对应的 Module Spec 文件
2. 有 → 从 `.specanchor/modules/` 中读取并注入上下文
3. 无 → 提醒用户：`⚠️ 模块 <path> 无 Module Spec，建议先运行 SA MODULE <path> 或 SA INFER <path>`

### 3.3 加载顺序

```
config.yaml → Global Specs → Module Spec(s)（via module-index.md） → Project Codemap（如需要）
```

## §4 与 SDD-RIPER-ONE 集成协议

### 4.1 默认写作协议

SpecAnchor 内置 SDD-RIPER-ONE 作为默认写作协议。`SA TASK` 命令默认使用 SDD-RIPER-ONE 格式的 Task Spec 模板。

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

SpecAnchor 不硬编码 SDD-RIPER-ONE 的具体指令。默认内置 SDD-RIPER-ONE 模板是为了开箱即用，但可替换为其他协议（如 SPECLAN、IntentSpec）：

1. 替换 `references/task-spec-template.md` 的 SDD 变体部分
2. 保留 SpecAnchor 的 YAML frontmatter 格式不变
3. 在 SKILL.md 中更新写作协议引用

### 4.5 独立模式

用户明确要求简化模式时：

- `SA TASK` 使用简化 Task Spec 模板（见 `references/task-spec-template.md` 的简化版）
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

- `SA MODULE` / `SA INFER` 创建或更新 Module Spec 时自动更新
- `SA STATUS` / `SA INDEX` 命令触发时自动更新
- `specanchor-check.sh` 执行时自动更新

### 5.3 全量更新协议

当运行 `SA MODULE <path>` 且 Module Spec 已存在时：

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

## 附录 A: config.yaml 默认模板

```yaml
specanchor:
  version: "0.2.0"
  project_name: "<project_name>"

  paths:
    global_specs: ".specanchor/global/"
    module_specs: ".specanchor/modules/"
    task_specs: ".specanchor/tasks/"
    archive: ".specanchor/archive/"
    module_index: ".specanchor/module-index.md"
    project_codemap: ".specanchor/project-codemap.md"

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
    warn_recent_commits_days: 30      # 无 Spec 的模块在最近 N 天内有代码提交 → 发出警告
    task_base_branch: "main"          # SA CHECK task 的默认 git 基准分支

  sync:
    auto_check_on_mr: true
    sprint_sync_reminder: true
```

### 附录 B: check 配置字段说明

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `stale_days` | 30 | Module Spec 上次同步后超过此天数，且模块代码有新提交 → 标记为 STALE |
| `outdated_days` | 90 | Module Spec 上次同步后超过此天数，且模块代码有新提交 → 标记为 OUTDATED（比 STALE 更严重） |
| `warn_recent_commits_days` | 30 | 无 Spec 覆盖的模块在最近此天数内有代码提交 → 发出警告 |
| `task_base_branch` | main | `SA CHECK task` 的默认 git 基准分支 |
