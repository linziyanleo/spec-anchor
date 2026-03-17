# specanchor_index

更新 Module Spec 索引文件 `module-index.md`。索引是 Agent 快速定位模块 Spec 的关键。

**用户可能这样说**: "更新一下模块索引" / "刷新 module-index" / "重新生成模块规范索引"

## 执行

1. 扫描 `.specanchor/modules/` 下所有 `.spec.md` 文件
2. 读取每个文件的 frontmatter
3. 扫描 `config.yaml` 中 `scan_paths` 下的模块目录
4. 生成/更新 `.specanchor/module-index.md`，格式：

```markdown
# Module Spec Index
<!-- 自动生成，请勿手动编辑 -->

| 模块名 | 模块路径 | Spec 文件 | 状态 | 版本 | 最后同步 | Owner |
|--------|---------|----------|------|------|---------|-------|
| 用户认证 | src/modules/auth | src-modules-auth.spec.md | active | 2.1.0 | 2026-03-10 | @zhangsan |

## 无 Spec 覆盖的模块

| 模块路径 | 近 30 天提交数 | 建议 |
|---------|-------------|------|
| src/modules/payment | 12 | 建议为此模块创建规范 |
```
