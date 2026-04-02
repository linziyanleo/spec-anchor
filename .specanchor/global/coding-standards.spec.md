---
specanchor:
  level: global
  type: coding-standards
  version: "2.0.0"
  author: "@fanghu"
  reviewers: []
  last_synced: "2026-04-02"
  last_change: "审计后全面更新：补充错误处理、tmpfile、共享函数、参数风格约定"
  applies_to: "scripts/**/*.sh, **/*.md"
---

# 编码规范

## 技术栈
- Shell 脚本：Bash 4+，`set -euo pipefail` 强制
- 文档：Markdown (YAML frontmatter)
- 配置：YAML (`anchor.yaml`, `schema.yaml`)

## Shell 脚本约定
- 首行 shebang：`#!/usr/bin/env bash`
- 颜色输出：TTY 检测 `[[ -t 1 ]]`，非终端时静默
- 日期处理：macOS `date -j` + Linux `date -d` 双路径 fallback，失败时必须有安全默认值（不得产生 epoch=0）
- 错误退出：`die()` 函数统一错误输出到 stderr
- 静默吞错：`|| true` 和 `|| echo ""` 仅用于非关键路径（如 warning 级别的检测），关键路径必须 `die()`
- 临时文件：`mktemp` 创建，cleanup 函数中统一清理（不在循环内反复 `trap`，应使用数组收集后统一清理）
- 配置查找：`find_config()` 双路径（anchor.yaml → .specanchor/config.yaml）
- YAML 解析：`parse_yaml_field()` 仅用于单行简单值，复杂结构（数组/嵌套）应避免在 Bash 中解析
- 共享函数：跨脚本复用的函数（如 `parse_yaml_field`、`find_config`、颜色定义）应提取到 `scripts/lib/common.sh`，通过 `source` 引入
- CLI 入口风格：顶层命令用 positional subcommand（`check task`），选项用 `--long-opt` 风格，不混用

## Markdown 约定
- Spec 文件必须有 `specanchor:` YAML frontmatter
- 模板中使用 `<placeholder>` 标记需填充的占位符
- 章节编号格式：`## N. 标题` 或 `## §N 标题`

## 命名约定
- 脚本文件：kebab-case（`specanchor-check.sh`）
- 命令名：snake_case（`specanchor_init`）
- Spec 文件：`<module-id>.spec.md`（Module）/ `<type>.spec.md`（Global）
- Schema 目录：kebab-case（`sdd-riper-one/`）
- 共享库：`scripts/lib/<name>.sh`

## Git 提交约定
- 格式：`<type>(<scope>): <subject>`
- type：feat / fix / docs / refactor / test / chore
- scope：skill / scripts / schemas / workflow / protocol
