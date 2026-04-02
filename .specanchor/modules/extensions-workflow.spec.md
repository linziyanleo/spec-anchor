---
specanchor:
  level: module
  module_name: "工作流扩展"
  module_path: "extensions/workflow/"
  version: "1.0.0"
  owner: "@fanghu"
  author: "@fanghu"
  reviewers: []
  created: "2026-04-02"
  updated: "2026-04-02"
  last_synced: "2026-04-02"
  last_change: "初始创建 — Skill 专家审计后补全"
  status: active
  depends_on:
    - "references/"
---

# Module Spec: extensions/workflow/ (工作流扩展)

## 1. 职责

为 SpecAnchor 提供开发工作流能力：代码提交推送、代码评审、开发服务器启停。作为可选扩展存在，由主 SKILL.md 按需路由加载，不独立触发。

## 2. 业务规则

- 扩展启动时检查 `.specanchor/global/project-setup.spec.md` 存在性，缺失则引导用户先生成
- CR 脚本由用户项目持有（`codereview.sh`），首次运行时从模板生成，后续不自动修改
- 命令执行前检查 git 工作区状态（是否有未暂存/未提交的变更）
- 扩展内路径相对于 `extensions/workflow/`，非 Skill 根目录

## 3. 公开接口

### 3.1 工作流命令

| 命令 | 触发词 | 定义文件 | 前置条件 |
|------|--------|----------|----------|
| `workflow_commit_push` | 提交 / push / commit | `references/commands/commit_push.md` | 有未提交变更 |
| `workflow_submit_cr` | 评审 / CR | `references/commands/submit_cr.md` | 已提交且有 CR 脚本 |
| `workflow_start_dev` | 启动项目 / start | `references/commands/start_dev.md` | project-setup 配置存在 |
| `workflow_stop_dev` | 停止项目 / stop | `references/commands/stop_dev.md` | 有运行中的 dev server |

### 3.2 脚本模板

| 文件 | 用途 |
|------|------|
| `scripts/codereview.sh.template` | CR 脚本模板（Gerrit 风格，含 GitHub/GitLab 注释示例） |

## 4. 内部状态

无持久化状态。通过读取 `project-setup.spec.md` 获取运行时配置（启动命令、本地地址、评审人）。

## 5. 模块约定

- 扩展内部遵循主 Skill 相同的四层架构：SKILL.md（入口） → references/（命令定义） → scripts/（模板）
- 命令定义结构与主 Skill 的 `references/commands/` 格式一致
- 新增命令需同时更新主 Skill 的 `commands-quickref.md` 工作流命令段

## 6. 约束

- 依赖 `project-setup.spec.md`：缺失时所有命令（除 `workflow_stop_dev`）被阻断
- CR 脚本模板默认 Gerrit 风格，用户需手动修改适配 GitHub PR / GitLab MR
- 扩展不访问 Module Spec 或 Task Spec，只读取 Global Spec 中的项目配置

## 7. 代码结构

| 路径 | 文件数 | 职责 |
|------|--------|------|
| `SKILL.md` | 1 | 扩展入口 + 命令路由 |
| `references/commands/` | 4 个 .md | 各工作流命令的详细定义 |
| `scripts/` | 1 个 .template | CR 脚本模板 |

## 8. 已知问题

- CR 模板使用 `eval "$command"` 执行拼接命令，存在注入风险（评审人名含特殊字符时）
- 模板中 `#!/bin/bash` 而非 `#!/usr/bin/env bash`，与 coding-standards 规定不一致
- `start_dev` / `stop_dev` 的进程管理依赖 Agent 记忆 PID，无持久化机制
