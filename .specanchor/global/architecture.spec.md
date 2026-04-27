---
specanchor:
  level: global
  type: architecture
  version: "2.3.0"
  author: "maintainers"
  reviewers: []
  last_synced: "2026-04-27"
  last_change: "将内部索引主契约迁移到 spec-index.md v3，并保留 module-index.md 兼容 fallback"
  applies_to: "**/*"
---

# 架构约定

## 三层主架构

1. **Core 层**（`SKILL.md`）：入口、路由、工作流选择、门禁，不含实现细节
2. **Protocol 层**（`references/`）：协议、命令定义、模板——纯声明式，不含脚本
3. **Scripts 层**（`scripts/`）：12 个自动化脚本——纯命令式，不依赖 Skill 上下文，覆盖初始化/启动/状态/索引/检测/注入/诊断/解析/校验全链路

## 层间依赖规则

- Core → Protocol：Core 引用 Protocol 文件路径，按需读取
- Core → Scripts：Core 指引 Agent 调用脚本，不直接执行
- Protocol → Scripts：Protocol 文件可声明"应调用某脚本"（如 `specanchor_check` 命令定义引用 `specanchor-check.sh`），但 Protocol 本身不执行脚本
- Scripts → 无外部依赖：脚本不依赖 Skill 上下文或 Agent，仅读取 anchor.yaml 和文件系统
- Scripts → 层内依赖允许：组合脚本（如 Layer 2）可调用同层其他脚本，共享库 `scripts/lib/` 可被 source

## .specanchor/ 内部结构

- `global/`：Global Spec 存放（合计 ≤ 200 行）
- `modules/`：Module Spec 集中存放，文件名由路径转换（`/` → `-`）
- `tasks/<module>/`：Task Spec 按模块分组
- `tasks/_cross-module/`：跨模块 Task Spec
- `archive/`：已完成的 Task Spec 归档
- `spec-index.md`：主索引（v3 block YAML frontmatter，覆盖 Global/Module/Task 统计、健康度与路径映射，必须与 `global/`、`modules/`、`tasks/` 目录保持同步）
- `module-index.md`：已废弃的模块索引（仅作为迁移期兼容 fallback，可由 `specanchor-index.sh --legacy-module-index` 生成）
- `project-codemap.md`：项目架构可视化

## 路径约定

- Skill 内路径（`references/`、`scripts/`）相对于 SKILL.md 所在目录
- 项目路径（`.specanchor/`、`anchor.yaml`）相对于用户工作区根目录

## 扩展性约定

- 新命令：在 `references/commands/` 添加 `<cmd>.md`，在 quickref 注册
- 新 Schema：在 `references/schemas/<name>/` 添加 `schema.yaml` + `template.md`
- 若要维护独立扩展，默认放在本仓以外或 maintainer-local 区域，不把不存在的扩展路径写进公开样本

## 向后兼容

- `.specanchor/config.yaml` → `anchor.yaml` 迁移期间保持双路径查找
- `.specanchor/module-index.md` → `.specanchor/spec-index.md` 迁移期间，运行时消费者必须优先读 `spec-index.md`，仅在缺失时 fallback 到 legacy module index
- DEPRECATED 文件保留但标注废弃，不删除
