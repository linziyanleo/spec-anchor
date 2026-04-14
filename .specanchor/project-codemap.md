# spec-anchor Project Codemap

## 项目定位

SpecAnchor 是一个 AI Agent Skill，管理三级 Spec 体系（Global → Module → Task），在 AI 生成代码前注入团队规范上下文。

## 架构层次

```
spec-anchor/
├── SKILL.md                          # 核心入口 — Skill 主定义文件
├── anchor.yaml                       # SA 自身配置
├── references/                       # 协议层 — 命令定义、模板、Schema
│   ├── specanchor-protocol.md        #   核心协议（启动检查、加载规则、集成协议）
│   ├── external-sources-protocol.md  #   外部来源治理协议
│   ├── commands-quickref.md          #   意图映射快速参考
│   ├── commands/                     #   各命令的详细定义
│   ├── global-spec-template.md       #   Global Spec 模板
│   ├── module-spec-template.md       #   Module Spec 模板
│   ├── task-spec-template.md         #   (DEPRECATED) Task Spec 模板
│   └── schemas/                      #   Schema 系统（6 个内置 Schema）
│       ├── sdd-riper-one/            #     默认 Schema
│       ├── bug-fix/
│       ├── refactor/
│       ├── research/
│       ├── openspec-compat/
│       └── simple/
├── scripts/                          # 自动化层 — Shell 脚本
│   ├── specanchor-check.sh           #   Spec-Commit 对齐检测（548 行）
│   ├── frontmatter-inject.sh         #   Frontmatter 自动注入 Layer 1（581 行）
│   └── frontmatter-inject-and-check.sh  # 注入+检测 Layer 2（207 行）
├── extensions/                       # 独立 skill 存放区
│   └── workflow/                     #   独立工作流 skill（提交/评审/启停）
│       ├── SKILL.md
│       ├── references/commands/
│       └── scripts/
└── mydocs/                           # 开发文档（历史 Spec、规划）
    ├── specs/                        #   历史开发 Task Spec
    ├── PLAN.md
    └── idea.md
```

## 核心数据流

```
anchor.yaml → SKILL.md 启动检查 → 加载 Global Spec → 按需加载 Module Spec
                                                          ↓
                                               Schema 推荐 → Task Spec 创建
                                                          ↓
                                               RIPER 流程推进 → specanchor-check.sh 验证
```

## 关键文件索引

| 文件 | 职责 | 行数 |
|------|------|------|
| `SKILL.md` | Skill 主入口，启动检查 + 命令路由 + 工作流选择 | ~200 |
| `references/specanchor-protocol.md` | 核心协议（启动、加载、Schema、门禁、管理） | ~350 |
| `scripts/specanchor-check.sh` | 对齐检测（task/module/global/coverage 四种模式） | ~548 |
| `scripts/frontmatter-inject.sh` | Frontmatter 注入 Layer 1 | ~581 |
| `scripts/frontmatter-inject-and-check.sh` | 注入+检测 Layer 2 组合器 | ~207 |
