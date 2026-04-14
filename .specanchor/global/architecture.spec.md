---
specanchor:
  level: global
  type: architecture
  version: "2.0.0"
  author: "@fanghu"
  reviewers: []
  last_synced: "2026-04-14"
  last_change: "职责收口：明确 extensions/ 为独立 skill，不由主 Skill 路由"
  applies_to: "**/*"
---

# 架构约定

## 四层架构
1. **Core 层**（`SKILL.md`）：入口、路由、工作流选择、门禁，不含实现细节
2. **Protocol 层**（`references/`）：协议、命令定义、模板——纯声明式，不含脚本
3. **Scripts 层**（`scripts/`）：自动化工具——纯命令式，不依赖 Skill 上下文
4. **Extension 层**（`extensions/`）：与主 Skill 并列维护的独立 skill，不由主 Skill 路由

## 层间依赖规则
- Core → Protocol：Core 引用 Protocol 文件路径，按需读取
- Core → Scripts：Core 指引 Agent 调用脚本，不直接执行
- Core ↛ Extension：主 Skill 不负责加载独立 workflow skill
- Protocol → Scripts：Protocol 文件可声明"应调用某脚本"（如 `specanchor_check` 命令定义引用 `specanchor-check.sh`），但 Protocol 本身不执行脚本
- Scripts → 无外部依赖：脚本不依赖 Skill 上下文或 Agent，仅读取 anchor.yaml 和文件系统
- Scripts → 层内依赖允许：组合脚本（如 Layer 2）可调用同层其他脚本，共享库 `scripts/lib/` 可被 source
- Extension → Protocol：Extension 可引用 Protocol 层的模板和配置

## .specanchor/ 内部结构
- `global/`：Global Spec 存放（合计 ≤ 200 行）
- `modules/`：Module Spec 集中存放，文件名由路径转换（`/` → `-`）
- `tasks/<module>/`：Task Spec 按模块分组
- `tasks/_cross-module/`：跨模块 Task Spec
- `archive/`：已完成的 Task Spec 归档
- `module-index.md`：模块索引（v2 结构化格式：YAML frontmatter 含模块列表与健康度统计 + Markdown 渲染表格，必须与 `modules/` 目录保持同步）
- `project-codemap.md`：项目架构可视化

## 路径约定
- Skill 内路径（`references/`、`scripts/`）相对于 SKILL.md 所在目录
- 项目路径（`.specanchor/`、`anchor.yaml`）相对于用户工作区根目录
- Extension 内路径相对于 Extension 自己的 SKILL.md 所在目录

## 扩展性约定
- 新命令：在 `references/commands/` 添加 `<cmd>.md`，在 quickref 注册
- 新 Schema：在 `references/schemas/<name>/` 添加 `schema.yaml` + `template.md`
- 新扩展：在 `extensions/<name>/` 添加 `SKILL.md` + 子目录

## 向后兼容
- `.specanchor/config.yaml` → `anchor.yaml` 迁移期间保持双路径查找
- DEPRECATED 文件保留但标注废弃，不删除
