# SpecAnchor Workflow Extension

开发工作流扩展，为 SpecAnchor 提供代码提交、评审、开发服务器管理能力。

此扩展通过 SpecAnchor 主 Skill 按需加载，不独立触发。

## 依赖

- `.specanchor/global/project-setup.spec.md`：提供项目启动命令、本地地址、评审人等配置
- 如果 `project-setup.spec.md` 不存在，提示用户先执行 `specanchor_global`（project-setup 类型）生成

## 需求复杂度评估

执行开发任务前，先评估需求复杂度以选择合适流程：

**简单需求**（快速流程）：单文件修改、样式调整、单个 bug 修复、简单配置修改、不涉及架构变更、预计 < 2 小时

**复杂需求**（标准流程）：新增功能模块、多文件修改、架构设计、数据流变更、API 接口设计、多模块协作、预计 >= 2 小时

- 简单需求：直接执行相应命令，无需创建 Task Spec
- 复杂需求：先执行 `specanchor_task` 创建 Task Spec，按 RIPER 流程执行

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
- 如果用户项目没有 CR 脚本，自动从 `extensions/workflow/scripts/codereview.sh.template` 复制并引导用户配置

## 脚本管理

以下脚本在 `specanchor_global`（project-setup 类型）执行时自动生成到用户项目，后续不再自动修改：

| 脚本 | 生成时机 | 目标 | 用途 |
|------|----------|------|------|
| `codereview.sh` | project-setup 初始化时 | 项目根目录 | CR 评审脚本（基于模板 + 用户配置生成） |
| `specanchor-check.sh` | project-setup 初始化时 | 项目 `scripts/` 目录 | Spec-代码对齐检测 |

模板位置：`extensions/workflow/scripts/codereview.sh.template`。如果用户项目已有这些脚本则跳过生成。

## 推荐流程

1. "启动项目" → 读取配置并启动开发服务器
2. 开发过程（按 SpecAnchor Spec 管理流程）
3. "提交代码" → 分析变更，生成 commit message，提交推送
4. "提交代码评审" → 执行 CR 脚本，展示链接
5. "停止项目" → 停止开发服务器
