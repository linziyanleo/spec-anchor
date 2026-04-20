---
name: spec-anchor
description: 三级 Spec 体系（Global/Module/Task），在 AI 生成代码前自动加载编码规范与模块契约，保障团队一致性。只要项目中有 anchor.yaml 或 .specanchor/ 目录，或者正在生成 Spec 文档，就应该使用此 Skill。自然语言是主入口，`SA:` 仅是高级 shorthand；中英文关键词触发：规范、约定、对齐、覆盖率、spec。
---

# SpecAnchor

Spec 是锚，代码是船。SpecAnchor 管理 Global → Module → Task 三层 Spec，在 AI 动手前先加载团队规范。主 `SKILL.md` 只负责入口、路由、工作流选择和门禁；详细协议统一下沉到 `references/`。

## Script Invocation

Skill 脚本位于 Skill 根目录的 `scripts/` 下，运行时必须站在用户项目根目录。

```bash
# $SA_SKILL_DIR = SKILL.md 所在目录
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/<script-name>.sh" [args]
```

Shell 脚本是实现辅助工具，不是用户主交互语言。

## Boot Requirement

激活后先运行：

```bash
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/specanchor-boot.sh"
```

- `--format=summary`：人类可读摘要
- `--format=full`：额外附带 Global Spec 正文
- `--format=json`：机器可读 JSON

如果 `anchor.yaml` 缺失，或 `mode=full` 但 `.specanchor/` 缺失，先修配置再继续。

## Assembly Trace

每轮都要显式输出一次 Assembly Trace，说明本轮到底加载了哪些 Spec、是摘要还是全文：

```text
Assembly Trace:
  - Global: summary|full|none|skipped -> <files or reason>
  - Module: full|deferred|sources-only|none -> <files or reason>
```

完整规则见 `references/assembly-trace.md`。

## Loading Strategy

- `full`：始终加载 `anchor.yaml` + 全部 Global Spec；Module Spec 按需加载；`project-codemap.md` 按需加载。
- `parasitic`：只加载 `anchor.yaml` 与外部 `sources`；不创建 full-only Spec。
- 需要判断该读哪些模块时，优先看 `references/commands-quickref.md`、`.specanchor/module-index.md`，或运行 `bash scripts/specanchor-resolve.sh --files=... --intent=...`。

## Command Routing

自然语言是主用户接口。

- `specanchor_*` 是 Skill 内部命令 ID，用于把用户意图路由到对应协议文件。
- `SA:` 是可选的高级 shorthand，不是单独的 CLI 契约。
- `scripts/*.sh` 是实现层入口，不替代用户侧命令语言。

先读取 `references/commands-quickref.md`，再按匹配结果加载对应命令定义文件。

| Internal ID | Purpose | Definition |
| --- | --- | --- |
| `specanchor_init` | 初始化配置与目录 | `references/commands/init.md` |
| `specanchor_global` | 创建或更新 Global Spec | `references/commands/global.md` |
| `specanchor_module` | 创建或更新 Module Spec | `references/commands/module.md` |
| `specanchor_infer` | 从代码逆推 Module Spec 草稿 | `references/commands/infer.md` |
| `specanchor_task` | 创建 Task Spec | `references/commands/task.md` |
| `specanchor_load` | 手动加载 Spec | `references/commands/load.md` |
| `specanchor_status` | 查看状态与覆盖率 | `references/commands/status.md` |
| `specanchor_check` | 运行对齐检测 | `references/commands/check.md` |
| `specanchor_index` | 更新 module-index | `references/commands/index.md` |
| `specanchor_import` | 导入外部 SDD 配置 | `references/commands/import.md` |

## Workflow Selection

- `⚡ 轻量流程`：单文件或小范围修复，直接执行，无需 Task Spec。
- `📋 <schema>`：多文件、多模块、数据流或结构性变更；先创建 Task Spec，再推进实现。
- 严格门禁规则见 `references/workflow-gates.md`；不要在 gate 通过前进入 Execute。
- `docs/superpowers/` 存在时，Task Spec 创建门禁降级为建议；见 `references/integrations/superpowers.md`。

## Reference Index

- `references/commands-quickref.md`：自然语言意图 → 内部命令 ID
- `references/specanchor-protocol.md`：核心协议总览
- `references/script-contract.md`：脚本清单、调用契约、输出边界
- `references/assembly-trace.md`：Assembly Trace 格式与刷新时机
- `references/workflow-gates.md`：`⚡/📋` 选择与严格门禁规则
- `references/external-sources-protocol.md`：外部 sources 治理与 frontmatter 注入
- `references/integrations/sdd-riper-one.md`：默认写作协议的接入方式
- `references/integrations/superpowers.md`：与 superpowers 的协作和降级规则
