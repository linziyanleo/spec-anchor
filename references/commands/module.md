# specanchor_module

创建或全量更新 Module Spec。结合代码扫描和用户口述的业务规则，生成完整的模块契约文档。

**用户可能这样说**: "帮我创建 auth 模块的规范" / "更新用户认证模块的 Spec" / "给 src/modules/auth 写模块规范" / "这个模块的 Spec 需要同步"

## 参数

- `path`（必须，从用户意图推断模块路径）: 模块路径（目录或单文件）
- `scan`（可选）: 额外扫描路径（如依赖模块）

## 执行

1. 检查模块路径存在。不存在则报错
2. 生成 Module ID：路径中 `/` 替换为 `-`（如 `src/modules/auth` → `src-modules-auth`）
3. 扫描代码：
   - path 为目录 → 扫描目录下所有代码文件
   - path 为单文件 → 扫描该文件本身
4. 确定 Spec 路径：`.specanchor/modules/<module-id>.spec.md`
5. **更新模式**（Spec 已存在）：
   - 读取 frontmatter，保留 `owner` / `reviewers`
   - 使用 `references/module-spec-template.md` 全量重生成正文（§1-§7 全部章节）
   - version minor +1，updated = 当前日期，last_synced = 当前日期
6. **创建模式**（Spec 不存在）：
   - 使用 `references/module-spec-template.md` 从代码推断所有章节
   - version = 1.0.0，status = draft，module_path = 用户指定路径
7. 写入文件
8. 更新 `.specanchor/spec-index.md`
9. 建议用户 `git diff` 确认变更
