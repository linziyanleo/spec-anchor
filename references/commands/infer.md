# specanchor_infer

纯粹从代码逆向推断 Module Spec 草稿。与 `specanchor_module` 的区别：infer 不需要用户口述业务规则，完全基于代码分析；产出 status 始终为 draft。适合存量项目快速补齐 Spec。

**用户可能这样说**: "帮我从代码推断 auth 模块的规范" / "自动分析这个模块生成 Spec 草稿" / "先自动生成个草稿，我再确认"

## 参数

- `path`（必须，从用户意图推断）: 模块目录路径

## 执行

1. 扫描模块目录下所有代码文件
2. 生成 Module ID
3. 分析导出接口、内部状态、依赖关系、代码模式
4. 推断业务规则（基于代码逻辑和命名）
5. 使用 `references/module-spec-template.md` 生成 `.specanchor/modules/<module-id>.spec.md`，status = draft
6. 对不确定的推断章节，标注"由代码推断，待人工确认"
7. 更新 `.specanchor/spec-index.md`
