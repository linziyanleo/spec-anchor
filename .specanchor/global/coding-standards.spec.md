---
specanchor:
  level: global
  type: coding-standards
  version: "2.2.0"
  author: "maintainers"
  reviewers: []
  last_synced: "2026-04-27"
  last_change: "补充 spec-index v3、严格校验与 Bash 3.2 phase parser 约束"
  applies_to: "scripts/**/*.sh, **/*.md"
---

# 编码规范

## 技术栈
- Shell 脚本：Bash 3.2+ 兼容，`set -euo pipefail` 强制
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
- Bash 正则：必须兼容 macOS Bash 3.2，使用 POSIX 字符类或显式枚举；不得依赖 `\w` 等不可移植扩展
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

## 测试约定
- 公共回归入口：`bash tests/run.sh`
- Step 1 smoke gate：仓库根 `specanchor-boot.sh --format=summary` 不应再打印缺失 source 的 `✗`
- 发布面文档契约：`README.md` / `README_ZH.md` / `CHANGELOG.md` / `docs/release/*` 属于公开 release surface；改动这些文件后，必须先本地跑通 `bash tests/run.sh`
- consumer 安装链路：按 `.skillexclude` 安装到临时项目后，`specanchor-init.sh` + `specanchor-boot.sh` 必须通过
- legacy Bats 补充面：索引、frontmatter、init、status 等底层行为变更后必须跑 `SPECANCHOR_RUN_BATS=1 bash tests/run_all.sh`，除非明确退役对应 suite
- 严格校验：`specanchor-validate.sh --strict` 遇到 warning 返回 1，遇到 blocking error 返回 2；非 strict warning 仍返回 0
- 夹具目录：`tests/fixtures/*`
- 断言工具：`tests/helpers/assert.sh`
- 旧的 `tests/test_*.bats` 可保留为补充回归，但 CI 不依赖 bats-core
- 测试隔离：使用 `mktemp -d` 创建临时工作区并在退出时清理

## 脚本驱动边界
- 结构化数据操作（YAML 解析、日期计算、文件扫描）→ 脚本驱动
- 代码语义分析和 Spec 内容生成 → 模型驱动
- 两者混合时，脚本处理确定性部分，模型处理需要推理的部分

## Git 提交约定
- 格式：`<type>(<scope>): <subject>`
- type：feat / fix / docs / refactor / test / chore
- scope：skill / scripts / schemas / workflow / protocol / spec
