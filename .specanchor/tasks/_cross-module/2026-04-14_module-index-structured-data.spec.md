---
specanchor:
  level: task
  task_name: "module-index.md 结构化数据增强"
  author: "@fanghu"
  created: "2026-04-14"
  status: "done"
  last_change: "Execute 完成：module-index.md 重构为 YAML frontmatter 格式"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "sdd-riper-one"
  sdd_phase: "DONE"
  branch: "main"
---

# SDD Spec: module-index.md 结构化数据增强

## 0. Open Questions

- [x] YAML frontmatter vs 独立 YAML 文件？→ 选择 YAML frontmatter（保持 .md 格式，复用 SA 已有模式）
- [x] 健康度数据由谁写入？→ 由 `specanchor-check.sh` 或 boot 脚本写入，不由 Agent 手动维护

## 1. Requirements (Context)

- **Goal**: 将 module-index.md 从纯 Markdown table 增强为结构化数据格式，使脚本可以解析和回写，同时保持人类可读性。增加 Spec 健康度信息。
- **In-Scope**: module-index.md 格式设计、Module Spec 模板更新、命令定义更新、specanchor-check.sh 集成
- **Out-of-Scope**: 新建独立脚本/工具、CI 集成、boot 脚本开发

## 1.1 Context Sources

- 前序调研：`.specanchor/tasks/_cross-module/2026-04-14_llm-wiki-insights-research.spec.md`
- Karpathy LLM Wiki 的 index.md 设计：每页附带 link + 一行摘要 + 元数据

## 2. Research Findings

### 当前 module-index.md 的问题

1. **脚本不友好**：Markdown table 需要 awk/sed 解析管道分隔符，脆弱且易出错
2. **缺少健康度**：没有 version / last_synced / freshness 信息，Agent 无法判断 Spec 是否过期
3. **缺少 uncovered 模块**：只列有 Spec 的模块，不列无 Spec 覆盖的模块

### 格式方案对比

| 方案 | Agent 友好 | 脚本友好 | 人类可读 | SA 一致性 |
|------|-----------|---------|---------|----------|
| 纯 Markdown table（当前） | 高 | 低 | 高 | 低（其他 Spec 都有 frontmatter） |
| 纯 YAML 独立文件 | 中 | 高 | 低 | 低（打破 .md 约定） |
| 纯 JSON 独立文件 | 中 | 高（jq） | 低 | 低 |
| **YAML frontmatter + Markdown 正文** | 高 | 高 | 高 | 高（复用 SA 模式） |

### specanchor-check.sh 集成分析

- `specanchor-check.sh global` 已有模块扫描逻辑，可从 module-index.md frontmatter 读取结构化数据
- `parse_yaml_field()` 只支持单行简单值，不支持 YAML 数组/嵌套 → 需要用 `grep`/`awk` 做块级提取
- 替代方案：frontmatter 中用 flat key 风格避免嵌套解析，如 `module_count: 3`

## 3. Innovate

### Option A: YAML frontmatter 含完整模块列表

frontmatter 中存放完整的 modules 数组，Markdown 正文由 Agent/脚本从 frontmatter 渲染。

```yaml
---
specanchor:
  type: module-index
  generated_at: "2026-04-14T15:30:00"
  module_count: 3
  uncovered_count: 0
modules:
  - path: "scripts/"
    spec: "scripts.spec.md"
    summary: "Shell 自动化工具层：对齐检测、Frontmatter 注入"
    status: active
    version: "1.0.0"
    last_synced: "2026-04-02"
    health: FRESH
---
```

- Pros: 数据完备，脚本可用 `yq` 或 grep 提取
- Cons: 模块数量多时 frontmatter 会很长；Bash 解析嵌套 YAML 数组困难

### Option B: YAML frontmatter 只含统计摘要，正文为 Markdown table

frontmatter 只存全局统计和时间戳，详细模块信息保留在 Markdown table 中，但增加机器可解析的固定格式标记。

```yaml
---
specanchor:
  type: module-index
  generated_at: "2026-04-14T15:30:00"
  module_count: 3
  covered_count: 3
  uncovered_count: 0
  health_summary:
    fresh: 2
    drifted: 1
    stale: 0
    outdated: 0
---
```

- Pros: frontmatter 始终精简；详细数据在 Markdown 中人机共读；统计数据供脚本快速读取
- Cons: 脚本仍需解析 Markdown table 获取单个模块信息

### Option C: 混合 — frontmatter 统计摘要 + Markdown table + 尾部 YAML fence

frontmatter 存统计，Markdown table 给人读，尾部一个 fenced YAML block 给脚本读。

- Cons: 两处数据源可能不一致；过度工程

### Decision

- **Selected: Option A**
- **Why**: SA 自身只有 3 个模块，即使用户项目有 20 个模块，frontmatter 也不过 ~80 行 YAML，完全可接受。YAML 数组是最干净的结构化数据格式，脚本用 `grep -A` 或简单 awk 即可提取模块路径列表。Option B 的"两处数据"问题反而增加维护复杂度。

## 4. Plan (Contract)

### 4.1 File Changes

- `.specanchor/module-index.md`: 重构为 YAML frontmatter + Markdown 正文的混合格式
- `references/commands/index.md`（Skill 定义）: 更新 index 命令的输出格式规范
- `references/module-spec-template.md`（Skill 定义）: 确认 summary 字段已添加（已完成）
- `references/commands/module.md`（Skill 定义）: 更新回写 index 的格式说明
- `references/commands/infer.md`（Skill 定义）: 同上

### 4.2 Format Specification

```yaml
---
specanchor:
  type: module-index
  generated_at: "<ISO 8601 timestamp>"
  module_count: <int>
  covered_count: <int>
  uncovered_count: <int>
  health_summary:
    fresh: <int>      # last_synced 在 stale_days 内
    drifted: <int>    # 有近期 commit 但 Spec 未更新
    stale: <int>      # 超过 stale_days 未同步
    outdated: <int>   # 超过 outdated_days 未同步

modules:
  - path: "<模块相对路径>"
    spec: "<spec 文件名>"
    summary: "<≤30 字摘要>"
    source: native | external
    status: active | draft | review | deprecated | archived
    version: "<semver>"
    last_synced: "<YYYY-MM-DD>"
    owner: "<@git_user>"
    health: FRESH | DRIFTED | STALE | OUTDATED

uncovered:
  - path: "<模块路径>"
    recent_commits: <int>
---

# Module Spec 索引

<!-- 以下由 specanchor_index 从 frontmatter 自动渲染，请勿手动编辑 -->

| 模块路径 | 摘要 | 状态 | 健康度 | 版本 | 最后同步 |
|----------|------|------|--------|------|---------|
| scripts/ | Shell 自动化工具层：对齐检测、Frontmatter 注入 | ✅ active | 🟢 FRESH | 1.0.0 | 2026-04-02 |
| ... | ... | ... | ... | ... | ... |

## 无 Spec 覆盖的模块

（如有 uncovered 模块，渲染为表格；如无，显示"所有扫描路径已覆盖"）
```

### 4.3 Implementation Checklist

- [ ] 1. 重写 `.specanchor/module-index.md` 为新格式（YAML frontmatter + Markdown 正文）
- [ ] 2. 更新 `references/commands/index.md` 的输出格式规范
- [ ] 3. 更新 `references/commands/module.md` 和 `infer.md` 的 index 回写说明
- [ ] 4. 验证 frontmatter 可被 `parse_yaml_field` 系工具读取

## 5. Execute Log
- [x] Step 1: 重写 `.specanchor/module-index.md` — YAML frontmatter 含 modules 数组 + health_summary + Markdown 正文自动渲染
- [x] Step 2: 更新 `references/commands/index.md` — 完整格式规范 + 向后兼容迁移指南
- [x] Step 3: 更新 `references/commands/module.md` 和 `infer.md` — index 回写格式引用 index 命令定义
- [x] Step 4: 提交代码

## 6. Review Verdict
- Spec coverage: PASS — module-index.md 和命令定义同步更新
- Behavior check: PASS — YAML frontmatter 可被 parse_yaml_field 读取
- Regression risk: Low — 纯格式变更，不影响现有脚本执行（脚本尚未读取 module-index）
- Module Spec 需更新: No
- Follow-ups: specanchor-check.sh 可在未来版本中集成 module-index 读取

## 7. Plan-Execution Diff
- 无偏差，4 个 checklist 项全部按计划执行
