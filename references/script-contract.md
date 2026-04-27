# Script Contract

SpecAnchor 的脚本位于 Skill 根目录的 `scripts/` 下，调用模板统一为：

```bash
SPECANCHOR_SKILL_DIR="$SA_SKILL_DIR" bash "$SA_SKILL_DIR/scripts/<script-name>.sh" [args]
```

这些脚本是实现辅助工具，不是用户主交互语言。用户面仍以自然语言和可选 `SA:` shorthand 为主。

## Script List

| Script | Purpose | Mutates Files |
| --- | --- | --- |
| `specanchor-init.sh` | 初始化 `anchor.yaml` 与 `.specanchor/` 基线 | yes |
| `specanchor-boot.sh` | 启动检查、输出配置/Spec 摘要 | no |
| `specanchor-status.sh` | 状态、覆盖率、健康度概览 | no |
| `specanchor-index.sh` | 生成 `spec-index.md` | yes |
| `specanchor-check.sh` | Task/Module/Global/Coverage 对齐检测 | no |
| `frontmatter-inject.sh` | 注入或更新 `specanchor:` frontmatter | yes |
| `frontmatter-inject-and-check.sh` | 注入 + 对齐检测组合器 | yes |
| `specanchor-doctor.sh` | 只读健康检查 | no |
| `specanchor-resolve.sh` | 解析本轮应加载的锚点 | no |
| `specanchor-assemble.sh` | 把 resolver 结果转成 agent read plan | no |
| `specanchor-validate.sh` | 基础 schema/frontmatter + JSON contract 校验 | no |
| `specanchor-hygiene.sh` | 只读 spec hygiene / dead-link / duplicate-module 检查 | no |

## Behavior Notes

- `specanchor-init.sh` 在 `full` 模式下会创建 `.specanchor/` 基线，并种下 3 份 starter Global Specs；在 `parasitic` 模式下只写配置，不接管外部 spec 目录。
- `specanchor-resolve.sh` 现在输出 `specanchor.resolve.v2`，包含 `budget`、`missing`、`warnings` 和 `trace`；它保持 deterministic-first，不是 semantic RAG。
- `specanchor-assemble.sh` 消费 resolver 结果，给 agent 一个 bounded read plan 和 Assembly Trace。
- `specanchor-validate.sh` 支持 `--format=text|summary|json`，其中 `summary` 是 `text` 的兼容别名；默认还会校验 resolve / assembly JSON shape。
- `specanchor-hygiene.sh` 默认只读；只有 `--fix-generated` 才允许修复生成物。

## Output Rules

- `boot/status/doctor/resolve/assemble/validate/hygiene` 支持人类可读文本；其中 `boot/status/doctor/resolve/assemble/validate/hygiene` 的 `--format=json` 必须输出合法 JSON。
- `doctor` 的退出码：`0`=ok/warning(非 strict), `1`=warning(strict), `2`=blocking error, `64`=invalid args。
- `resolve` 和 `assemble` 支持 `--format=markdown`，用于直接向 agent 展示 read plan。
- `resolve`、`doctor`、`validate` 遇到 blocking 配置错误时返回非零并给出稳定错误语义。

## Portability

- 默认要求兼容 Linux 与 macOS。
- 避免 GNU-only 依赖，如 `sed -i`、`readlink -f`、GNU `date` 单一路径。
- 若需要日期处理，必须同时兼容 `date -j` 与 `date -d`。
