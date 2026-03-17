# specanchor_global

从项目代码扫描推断 Global Spec，创建或全量更新。Global Spec 是项目的"宪法"，所有 AI 生成的代码都必须遵循。

**用户可能这样说**: "帮我生成编码规范" / "从代码推断架构约定" / "更新全局的设计系统规则" / "生成 API 约定规范"

## 参数

- `type`（必须，从用户意图推断）: `coding-standards` / `architecture` / `design-system` / `project-setup` / `api-conventions` / 自定义名称
- `scan`（可选）: 指定扫描路径，不指定则自动推断

## 执行

1. 确定扫描范围（按 type 选择合适的文件）：
   - `coding-standards`: `package.json` / `tsconfig.json` / `.eslintrc` / `.prettierrc`，采样 5-10 个代码文件
   - `architecture`: 顶层目录结构、路由配置、中间件层
   - `design-system`: CSS/Tailwind 配置、组件库、主题文件
   - `project-setup`: `package.json`（完整信息）、README、`.env.example`、构建配置、项目元数据识别
   - `api-conventions`: API 路由定义、请求/响应类型、中间件
2. 从扫描结果推断规范内容。使用 `references/global-spec-template.md` 中对应类型的模板
   - 对于 `project-setup` 类型，自动识别并整合项目元数据：
     - **项目名称**：从 `package.json` 的 `name` 字段获取
     - **项目启动命令**：从 `package.json` 的 `scripts` 中获取（优先级：start > dev > serve）
     - **项目本地运行地址**：根据项目类型推断（如 Vite 项目默认 http://localhost:5173）
     - **默认代码评审人**：从 `package.json` 的 `scripts.cr` 命令提取，或提示用户补充
     - **构建和部署配置**：从构建工具配置文件推断
3. 已有文件 → 全量重生成，version minor +1，updated = 今天
4. 新建 → version = 1.0.0
5. 写入 `.specanchor/global/<type>.spec.md`
6. 检查全部 Global Spec 合计是否 ≤ 200 行。超出则警告并建议精简——这是 token 预算硬约束

## 项目元数据自动识别（project-setup 类型专用）

当执行 `specanchor_global` 且 type 为 `project-setup` 时，会自动执行以下项目元数据识别：

### 自动识别规则

#### 项目名称

```javascript
// 从 package.json 获取
const projectName = packageJson.name
```

#### 项目启动命令

```javascript
// 从 package.json 的 scripts 中获取
// 优先级：start > dev > serve
const startCommand =
	packageJson.scripts.start || packageJson.scripts.dev || packageJson.scripts.serve
```

#### 项目本地运行地址

```javascript
// 根据项目类型推断
const frameworks = {
	vite: 'http://localhost:5173',
	'create-react-app': 'http://localhost:3000',
	next: 'http://localhost:3000',
	vue: 'http://localhost:8080',
	angular: 'http://localhost:4200',
}
// 如果无法推断，提示用户补充
```

#### 默认代码评审人

```javascript
// 从 package.json 的 scripts.cr 中提取
// 格式：sh codereview.sh <目标分支> <用户名>
const crScript = packageJson.scripts.cr
if (crScript) {
	const reviewer = crScript.split(' ').pop() // 提取最后一个参数
}
// 如果无法提取，提示用户补充
```

### 执行示例

```
用户："初始化项目信息" 或 "帮我生成项目配置规范"

执行流程：
1. 识别为 project-setup 类型的 global spec 生成
2. 扫描 package.json 和相关配置文件
3. 自动识别项目元数据：
   - 项目名称：aidata-voice-collection
   - 启动命令：npm run dev
   - 运行地址：http://localhost:5173（Vite 项目）
   - 评审人：从 scripts.cr 提取或提示用户
4. 生成 .specanchor/global/project-setup.spec.md
5. 告知用户："项目配置规范已生成完成！"
```

### 缺失信息处理

如果某些信息无法自动识别：

```
已自动识别以下信息：
- 项目名称：aidata-voice-collection
- 项目启动命令：npm run dev

以下信息需要您补充：
1. 项目本地运行地址（推荐：http://localhost:5173）
2. 默认代码评审人

请提供缺失的信息，或直接回复"使用推荐值"。
```
