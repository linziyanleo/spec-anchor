# specanchor_index

更新 SpecAnchor 结构化索引文件 `spec-index.md`。索引覆盖 Global / Module / Task 三层，是 Agent 快速定位规范与健康度的主要入口。

**用户可能这样说**: "更新一下索引" / "刷新 spec-index" / "重新生成规范索引"

## 执行

**首选方式**：运行 `scripts/specanchor-index.sh`：

```bash
bash "<skill_install_dir>/scripts/specanchor-index.sh"

# 可选参数：
#   --config=<path>          指定配置文件（默认自动查找 anchor.yaml）
#   --output=<path>          指定输出路径（默认 .specanchor/spec-index.md）
#   --legacy-module-index    迁移期额外写出 .specanchor/module-index.md v2 子集
```

脚本自动执行以下步骤：

1. 扫描 `.specanchor/global/`、`.specanchor/modules/`、`.specanchor/tasks/`、`.specanchor/archive/`
2. 读取各 Spec frontmatter，并从 SDD 正文 marker 派生 task `sdd_phase`
3. 计算 Global 与 Module 健康度
4. 生成/覆盖 `.specanchor/spec-index.md`（v3 格式）
5. 如传入 `--legacy-module-index`，同步写出迁移期兼容文件

## 输出格式（v3）

v3 frontmatter 只使用 block YAML，避免 Bash 3.2 的行扫描解析器误读 flow map。

```yaml
---
specanchor:
  type: spec-index
  version: 3
  generated_at: "2026-04-27T16:00:00"
  spec_counts:
    globals: 3
    modules: 2
    tasks_active: 1
    tasks_archived: 0
  health_summary:
    globals:
      fresh: 3
      drifted: 0
      stale: 0
      outdated: 0
    modules:
      fresh: 2
      drifted: 0
      stale: 0
      outdated: 0
    tasks:
      active: 1
      archived: 0
specs:
  globals:
    - type: "architecture"
      file: ".specanchor/global/architecture.spec.md"
      version: "2.2.0"
      last_synced: "2026-04-27"
      owner: "maintainers"
      health: "FRESH"
  modules:
    - path: "scripts/"
      spec: "scripts.spec.md"
      summary: "Shell automation layer"
      source: "native"
      status: "active"
      version: "2.2.0"
      last_synced: "2026-04-27"
      owner: "maintainers"
      health: "FRESH"
  tasks:
    - spec: ".specanchor/tasks/_cross-module/example.spec.md"
      task_name: "Example"
      status: "in_progress"
      sdd_phase: "EXECUTE"
      created: "2026-04-27"
      last_change: "Current execution"
uncovered: []
---
```

## 健康度

Module health 沿用代码提交漂移算法：`last_synced` 后无提交为 `FRESH`，有提交且未超阈值为 `DRIFTED`，超过 `stale_days` / `outdated_days` 后分别为 `STALE` / `OUTDATED`。

Global health 只按 `last_synced` 年龄计算，因为 Global Spec 没有单一 `module_path`。Global 不产生 `DRIFTED`，该字段固定保留为 0 以维持结构对称。

Task 不计算健康度，只按 `.specanchor/tasks/` 与 `.specanchor/archive/` 归类 active / archived。

## boot 集成

`specanchor-boot.sh` 优先读取 `.specanchor/spec-index.md`，并输出：

- `Spec Index: v3 (structured)`
- `Available Commands:`
- `Available Modules:`

若迁移期只存在 `.specanchor/module-index.md`，boot 会以 legacy fallback 读取模块列表，并提示运行 `specanchor_index` 升级。
