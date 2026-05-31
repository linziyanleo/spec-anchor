---
specanchor:
  level: module
  module_name: "scripts"
  module_path: "scripts/"
  summary: "Shell 自动化工具层：初始化、状态/诊断、索引、对齐检测、Frontmatter、解析与校验"
  version: "2.6.0"
  owner: "maintainers"
  created: "2026-04-02"
  status: active
  last_synced: "2026-05-26"
  last_synced_sha: "71b2c7c"
  last_change: "v0.7 session-context-control: §2 加 Session 上下文加载契约（SP-20260531-001 accepted ← F-20260530-001）；boot 加 --tasks=open|all|none + 文档补 inline-brief；boot-install 注入模板加 boot-once/delta 契约；assemble 加超 N 行默认 summary 启发式"
  depends_on: []
---

# Module Spec: scripts/

## 1. 职责

自动化工具层，为 SpecAnchor 提供可独立执行的 Shell 脚本，不依赖 Skill 上下文或 Agent 运行时。所有脚本仅读取文件系统和 `anchor.yaml` 配置。

## 2. 业务规则

- 脚本必须独立可运行（`bash scripts/xxx.sh` 即可执行，无需 Agent）
- 所有脚本遵循 `set -euo pipefail` 严格模式
- 配置读取统一通过 `find_config()` + `parse_yaml_field()` 双路径查找
- 输出区分 TTY（彩色）和非 TTY（纯文本），支持管道和重定向
- 幂等安全：重复运行同一脚本不产生副作用
- **Session 上下文加载契约（boot / assemble）**：`specanchor-boot.sh` 是 session-start / preflight，同一 session 原则上只运行一次；同 session 内后续上下文刷新优先用 targeted `specanchor-assemble.sh --files=...`，不重复全量 boot。脚本本身保持「无持久化状态」（见 §4）——"已加载" 账本由调用方 / Assembly Trace 在对话内维护、不落盘；脚本只在单次调用内对目标集合去重。已 `full` 加载过的 spec 正文不重复打印，除非目标集合或 freshness 发生变化。该契约为 advisory（不机械阻断），且必须保留 fail-fast 与每次调用 bounded 输出。（来源：SP-20260531-001 ← F-20260530-001）

## 3. 公开接口（脚本入口）

### specanchor-init.sh

目录和配置初始化（半脚本化）：

| 参数 | 说明 |
|------|------|
| `--project=<name>` | 项目名称（默认取当前目录名） |
| `--mode=full\|parasitic` | 运行模式（默认 full） |
| `--scan-sources` | 扫描检测已有 spec 体系 |
| `--install-boot=<targets>` | init 完成后自动调用 boot-install.sh；`targets` 可为 `auto\|all\|<csv of claude,codex,gemini,cursor>` |

**脚本处理**: 目录创建、anchor.yaml 生成、starter Global Specs、spec-index.md 初始化、deprecated module-index 路径兼容、来源检测、（可选）boot 触发块注入
**Agent 处理**: 来源策略确认、细化 starter Global Specs（需代码分析）

### specanchor-boot-install.sh

幂等注入/移除 SpecAnchor 触发块到 Agent 指令文件，用 `<!-- specanchor:boot:start --> ... <!-- specanchor:boot:end -->` 标记块隔离，块外内容永不修改：

| 参数 | 说明 |
|------|------|
| `--target=<spec>` | `auto`（默认，按工作区标志检测）/ `all` / `claude` / `codex` / `gemini` / `cursor` / 逗号分隔多选 |
| `--dry-run` | 仅预览，不写文件 |
| `--remove` | 移除已注入的标记块（与 `--dry-run` 兼容） |

**目标文件映射**: claude → `CLAUDE.md`, codex → `AGENTS.md`, gemini → `GEMINI.md`, cursor → `.cursor/rules/specanchor.mdc`（自动 mkdir）
**幂等行为**: 文件不存在 → 创建；文件存在但无块 → 末尾追加（前置空行）；文件已含块 → 块内原位替换。`--remove` 干净移除块并 normalize 空行。
**典型用法**: 配合 `specanchor-init.sh --install-boot=auto` 一步完成，或独立运行让现有项目升级激活方式。

### specanchor-status.sh

状态和覆盖率报告：

| 参数 | 说明 |
|------|------|
| `--config=<path>` | 配置文件路径（默认自动查找） |
| `--format=summary\|json` | 输出格式（默认 summary） |

输出内容: Global Spec 统计、Module Spec 覆盖率/健康度、Task Spec 统计、Spec Index 格式状态、默认 Assembly Trace

### specanchor-index.sh

生成/更新 spec-index.md（v3 block YAML frontmatter 格式）：

| 参数 | 说明 |
|------|------|
| `--config=<path>` | 配置文件路径（默认自动查找） |
| `--output=<path>` | 输出路径（默认 .specanchor/spec-index.md） |
| `--legacy-module-index` | 兼容模式：同时生成 deprecated .specanchor/module-index.md |

自动扫描 `.specanchor/global/`、`.specanchor/modules/`、`.specanchor/tasks/`，读取 frontmatter 和 SDD body phase marker，计算健康度（FRESH/DRIFTED/STALE/OUTDATED），生成 v3 索引文件。

### specanchor-boot.sh

启动检查（只读），输出项目 SpecAnchor 配置状态摘要：

| 参数 | 说明 |
|------|------|
| `--format=summary\|full\|json\|inline-brief` | 输出格式（默认 summary；`inline-brief` 为 ~600 token 内联摘要，用于 hook 注入） |
| `--tasks=open\|all\|none` | Active Tasks 渲染：`open` 折叠终态 done/archived 为计数（保留 draft/review/in_progress/未知非终态）；`none` 仅留计数行；`all` 全量。默认 summary/full=all（向后兼容、不改默认 shape），inline-brief=open。`--format=json` 不受影响 |
| `--with-schemas` | summary/full 中显式输出 schema 摘要（默认开启；保留 flag 用于向后兼容） |
| `--no-schemas` | 关闭 Available Schemas 段（精简输出场景） |

环境变量 `SPECANCHOR_SKILL_DIR` 指向 Skill 安装目录，用于查找内置 schemas。长参数应作为单个 shell 参数传入；`boot` 兼容误拆成 `-- format=summary` 的常见启动配置错误。无论 `summary` 还是 `full`，都显式输出本轮 Assembly Trace；`summary` 默认输出 `Available Commands:`、`Available Modules:` 与 `Available Schemas:`，把 quickref/module/schema lookup 降为 fallback；`full` 额外附带 Global Spec 正文。

### specanchor-check.sh

对齐检测工具，四种模式：

| 子命令 | 签名 | 用途 |
|--------|------|------|
| `task` | `task <spec-file> [--base=<branch>]` | 检查 Task Spec 的 File Changes 与 git diff 是否对齐 |
| `module` | `module <spec-file\|--all>` | 检查 Module Spec 新鲜度（FRESH/DRIFTED/STALE/OUTDATED） |
| `global` | `global [--config=<file>]` | 输出全局覆盖率报告 + 告警 |
| `coverage` | `coverage <file1> [file2...]` | 检查指定文件是否被 Module Spec 覆盖 |

**退出码**: 0=成功, 1=错误（参数/文件缺失）

### frontmatter-inject.sh

Layer 1 — Frontmatter 自动推断与注入：

| 模式 | 签名 | 用途 |
|------|------|------|
| 单文件 | `<file> [options]` | 为单个 Spec 文件注入 frontmatter |
| 批量 | `--dir <directory> [options]` | 为目录下所有 `.md` 文件批量注入 |

**关键选项**: `--dry-run`（预览）, `--force`（覆盖已有）, `--task-name`, `--status`, `--level`, `--migrate-sdd-phase`, `--normalize-task-status`

**自动推断字段**: level, author, created, branch, protocol, task_name, status, related_global, related_modules。SDD phase 不再写入 frontmatter，必须从 body 的 `> Current RIPER Phase: <PHASE>` marker 解析；section inference 仅作 legacy fallback。

### frontmatter-inject-and-check.sh

Layer 2 — 组合器，串联 Layer 1 注入 + specanchor-check.sh 检测：

| 阶段 | 行为 |
|------|------|
| Phase 1 | 调用 `frontmatter-inject.sh`（透传所有 Layer 1 参数） |
| Phase 2 | 自动推断 check level，调用 `specanchor-check.sh` |

**额外选项**: `--check-level`（覆盖检测粒度）, `--skip-check`（只注入不检测）, `--base`（task 检测基准分支）

### specanchor-doctor.sh

只读健康检查：

| 参数 | 说明 |
|------|------|
| `--format=text\|json\|markdown` | 输出格式（默认 text） |
| `--strict` | warning 也返回非零 |
| `--profile=default\|agent\|release\|maintainer` | 检查 profile（默认 default） |
| `--allow-dirty` | maintainer profile 允许工作树有未提交改动 |
| `--lint=context-control` | 跑 Harness Context Control lint（v0.5.0-beta.1+）：扫描所有 task spec，按 `anchor.yaml.context_control.enforce` 等级检查 6 区段（hard_boundaries / allowed_freedom / checkpoints_contract / decisions_log / evidence_ledger / handoff_packet）是否存在 |

**退出码**: 0=ok/非 strict warning, 1=strict warning, 2=blocking error, 64=参数错误

### specanchor-resolve.sh

最小 Anchor Resolution 引擎：

| 参数 | 说明 |
|------|------|
| `--files=<csv>` | 本轮目标文件列表 |
| `--intent=<text>` | 自然语言任务摘要 |
| `--format=text\|json` | 输出格式 |

返回应加载的 Global/Module/Sources 锚点，以及 missing 覆盖建议。`parasitic` 模式按 source path、已知 source file、简单 token 匹配顺序做 deterministic-first 解析。

### specanchor-assemble.sh

将 resolve 结果转换为 agent-ready context plan：

| 参数 | 说明 |
|------|------|
| `--files=<csv>` / `--files-from=<path>` | 本轮目标文件列表 |
| `--intent=<text>` / `--intent-file=<path>` | 自然语言任务摘要 |
| `--diff-from=<ref>` | 从 git diff 自动补充文件列表 |
| `--resolve-json=<path>` | 复用已生成的 resolve JSON |
| `--budget=compact\|normal\|full` | 上下文预算策略 |
| `--format=text\|markdown\|json` | 输出格式 |
| `--bundle-schema=assembly.v1\|context_bundle.v1` | JSON shape 选择（v0.6 新增；默认 assembly.v1 向后兼容） |
| `--max-findings=N` | v0.6：lazy-load findings 共享桶 cap（默认 50；`anchor.yaml.findings.max_per_bundle` 项目级覆写；immediate 桶不受 cap） |
| `--write-trace=<path>` | 写出 Assembly Trace |
| `--mode=handoff` | 切换到 Harness Context Control handoff 模式（v0.5.0-beta.1+） |
| `--task-spec=<path>` | handoff 模式：目标 Task Spec 路径 |
| `--write-back` | handoff 模式：把 packet 回写到 Task Spec §7.2 |

默认输出 bounded read plan、Assembly Trace 与 agent instructions，不直接读取或修改业务文件。`--mode=handoff` 输出 handoff packet（task name / phase / hot decisions / evidence status / next step），用于跨 session 接手。

**v0.6 lazy-load findings**（仅在 `--format=json --bundle-schema=context_bundle.v1` 且 `--files=` 非空时启用）：扫描 `.specanchor/findings/*.md`，按 `affects.path` / `affects.module` 命中目标文件分级载荷——`immediate→full / sediment_queue→summary / handoff→title`，`hidden` 不进 bundle。截断时以 `finding_cap_truncated:` 前缀追加到 `warnings[]`（保持 schema 向后兼容）。

**C3 full-load 行数硬上限**：`assembly_load_for_anchor` 在任何 level / 任何 `--budget` 档下，若某 anchor 本会 `full` 加载但行数 > `FULL_LOAD_MAX_LINES`（默认 220，`anchor.yaml.full_load_max_lines` 可覆写），统一降级 `summary`。这关闭了 `--budget=full` 此前完全忽略行数的缺口，保证单次 bundle bounded（对齐 §2 加载契约）。

### specanchor-finding.sh

v0.6 hot context 写回入口：

| 子命令 | 签名 | 用途 |
|--------|------|------|
| `new` | `new --topic=<slug> --summary=<text> [--type=...] [--confidence=...] [--impact=...] [--visibility=...] [--suggested-target=...]` | 生成 finding 骨架，自动赋 id 与 visibility，写入 `.specanchor/findings/` |

**`--summary` 必选**（≤120 字符单行；主语 + 事实 + 锚点；占位串 `<...>` 会被拒绝）。`--topic` 必选；其他字段有默认值。

### specanchor-sediment.sh

v0.6 hot→cold 安全回流入口：

| 子命令 | 签名 | 用途 |
|--------|------|------|
| `propose` | `propose --finding=<F-id> [--target=<spec-path>] [--operation=...] [--topic=...]` | 生成 sediment proposal 骨架；校验 source findings 存在；不自动 apply |

### specanchor-stop-triggers.sh

v0.7 advisory 风险路径检测：

| 参数 | 说明 |
|------|------|
| `--staged` / `--against=<ref>` | 检测变更范围（必选其一） |
| `--format=text\|json` | 输出格式 |

仅 advisory（不阻断），命中类别：public_api / schema / dependency / security_path。JSON 输出可被 Bundle v1 集成。

### specanchor-validate.sh

基础 schema/frontmatter 校验：

| 参数 | 说明 |
|------|------|
| `--format=text\|summary\|json` | 输出格式（`summary` 是 `text` 的别名） |
| `--path <file>` | 只校验单个文件 |
| `--strict` | warning 也返回非零 |

当前最小校验：`specanchor.level`、`module_path`、level-aware `status`、日期字段、frontmatter `sdd_phase` deprecation、`anchor.yaml` 版本字段。退出码：0=clean 或非 strict warning，1=strict warning，2=blocking error。

### specanchor-hygiene.sh

只读 spec drift / dead-link 巡检，输出 finding 列表（`severity / code / path`）：

| 参数 | 说明 |
|------|------|
| `--format=markdown\|text\|json` | 输出格式（默认 markdown；`text` 是 `markdown` 别名） |
| `--fix-generated` | 仅对自动生成产物（如 spec-index）尝试就地修复，其他 finding 仍只读 |

**职责边界**：纯巡检工具，不修改业务 spec；与 `specanchor-doctor.sh` 的区别——doctor 关注配置健康（anchor.yaml / 路径连通），hygiene 关注内容腐化（断链、生成产物过期）。

## 4. 内部状态

无持久化状态。脚本间通过文件系统和 stdout 交互。

## 5. 模块约定

- 颜色变量：统一在脚本顶部定义 `RED/GREEN/YELLOW/CYAN/DIM/BOLD/RESET`
- 工具函数：`die()`（错误退出）, `warn()`（警告）, `info()`（信息）, `success()`（成功）
- 配置解析：`find_config()` + `parse_yaml_field(file, field, default)`
- Frontmatter 解析：`parse_frontmatter_field(file, field)` + `parse_frontmatter_list(file, field)`
- 索引读取：运行时消费者必须通过 `sa_load_spec_index_or_legacy()` 与 `sa_iter_index_modules()` 优先读取 spec-index v3，legacy module-index 仅作 fallback

## 6. 约束

- Bash 3.2+ 兼容要求（避免 Bash 4-only 特性）
- YAML 解析仅支持单行简单值，不支持数组/嵌套
- `date` 命令跨平台：必须同时处理 macOS (`date -j`) 和 Linux (`date -d`)
- 脚本间层内依赖：Layer 2 依赖 Layer 1 和 check 脚本，通过 `SCRIPT_DIR` 相对路径定位

## 7. 代码结构

| 文件 | 职责 |
|------|------|
| `specanchor-init.sh` | 目录结构和配置初始化（半脚本化）；`--install-boot=<targets>` 钩子转发到 boot-install |
| `specanchor-boot-install.sh` | 幂等注入/移除 boot 触发块到 CLAUDE.md/AGENTS.md/GEMINI.md/cursor 规则 |
| `specanchor-status.sh` | 状态/覆盖率报告（summary/json） |
| `specanchor-index.sh` | spec-index.md 生成/更新（v3 格式，可选 legacy module-index） |
| `specanchor-boot.sh` | 启动检查（只读摘要输出） |
| `specanchor-check.sh` | Spec-Commit 对齐检测（task/module/global/coverage） |
| `frontmatter-inject.sh` | Frontmatter 自动推断与注入 Layer 1 |
| `frontmatter-inject-and-check.sh` | Layer 2 组合器（注入 + 检测） |
| `specanchor-doctor.sh` | 只读健康检查 |
| `specanchor-resolve.sh` | 锚点解析 |
| `specanchor-assemble.sh` | resolve 结果到 agent context plan 的装配器 |
| `specanchor-validate.sh` | 基础 schema/frontmatter 校验（含 v0.6 finding lint：candidate fail / 非 candidate warn 对称二分宽容期） |
| `specanchor-hygiene.sh` | 只读 spec drift / dead-link 巡检（可选修复 generated 产物） |
| `specanchor-finding.sh` | v0.6 finding 骨架生成（`new` 子命令；`--summary` 必选） |
| `specanchor-sediment.sh` | v0.6 sediment proposal 骨架生成（`propose` 子命令） |
| `specanchor-stop-triggers.sh` | v0.7 advisory 风险路径检测（public_api / schema / dependency / security_path） |
| `lib/common.sh` | 跨脚本共享函数库 |
| `lib/decision-filter.sh` | Harness Context Control：Task Spec §5.2 hot/cold/superseded/withdrawn 分类（双重接口 lib + CLI） |
| `lib/evidence-filter.sh` | Harness Context Control：Task Spec §6.2 4 子段解析 + hot/cold 分类（双重接口 lib + CLI） |
| `lib/finding-parser.sh` | v0.6：共享 `parse_finding_frontmatter()` 解析器，被 validate.sh / assemble.sh / doctor.sh 复用 |

## 8. 已知问题（待修复）

- 老脚本仍有重复的 `parse_yaml_field()` / `find_config()`，可逐步收敛到 `scripts/lib/common.sh`
- `frontmatter-inject.sh` 的 trap 在循环中被覆盖，可能导致 tmpfile 泄漏
- `specanchor-check.sh` 的 `check_task` 使用双向子串匹配，可能产生假阳性
- `usage()` 在 `specanchor-check.sh` 中引用未初始化的配置变量
