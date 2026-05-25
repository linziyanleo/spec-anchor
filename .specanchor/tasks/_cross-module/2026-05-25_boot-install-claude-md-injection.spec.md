---
specanchor:
  level: task
  task_name: "Boot-install: 把 SpecAnchor 触发块幂等注入 CLAUDE.md/AGENTS.md/GEMINI.md/cursor 规则"
  author: "@方壶"
  created: "2026-05-25"
  status: "done"
  last_change: "implementation + 4-scenario e2e smoke passed"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "simple"
  branch: "feat/context-system-v0.7"
---

# Task: Boot-install — 把 SpecAnchor 触发块幂等注入 Agent 指令文件

## 目标

让 `specanchor_init` 在 boot activation 步骤能够（询问后）自动把 SpecAnchor 的触发块写入项目根 CLAUDE.md/AGENTS.md/GEMINI.md/`.cursor/rules/specanchor.mdc`，使后续 Claude Code / Codex / Gemini / Cursor session 在不依赖 SessionStart hook 的情况下也能自动激活 spec-anchor skill。

## 范围

- **In-Scope**:
  - 新增 `scripts/specanchor-boot-install.sh`：幂等注入/升级/移除标记块
  - `specanchor-init.sh` 增加 `--install-boot=<targets>` 钩子
  - `references/agents/{claude-code,codex,gemini,cursor}.md` 的 Boot Activation 模板统一升级为「中强约束块」（含 Skill 调用 + boot 命令 + 关键词触发）
  - `references/commands/init.md` 步骤 13 由文本指引升级为脚本调用
  - 同步 `scripts.spec.md` § 3 公开接口表
- **Out-of-Scope**:
  - 不强制写入：用户必须明确 `--install-boot` 或在交互中选择 Y
  - 不改 `anchor.yaml` schema
  - 不打包成 plugin（plugin 化作为长期路径，本任务不做）

## 改动计划

| 文件 | 变更说明 |
|------|---------|
| `scripts/specanchor-boot-install.sh` | 新增：参数 `--target=auto\|claude\|codex\|gemini\|cursor\|all`、`--dry-run`、`--remove`；标记块 `<!-- specanchor:boot:start --> ... <!-- specanchor:boot:end -->` 幂等替换；auto 模式检测 `.claude/` `.codex/` `GEMINI.md` `.cursor/` |
| `scripts/specanchor-init.sh` | main 末尾加 `--install-boot=<targets>` 参数转发 |
| `references/agents/claude-code.md` | Boot Activation 段：Option B（CLAUDE.md）模板换成中强约束块（含 Skill 调用 + boot 命令 + 关键词），加入 boot-install.sh 使用说明 |
| `references/agents/codex.md` | 同上，目标文件改为 AGENTS.md |
| `references/agents/gemini.md` | 同上，目标文件改为 GEMINI.md |
| `references/agents/cursor.md` | 同上，目标文件改为 `.cursor/rules/specanchor.mdc` |
| `references/commands/init.md` | 步骤 13：从「输出指引文本」升级为「检测 → 询问 → 调用 boot-install.sh」三步 |
| `.specanchor/modules/scripts.spec.md` | § 3 增加 `specanchor-boot-install.sh` 接口；§ 7 增条目；bump `last_synced` |
| `.specanchor/modules/references.spec.md` | § 3.4 / § 7 reflects boot-install 引用；bump `last_synced` |

## Checklist
- [x] 1. Task Spec 草稿
- [x] 2. boot-install.sh 实现 + 单元自测（dry-run / 首次 / 重复 / remove）
- [x] 3. init.sh 加 `--install-boot` 转发
- [x] 4. 四个 agents/*.md 模板统一升级
- [x] 5. init.md 步骤 13 升级
- [x] 6. Module Spec 同步更新
- [x] 7. 在 /tmp 临时项目跑端到端冒烟（4 scenario：新建 / 已有文件追加 / all / 不传 flag 向后兼容）
- [x] 8. `bash scripts/specanchor-validate.sh` ok（41 files）；`specanchor-doctor.sh` ok（0 issues）；module check DRIFTED 是 last_synced_sha 未提交导致，预期行为

## 完成确认
- [x] 代码符合 Global coding-standards（Bash 3.2+, set -euo pipefail, common.sh, --long-opt）
- [x] Module Spec 已同步（scripts/references 两份）
- [x] 幂等性手测通过（md5 字节级一致）
- [x] 用户已 review 标记块文案（中强方案）

## 备注
- 标记块文案以用户确认的 preview 为准（带"You MUST"和关键词触发提示，约 10 行）
- 不引入 `<EXTREMELY_IMPORTANT>` 是因为不想模仿 superpowers 的"嗓门"风格；用户选了中强方案
- boot-install.sh 与 frontmatter-inject.sh 同样属于"半破坏性写文件"脚本，必须默认 dry-run-first 习惯；本任务实现 `--dry-run` flag
