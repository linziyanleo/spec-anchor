<div align="center">
  <img src="assets/SpecAnchor_logo.png" alt="SpecAnchor Logo" width="140" />
</div>

<h1 align="center">SpecAnchor</h1>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ZH.md">中文</a> ·
  <a href="WHY_ZH.md">为什么需要</a> ·
  <a href="docs/INSTALL.md">安装</a> ·
  <a href="CONTRIBUTING.md">贡献</a>
</p>

---

SpecAnchor 是面向 AI 编码的 spec governance / anti-decay layer。它会在 AI 写代码前加载 Global / Module / Task 三层规范，但不绑定具体的 Spec 写作流程。

> 提示
> SpecAnchor 会写入 `.specanchor/`，可能创建或更新 `anchor.yaml`，也可能修改 Markdown frontmatter。首次使用建议在干净分支上试。

## 快速开始

1. 把 Skill 安装到目标项目。

```bash
SKILL_DIR=/absolute/path/to/spec-anchor
PROJECT_DIR=/absolute/path/to/your-project

rsync -a --exclude-from="$SKILL_DIR/.skillexclude" \
  "$SKILL_DIR/" "$PROJECT_DIR/.cursor/skills/specanchor/"
```

1. 在目标项目根目录初始化并启动检查。

```bash
cd "$PROJECT_DIR"

SPECANCHOR_SKILL_DIR="$PWD/.cursor/skills/specanchor" \
  bash "$PWD/.cursor/skills/specanchor/scripts/specanchor-init.sh" \
  --project="$(basename "$PWD")" --mode=full

SPECANCHOR_SKILL_DIR="$PWD/.cursor/skills/specanchor" \
  bash "$PWD/.cursor/skills/specanchor/scripts/specanchor-boot.sh" \
  --format=summary
```

成功标准：命令退出码为 `0`，且输出里没有缺失 source 的 `✗` 行。

更完整的安装方式见 [docs/INSTALL.md](docs/INSTALL.md)；贡献前的检查命令见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 定位

- SpecAnchor 负责治理和防腐，不负责规定唯一的写作流程。
- SDD-RIPER-ONE、OpenSpec 等更偏向写作流程和格式。
- SpecAnchor 支持 `full` 模式和 `parasitic` 模式。

## 许可

代码采用 [MIT](LICENSE)；仓库图片来源与授权说明见 [assets/README.md](assets/README.md)。
