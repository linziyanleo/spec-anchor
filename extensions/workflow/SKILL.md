---
name: spec-anchor-workflow-extension
description: 独立的 SpecAnchor 开发工作流 Skill，负责代码提交、代码评审、开发服务器启停。仅在用户明确需要提交、评审、启动项目或停止项目等工作流操作时使用。
---

# SpecAnchor Workflow Extension

独立工作流 skill，为使用 SpecAnchor 的项目提供代码提交、评审、开发服务器管理能力。

这是独立 skill，不由主 SKILL.md 路由。

## 路径约定

本文件中的路径相对于**本文件所在目录**（即 `extensions/workflow/`），而非 Skill 根目录或用户工作区。例如 `references/commands/commit_push.md` 指的是 `extensions/workflow/references/commands/commit_push.md`。

唯一例外：`.specanchor/` 和 `project-setup.spec.md` 等项目配置路径相对于用户工作区根目录。

## 依赖

- `.specanchor/global/project-setup.spec.md`：提供项目启动命令、本地地址，以及可选的 CR 配置提示
- 如果 `project-setup.spec.md` 不存在，提示用户先执行 `specanchor_global`（project-setup 类型）生成

## 命令

| 命令 | 用途 | 触发词 | 详细定义 |
|------|------|--------|----------|
| `workflow_commit_push` | 分析变更并提交推送 | 提交 / push / commit | `references/commands/commit_push.md` |
| `workflow_submit_cr` | 提交代码评审 | 评审 / CR / 代码评审 | `references/commands/submit_cr.md` |
| `workflow_start_dev` | 启动开发服务器 | 启动项目 / start / dev | `references/commands/start_dev.md` |
| `workflow_stop_dev` | 停止开发服务器 | 停止项目 / stop | `references/commands/stop_dev.md` |

## 平台适配

CR 命令的具体执行方式由用户项目配置驱动：
- `project-setup.spec.md` 可选声明 CR 脚本路径、目标分支、评审人
- 扩展只负责：检查代码状态 → 提交变更 → 调用用户配置的 CR 命令 → 提取结果
- 如果用户项目没有 CR 脚本，自动从 `scripts/codereview.sh.template` 复制并引导用户配置

## 脚本管理

以下脚本由 workflow skill 在需要时按需检查/生成：

| 脚本 | 生成时机 | 目标 | 用途 |
|------|----------|------|------|
| `codereview.sh` | 首次执行 `workflow_submit_cr` 且脚本缺失时 | 项目根目录 | CR 评审脚本（基于模板 + 用户配置生成） |

模板位置：`scripts/codereview.sh.template`（相对于本文件所在目录）。如果用户项目已有这些脚本则跳过生成。

## 推荐流程

1. "启动项目" → 读取配置并启动开发服务器
2. 开发过程（按 SpecAnchor Spec 管理流程）
3. "提交代码" → 分析变更，生成 commit message，提交推送
4. "提交代码评审" → 执行 CR 脚本，展示链接
5. "停止项目" → 停止开发服务器
