# specanchor_global

从项目代码扫描推断 Global Spec，创建或全量更新。Global Spec 是项目的"宪法"，所有 AI 生成的代码都必须遵循。

**用户可能这样说**: "帮我生成编码规范" / "从代码推断架构约定" / "更新全局的设计系统规则" / "生成 API 约定规范" / "初始化项目信息"

## 参数

- `type`（必须，从用户意图推断）: `coding-standards` / `architecture` / `design-system` / `project-setup` / `api-conventions` / 自定义名称
- `scan`（可选）: 指定扫描路径，不指定则自动推断

## 执行

1. 确定扫描范围（按 type 选择合适的文件）：
   - `coding-standards`: `package.json` / `tsconfig.json` / `.eslintrc` / `.prettierrc`，采样 5-10 个代码文件
   - `architecture`: 顶层目录结构、路由配置、中间件层
   - `design-system`: CSS/Tailwind 配置、组件库、主题文件
   - `project-setup`: `package.json`（完整信息）、README、`.env.example`、构建配置
   - `api-conventions`: API 路由定义、请求/响应类型、中间件
2. 从扫描结果推断规范内容。使用 `references/global-spec-template.md` 中对应类型的模板
3. 已有文件 → 全量重生成，version minor +1，updated = 今天
4. 新建 → version = 1.0.0
5. 写入 `.specanchor/global/<type>.spec.md`
6. 检查全部 Global Spec 合计是否 ≤ 200 行。超出则警告并建议精简——这是 token 预算硬约束

## project-setup 类型补充说明

当 type 为 `project-setup` 时，自动识别以下项目元数据：

- **项目名称**：从 `package.json` 的 `name` 字段
- **项目启动命令**：从 `package.json` 的 `scripts` 中选取（优先级：start > dev > serve）
- **项目本地运行地址**：根据项目框架推断（Vite → 5173，Next → 3000，CRA → 3000，Vue CLI → 8080）

无法自动识别的信息列出已识别项和待补充项，提示用户提供或使用推荐值。

`project-setup` 类型只生成 Spec 内容，不生成或修改工作流脚本。
