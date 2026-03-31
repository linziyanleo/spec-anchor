# specanchor_status

显示当前 Spec 加载状态和覆盖率概览。

**用户可能这样说**: "看看当前规范状态" / "模块规范覆盖率怎么样" / "哪些规范已经加载了" / "规范概览"

## 执行

1. 列出当前已加载的 Spec（Global + Module）
2. 扫描 `.specanchor/modules/`，统计 Module Spec 覆盖率
3. 统计活跃/归档 Task Spec 数量
4. 自动更新 `.specanchor/module-index.md`
5. 如 `anchor.yaml` 中存在 `sources`，统计各来源文件数和治理状态
6. 输出简洁摘要：

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
