# spec-anchor Project Codemap

## 项目定位

SpecAnchor 是一个 AI Agent Skill，管理三级 Spec 体系（Global → Module → Task），并在 AI 生成代码前注入团队规范上下文。当前仓库既是 Skill 本体，也是 self-dogfood 的 full-mode 示例仓库。

## 架构层次

```text
spec-anchor/
├── SKILL.md                          # 入口/路由/门禁（精简 entrypoint）
├── anchor.yaml                       # 仓库自身的 SpecAnchor 配置
├── references/                       # 协议层：命令定义、模板、Schema、集成文档
│   ├── commands-quickref.md
│   ├── script-contract.md
│   ├── assembly-trace.md
│   ├── workflow-gates.md
│   ├── integrations/
│   ├── commands/
│   └── schemas/
├── scripts/                          # 自动化层：10 个脚本 + lib/common.sh
│   ├── specanchor-init.sh
│   ├── specanchor-boot.sh
│   ├── specanchor-status.sh
│   ├── specanchor-index.sh
│   ├── specanchor-check.sh
│   ├── frontmatter-inject.sh
│   ├── frontmatter-inject-and-check.sh
│   ├── specanchor-doctor.sh
│   ├── specanchor-resolve.sh
│   ├── specanchor-validate.sh
│   └── lib/common.sh
├── .specanchor/                      # curated public Global/Module sample + local task notes
├── tests/                            # public shell tests + fixtures
├── .github/workflows/ci.yml          # Ubuntu/macOS shell CI
└── docs/release/v0.4.0-alpha.md      # alpha release prep note
```

## 核心数据流

```text
anchor.yaml
  -> specanchor-boot.sh / specanchor-doctor.sh
  -> Global Specs
  -> module-index.md + specanchor-resolve.sh
  -> on-demand Module Specs
  -> task execution / specanchor-check.sh / specanchor-validate.sh
```

## 关键文件索引

| 文件 | 职责 |
|------|------|
| `SKILL.md` | Skill 主入口，负责 boot、路由、`⚡/📋` 选择与门禁摘要 |
| `references/specanchor-protocol.md` | 核心协议总览 |
| `references/script-contract.md` | 脚本清单、调用契约、输出边界 |
| `scripts/specanchor-doctor.sh` | 只读健康检查 |
| `scripts/specanchor-resolve.sh` | 最小 Anchor Resolution |
| `scripts/specanchor-validate.sh` | 基础 schema/frontmatter 校验 |
| `tests/run.sh` | 公共 shell 回归入口 |
