---
specanchor:
  level: module
  module_name: "scripts"
  module_path: "scripts/"
  version: "1.0.0"
  owner: "@fanghu"
  created: "2026-04-02"
  status: active
  last_synced: "2026-04-02"
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

## 4. 内部状态

无持久化状态。脚本间通过文件系统和 stdout 交互。

## 5. 模块约定

- 颜色变量：统一在脚本顶部定义 `RED/GREEN/YELLOW/CYAN/DIM/BOLD/RESET`
- 工具函数：`die()`（错误退出）, `warn()`（警告）, `info()`（信息）, `success()`（成功）
- 配置解析：`find_config()` + `parse_yaml_field(file, field, default)`
- Frontmatter 解析：`parse_frontmatter_field(file, field)` + `parse_frontmatter_list(file, field)`

## 6. 约束

- Bash 4+ 要求（macOS 默认 Bash 3，需 Homebrew 安装）
- YAML 解析仅支持单行简单值，不支持数组/嵌套
- `date` 命令跨平台：必须同时处理 macOS (`date -j`) 和 Linux (`date -d`)
- 脚本间层内依赖：Layer 2 依赖 Layer 1 和 check 脚本，通过 `SCRIPT_DIR` 相对路径定位

## 7. 代码结构

| 文件 | 行数 | 职责 |
|------|------|------|
| `specanchor-check.sh` | ~548 | Spec-Commit 对齐检测（task/module/global/coverage） |
| `frontmatter-inject.sh` | ~581 | Frontmatter 自动推断与注入 Layer 1 |
| `frontmatter-inject-and-check.sh` | ~207 | Layer 2 组合器（注入 + 检测） |

## 8. 已知问题（待修复）

- `parse_yaml_field()` 在两个脚本中重复定义，应提取到 `scripts/lib/common.sh`
- `frontmatter-inject.sh` 的 trap 在循环中被覆盖，可能导致 tmpfile 泄漏
- `specanchor-check.sh` 的 `check_task` 使用双向子串匹配，可能产生假阳性
- `detect_sdd_phase()` 硬编码章节号，与 Schema 模板耦合
- `usage()` 在 `specanchor-check.sh` 中引用未初始化的配置变量
