# specanchor_status

显示当前 Spec 加载状态和覆盖率概览。

**用户可能这样说**: "看看当前规范状态" / "模块规范覆盖率怎么样" / "哪些规范已经加载了" / "规范概览"

## 执行

**首选方式**：运行 `scripts/specanchor-status.sh` 脚本获取状态报告：

```bash
bash "<skill_install_dir>/scripts/specanchor-status.sh"

# 可选参数：
#   --config=<path>       指定配置文件（默认自动查找 anchor.yaml）
#   --format=summary|json 输出格式（默认 summary）
```

脚本自动完成以下步骤：

1. 读取配置文件
2. 扫描 `.specanchor/global/`，统计 Global Spec 数量和总行数
3. 扫描 `.specanchor/modules/`，统计 Module Spec 覆盖率和健康度
4. 统计活跃/归档 Task Spec 数量
5. 检测 module-index.md 格式（v2/legacy/missing）
6. 输出简洁摘要

Agent 可在脚本输出基础上补充"已加载的 Spec"信息（session-specific，脚本无法感知）。

### 输出格式

full 模式：

```
SpecAnchor Status [full]
  Config: anchor.yaml
  Loaded: coding-standards (v1.2), architecture (v1.0), auth/MODULE (v2.1)
  Coverage: 3/4 modules (75%)
  Tasks: 2 active, 15 archived
  Sources:
    specs/ [spec-kit]: 12 files, stale_check: ✅, frontmatter_inject: ❌
```

parasitic 模式：

```
SpecAnchor Status [parasitic]
  Config: anchor.yaml
  Sources:
    specs/ [spec-kit]: 12 files, stale_check: ✅, frontmatter_inject: ❌
    .qoder/specs/ [qoder]: 5 files, stale_check: ✅, frontmatter_inject: ✅
```
