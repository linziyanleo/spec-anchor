---
specanchor:
  level: module
  module_name: "scripts"
  module_path: "scripts/"
  summary: "Shell 自动化工具层：初始化、状态/诊断、索引、对齐检测、Frontmatter、解析与校验"
  version: "2.1.0"
  owner: "maintainers"
  created: "2026-04-02"
  status: active
  last_synced: "2026-04-21"
  last_change: "full-mode init 现在会种下 starter Global Specs，validate 支持 summary，resolve 支持 parasitic source-file fallback"
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

## 3. 公开接口（脚本入口）

### specanchor-init.sh

目录和配置初始化（半脚本化）：

| 参数 | 说明 |
|------|------|
| `--project=<name>` | 项目名称（默认取当前目录名） |
| `--mode=full\|parasitic` | 运行模式（默认 full） |
| `--scan-sources` | 扫描检测已有 spec 体系 |

**脚本处理**: 目录创建、anchor.yaml 生成、module-index.md 初始化、来源检测
**脚本处理**: 目录创建、anchor.yaml 生成、starter Global Specs、module-index.md 初始化、来源检测
**Agent 处理**: 来源策略确认、细化 starter Global Specs（需代码分析）

### specanchor-status.sh

状态和覆盖率报告：

| 参数 | 说明 |
|------|------|
| `--config=<path>` | 配置文件路径（默认自动查找） |
| `--format=summary\|json` | 输出格式（默认 summary） |

输出内容: Global Spec 统计、Module Spec 覆盖率/健康度、Task Spec 统计、Module Index 格式状态、默认 Assembly Trace

### specanchor-index.sh

生成/更新 module-index.md（v2 YAML frontmatter 格式）：

| 参数 | 说明 |
|------|------|
| `--config=<path>` | 配置文件路径（默认自动查找） |
| `--output=<path>` | 输出路径（默认 .specanchor/module-index.md） |

自动扫描 `.specanchor/modules/` 下所有 Module Spec，读取 frontmatter，计算健康度（FRESH/DRIFTED/STALE/OUTDATED），生成 v2 格式索引文件。

### specanchor-boot.sh

启动检查（只读），输出项目 SpecAnchor 配置状态摘要：

| 参数 | 说明 |
|------|------|
| `--format=summary\|full\|json` | 输出格式（默认 summary） |

环境变量 `SPECANCHOR_SKILL_DIR` 指向 Skill 安装目录，用于查找内置 schemas。无论 `summary` 还是 `full`，都显式输出本轮 Assembly Trace；`full` 额外附带 Global Spec 正文。

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

**关键选项**: `--dry-run`（预览）, `--force`（覆盖已有）, `--task-name`, `--status`, `--level`

**自动推断字段**: level, author, created, branch, protocol, task_name, sdd_phase, status, related_global, related_modules

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
| `--format=text\|json` | 输出格式（默认 text） |
| `--strict` | warning 也返回非零 |

**退出码**: 0=ok/非 strict warning, 1=strict warning, 2=blocking error, 64=参数错误

### specanchor-resolve.sh

最小 Anchor Resolution 引擎：

| 参数 | 说明 |
|------|------|
| `--files=<csv>` | 本轮目标文件列表 |
| `--intent=<text>` | 自然语言任务摘要 |
| `--format=text\|json` | 输出格式 |

返回应加载的 Global/Module/Sources 锚点，以及 missing 覆盖建议。`parasitic` 模式按 source path、已知 source file、简单 token 匹配顺序做 deterministic-first 解析。

### specanchor-validate.sh

基础 schema/frontmatter 校验：

| 参数 | 说明 |
|------|------|
| `--format=text\|summary\|json` | 输出格式（`summary` 是 `text` 的别名） |
| `--path <file>` | 只校验单个文件 |

当前最小校验：`specanchor.level`、`module_path`、`status`、日期字段、`anchor.yaml` 版本字段。

## 4. 内部状态

无持久化状态。脚本间通过文件系统和 stdout 交互。

## 5. 模块约定

- 颜色变量：统一在脚本顶部定义 `RED/GREEN/YELLOW/CYAN/DIM/BOLD/RESET`
- 工具函数：`die()`（错误退出）, `warn()`（警告）, `info()`（信息）, `success()`（成功）
- 配置解析：`find_config()` + `parse_yaml_field(file, field, default)`
- Frontmatter 解析：`parse_frontmatter_field(file, field)` + `parse_frontmatter_list(file, field)`

## 6. 约束

- Bash 3.2+ 兼容要求（避免 Bash 4-only 特性）
- YAML 解析仅支持单行简单值，不支持数组/嵌套
- `date` 命令跨平台：必须同时处理 macOS (`date -j`) 和 Linux (`date -d`)
- 脚本间层内依赖：Layer 2 依赖 Layer 1 和 check 脚本，通过 `SCRIPT_DIR` 相对路径定位

## 7. 代码结构

| 文件 | 职责 |
|------|------|
| `specanchor-init.sh` | 目录结构和配置初始化（半脚本化） |
| `specanchor-status.sh` | 状态/覆盖率报告（summary/json） |
| `specanchor-index.sh` | module-index.md 生成/更新（v2 格式） |
| `specanchor-boot.sh` | 启动检查（只读摘要输出） |
| `specanchor-check.sh` | Spec-Commit 对齐检测（task/module/global/coverage） |
| `frontmatter-inject.sh` | Frontmatter 自动推断与注入 Layer 1 |
| `frontmatter-inject-and-check.sh` | Layer 2 组合器（注入 + 检测） |
| `specanchor-doctor.sh` | 只读健康检查 |
| `specanchor-resolve.sh` | 锚点解析 |
| `specanchor-validate.sh` | 基础 schema/frontmatter 校验 |

## 8. 已知问题（待修复）

- 老脚本仍有重复的 `parse_yaml_field()` / `find_config()`，可逐步收敛到 `scripts/lib/common.sh`
- `frontmatter-inject.sh` 的 trap 在循环中被覆盖，可能导致 tmpfile 泄漏
- `specanchor-check.sh` 的 `check_task` 使用双向子串匹配，可能产生假阳性
- `detect_sdd_phase()` 硬编码章节号，与 Schema 模板耦合
- `usage()` 在 `specanchor-check.sh` 中引用未初始化的配置变量
