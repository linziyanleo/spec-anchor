---
specanchor:
  level: global
  type: project-setup
  version: "1.3.0"
  author: "maintainers"
  reviewers: []
  last_synced: "2026-04-27"
  last_change: "更新 spec-index v3 初始化、索引生成与严格校验命令"
  applies_to: "**/*"
---

# 项目启动指南

## 基本信息
- 项目名称：spec-anchor (SpecAnchor)
- 项目类型：AI Agent Skill（纯 Markdown + Shell 脚本，无编译 / 构建步骤）
- 本地运行：无 dev server，脚本直接 `bash scripts/<name>.sh` 执行

## 环境要求
- Shell：Bash 3.2+（macOS 系统 Bash 可直接跑）
- Git：任意现代版本
- Python 3：用于 JSON 校验（CI 必备，本地可选）
- 测试框架：`bash tests/run.sh`（bats-core 仅作补充回归）
- 可选：ShellCheck（`brew install shellcheck`）用于静态分析

## 常用命令
- 初始化：`bash scripts/specanchor-init.sh --project=<name>`
- 启动检查：`bash scripts/specanchor-boot.sh`
- 状态报告：`bash scripts/specanchor-status.sh`
- 健康检查：`bash scripts/specanchor-doctor.sh`
- 严格健康检查：`bash scripts/specanchor-doctor.sh --strict`
- 锚点解析：`bash scripts/specanchor-resolve.sh --files=... --intent=...`
- 基础校验：`bash scripts/specanchor-validate.sh`
- 严格校验：`bash scripts/specanchor-validate.sh --strict`
- 索引生成：`bash scripts/specanchor-index.sh`（生成 `.specanchor/spec-index.md`）
- 兼容索引生成：`bash scripts/specanchor-index.sh --legacy-module-index`（同时生成 deprecated `.specanchor/module-index.md`）
- 对齐检测：`bash scripts/specanchor-check.sh <task|module|global|coverage>`
- Frontmatter 注入：`bash scripts/frontmatter-inject.sh <file|--dir path>`
- 注入+检测：`bash scripts/frontmatter-inject-and-check.sh --dir <path>`
- 回归测试：`bash tests/run.sh`
- 完整底层回归：`SPECANCHOR_RUN_BATS=1 bash tests/run_all.sh`

## 开发约定
- 分支策略：main 为主分支，feature 分支 → PR → merge
- 提交格式：`<type>(<scope>): <subject>`（详见 coding-standards.spec.md）
- Spec 工作流：修改代码前创建/加载 Task Spec → 修改后运行 `specanchor-check.sh`
