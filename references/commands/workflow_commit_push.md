# workflow_commit_push - 提交并推送代码

## 命令描述

自动分析代码变更，生成符合规范的 commit message，并执行提交和推送操作。

## 触发词

- "提交"
- "提交代码"
- "push"
- "git push"
- "推送代码"
- "commit"
- "git commit"

## 执行流程

1. 执行 `git status` 查看变更文件
2. 分析变更文件类型和内容
3. 根据变更类型生成 commit message（feat/fix/docs/style/refactor/perf/test/chore）
4. 执行 `git add . && git commit -m "<message>" && git push`

## Commit Message 生成规则

根据代码变更类型选择合适的前缀：

- `feat:` - 新增功能
- `fix:` - 修复 bug
- `docs:` - 文档更新
- `style:` - 代码格式调整（不影响功能）
- `refactor:` - 代码重构
- `perf:` - 性能优化
- `test:` - 测试相关
- `chore:` - 构建/工具配置等

## 生成流程

```
1. 执行 git status 查看变更文件
2. 分析变更文件类型和内容
3. 确定变更类型（feat/fix/docs等）
4. 提取核心变更内容（10-50字）
5. 生成格式：<type>: <简洁描述>
```

## 执行示例

### 示例 1：修复 Bug

```
用户："提交代码"

你的处理流程：
1. 执行 git status 查看变更
2. 发现修改了 src/components/LoginButton.tsx
3. 分析变更：修复了按钮点击事件
4. 生成 message: "fix: 修复登录按钮点击无响应问题"
5. 执行: git add . && git commit -m "fix: 修复登录按钮点击无响应问题" && git push
```

### 示例 2：新增功能

```
用户："push 一下"

你的处理流程：
1. 执行 git status 查看变更
2. 发现新增了 src/pages/UserProfile 目录
3. 分析变更：新增用户资料页面
4. 生成 message: "feat: 新增用户资料页面"
5. 执行: git add . && git commit -m "feat: 新增用户资料页面" && git push
```

### 示例 3：文档更新

```
用户："提交"

你的处理流程：
1. 执行 git status 查看变更
2. 发现修改了 README.md 和 docs/ 目录下的文件
3. 分析变更：更新了项目文档
4. 生成 message: "docs: 更新项目文档和使用说明"
5. 执行: git add . && git commit -m "docs: 更新项目文档和使用说明" && git push
```

### 示例 4：样式调整

```
用户："git commit"

你的处理流程：
1. 执行 git status 查看变更
2. 发现修改了多个 .css 和 .module.css 文件
3. 分析变更：调整了组件样式
4. 生成 message: "style: 调整组件样式和布局"
5. 执行: git add . && git commit -m "style: 调整组件样式和布局" && git push
```

## 错误处理

如果执行过程中出现错误，必须：

1. **明确告知用户错误信息**：完整显示 Git 返回的错误信息
2. **解释错误原因**：用通俗语言说明错误含义
3. **提供解决方案**：给出具体的解决步骤

### 常见错误处理示例

```
错误 1：nothing to commit, working tree clean
→ 告知用户："当前没有需要提交的代码变更，工作区是干净的。"

错误 2：fatal: not a git repository
→ 告知用户："当前目录不是 Git 仓库，请先执行 git init 初始化仓库。"

错误 3：error: failed to push some refs
→ 告知用户："推送失败，可能是远程仓库有新的提交。建议先执行 git pull 拉取最新代码。"

错误 4：Author identity unknown
→ 告知用户："Git 用户信息未配置，请先执行：
   git config user.name '你的名字'
   git config user.email '你的邮箱'"

错误 5：Updates were rejected because the remote contains work
→ 告知用户："推送被拒绝，远程仓库包含本地没有的提交。请先执行：
   git pull --rebase
   然后重新推送"

错误 6：Permission denied (publickey)
→ 告知用户："SSH 密钥认证失败，请检查：
   1. SSH 密钥是否正确配置
   2. 是否有仓库推送权限
   3. 网络连接是否正常"
```

## 变更类型识别规则

### feat（新增功能）

- 新增文件夹/目录结构
- 新增 .tsx/.jsx/.vue 组件文件
- 新增 API 接口文件
- 新增路由配置
- 新增功能模块

### fix（修复 bug）

- 修改现有组件的逻辑错误
- 修复样式问题
- 修复配置错误
- 修复依赖问题

### docs（文档更新）

- 修改 README.md
- 修改 docs/ 目录下文件
- 修改注释文档
- 修改 CHANGELOG.md

### style（样式调整）

- 修改 .css/.scss/.less 文件
- 修改 .module.css 文件
- 调整代码格式（不影响功能）
- 修改 ESLint/Prettier 配置

### refactor（代码重构）

- 重构现有代码结构
- 提取公共组件/函数
- 优化代码组织
- 重命名文件/变量

### perf（性能优化）

- 优化算法实现
- 减少不必要的渲染
- 优化资源加载
- 缓存优化

### test（测试相关）

- 新增/修改测试文件
- 修改测试配置
- 更新测试用例

### chore（构建/工具配置）

- 修改 package.json
- 修改构建配置（webpack、vite等）
- 修改 CI/CD 配置
- 更新依赖版本

## 复杂变更处理

当变更涉及多种类型时，按以下优先级选择：

1. **feat** > fix > refactor > perf > style > docs > test > chore
2. 如果同时有新增功能和修复 bug，优先使用 feat
3. 如果变更过于复杂，可以询问用户确认 commit message

### 复杂变更示例

```
变更文件：
- 新增 src/components/UserProfile/
- 修改 src/pages/User/index.tsx
- 修改 src/styles/user.css
- 更新 README.md

分析结果：主要是新增用户资料功能
生成 message: "feat: 新增用户资料页面和相关样式"
```

## 参数

- `--message`: 可选，手动指定 commit message（覆盖自动生成）

### 使用参数示例

```
用户："提交代码 --message 'fix: 紧急修复登录问题'"

你的处理流程：
1. 检测到用户指定了 commit message
2. 跳过自动生成步骤
3. 执行: git add . && git commit -m "fix: 紧急修复登录问题" && git push
```

## 注意事项

- 必须先分析变更内容再生成 commit message
- Commit message 要简洁明了，符合团队规范
- 遇到错误必须完整展示错误信息并提供解决方案
- 如果变更内容复杂，可以询问用户确认 commit message
- 自动生成的 commit message 应该在 50 字符以内
- 如果无法确定变更类型，默认使用 `chore:`
