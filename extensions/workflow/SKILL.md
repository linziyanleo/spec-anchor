# SpecAnchor Workflow Extension

开发工作流扩展，为 SpecAnchor 提供代码提交、评审、开发服务器管理能力。

此扩展通过 SpecAnchor 主 Skill 按需加载，不独立触发。

## 路径约定

本文件中的路径相对于**本文件所在目录**（即 `extensions/workflow/`），而非 Skill 根目录或用户工作区。例如 `references/commands/commit_push.md` 指的是 `extensions/workflow/references/commands/commit_push.md`。

唯一例外：`.specanchor/` 和 `project-setup.spec.md` 等项目配置路径相对于用户工作区根目录。

## 依赖

- `.specanchor/global/project-setup.spec.md`：提供项目启动命令、本地地址、评审人等配置
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
- CR 脚本路径和参数格式在 `project-setup.spec.md` 中声明
- 扩展只负责：检查代码状态 → 提交变更 → 调用用户配置的 CR 命令 → 提取结果
- 如果用户项目没有 CR 脚本，自动从 `scripts/codereview.sh.template` 复制并引导用户配置

## 脚本管理

以下脚本在 `specanchor_global`（project-setup 类型）执行时自动生成到用户项目，后续不再自动修改：

| 脚本 | 生成时机 | 目标 | 用途 |
|------|----------|------|------|
| `codereview.sh` | project-setup 初始化时 | 项目根目录 | CR 评审脚本（基于模板 + 用户配置生成） |
| `specanchor-check.sh` | project-setup 初始化时 | 项目 `scripts/` 目录 | Spec-代码对齐检测 |

模板位置：`scripts/codereview.sh.template`（相对于本文件所在目录）。如果用户项目已有这些脚本则跳过生成。

## 推荐流程

1. "启动项目" → 读取配置并启动开发服务器
2. 开发过程（按 SpecAnchor Spec 管理流程）
3. "提交代码" → 分析变更，生成 commit message，提交推送
4. "提交代码评审" → 执行 CR 脚本，展示链接
5. "停止项目" → 停止开发服务器
