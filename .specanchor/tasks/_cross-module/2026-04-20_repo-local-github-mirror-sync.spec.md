---
specanchor:
  level: task
  task_name: "repo-local GitHub mirror sync"
  author: "@fanghu"
  created: "2026-04-20"
  status: "done"
  last_change: "分支级历史重写同步与 repo-local hooks 已落地，真实 post-commit / pre-push 触发验证通过"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "simple"
  branch: "main"
---

# Task: repo-local GitHub mirror sync

## 目标
为当前 `spec-anchor` 仓库增加一套仅仓库自用的 GitHub 镜像同步机制：在 `spec-anchor/` 的提交、合并、改写历史和推送后，`spec-anchor-github/` 对应分支也自动更新并按 GitHub author 重写历史。

## 范围
- **In-Scope**: repo-local 同步脚本、repo-local hooks、repo-local bats 测试、任务执行记录
- **Out-of-Scope**: `SKILL.md`、`references/`、`scripts/`、`README*` 等随 Skill 分发的文件；Git 原生多作者同一 commit；跨机器自动部署

## 改动计划
| 文件 | 变更说明 |
|------|---------|
| `.specanchor/devtools/sync-github-mirror.sh` | repo-local 分支同步脚本，按 mirror author 重写整条分支历史并更新本地 / 远端 GitHub mirror |
| `.git/hooks/post-commit` 等本地 hook | 在提交、merge、rebase/amend、push 时自动触发同步 |
| `tests/test_github_mirror_sync.bats` | 覆盖主链：merge commit、非当前分支同步、push、幂等重跑、脏工作区保护 |
| `.specanchor/tasks/_cross-module/2026-04-20_repo-local-github-mirror-sync.spec.md` | 记录边界、执行日志和验证结果 |

## Checklist
- [x] 1. 新增 repo-local GitHub 镜像同步脚本
- [x] 2. 安装 repo-local 自动同步 hooks
- [x] 3. 更新 bats 测试覆盖 merge / branch / push 链路
- [x] 4. 跑定向验证并回填执行记录

## 完成确认
- [x] 不修改随 Skill 分发的文件
- [x] `git commit` / `git push` 触发 mirror 自动同步
- [x] 定向测试通过

## 备注
- 这轮只针对当前仓库，不把同步能力做进 Skill 本体
- GitHub 镜像仓库固定为 `linziyanleo/spec-anchor`

## 执行记录
- 首版 `.specanchor/devtools/sync-github-mirror.sh` 已完成首次历史迁移，但在线性重放模式下遇到 merge commit 阻断，证明“增量 cherry-pick”不足以覆盖当前仓库的真实提交拓扑
- 现阶段改为“分支级历史重写”方案：每次按 source 分支生成带 GitHub author 的 mirror 分支，并配合 repo-local hook 自动触发
- 实际生效的 hook 路径来自 `.git/config` 中的 `core.hooksPath=.githooks`，因此 repo-local 自动同步 hooks 安装到 `.githooks/`，并通过 `.git/info/exclude` 保持本地可见但不污染 `git status`
- repo-local hooks：
  - `post-commit` / `post-merge` / `post-rewrite` → 同步当前 source 分支到本地 mirror checkout
  - `pre-push` → 解析本次将要 push 的本地分支，并把对应 rewritten 分支推到 GitHub origin
- 新版 `tests/test_github_mirror_sync.bats` 已覆盖 merge commit、非当前分支同步、幂等重跑、push、mirror 脏工作区保护
- 验证通过：`bash -n .specanchor/devtools/sync-github-mirror.sh`、`bash -n .githooks/github-mirror-sync`、`bats tests/test_github_mirror_sync.bats`、`git diff --check`
- 真实仓库触发验证通过：`bash .githooks/post-commit` 返回 `Already synced: main @ 01b0407`；`printf ... | bash .githooks/pre-push ...` 返回 `Already synced: main @ 01b0407` + `Pushed origin/main`
- 确认 `.gitignore` 已忽略 `/tests/` 和 `.specanchor/`，因此本轮新增文件默认仅在当前 checkout 生效
