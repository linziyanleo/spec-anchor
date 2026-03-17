# specanchor_global

从项目代码扫描推断 Global Spec，创建或全量更新。Global Spec 是项目的"宪法"，所有 AI 生成的代码都必须遵循。

**用户可能这样说**: "帮我生成编码规范" / "从代码推断架构约定" / "更新全局的设计系统规则" / "生成 API 约定规范"

## 参数

- `type`（必须，从用户意图推断）: `coding-standards` / `architecture` / `design-system` / `api-conventions` / 自定义名称
- `scan`（可选）: 指定扫描路径，不指定则自动推断

## 执行

1. 确定扫描范围（按 type 选择合适的文件）：
   - `coding-standards`: `package.json` / `tsconfig.json` / `.eslintrc` / `.prettierrc`，采样 5-10 个代码文件
   - `architecture`: 顶层目录结构、路由配置、中间件层
   - `design-system`: CSS/Tailwind 配置、组件库、主题文件
   - `api-conventions`: API 路由定义、请求/响应类型、中间件
2. 从扫描结果推断规范内容。使用 `references/global-spec-template.md` 中对应类型的模板
3. 已有文件 → 全量重生成，version minor +1，updated = 今天
4. 新建 → version = 1.0.0
5. 写入 `.specanchor/global/<type>.spec.md`
6. 检查全部 Global Spec 合计是否 ≤ 200 行。超出则警告并建议精简——这是 token 预算硬约束
