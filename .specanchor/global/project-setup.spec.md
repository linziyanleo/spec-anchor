---
specanchor:
  level: global
  type: project-setup
  version: "1.0.0"
  author: "@fanghu"
  reviewers: []
  last_synced: "2026-04-02"
  last_change: "初始创建 — Skill 专家审计后补全"
  applies_to: "**/*"
---

# 项目启动指南

## 基本信息
- 项目名称：spec-anchor (SpecAnchor)
- 项目类型：AI Agent Skill（纯 Markdown + Shell 脚本，无编译 / 构建步骤）
- 本地运行：无 dev server，脚本直接 `bash scripts/<name>.sh` 执行
- 默认代码评审人：@fanghu

## 环境要求
- Shell：Bash 4+（macOS 需 `brew install bash`，系统自带为 3.x）
- Git：任意现代版本
- 测试框架：bats-core（`brew install bats-core`）
- 可选：ShellCheck（`brew install shellcheck`）用于静态分析

## 常用命令
- 脚本执行：`bash scripts/specanchor-check.sh <subcommand>`
- Frontmatter 注入：`bash scripts/frontmatter-inject.sh <file|--dir path>`
- 注入+检测：`bash scripts/frontmatter-inject-and-check.sh --dir <path>`
- 回归测试：`bash tests/run_all.sh`（待建）

## 开发约定
- 分支策略：main 为主分支，feature 分支 → PR → merge
- 提交格式：`<type>(<scope>): <subject>`（详见 coding-standards.spec.md）
- Spec 工作流：修改代码前创建/加载 Task Spec → 修改后运行 `specanchor-check.sh`
