# workflow_commit_push - 提交并推送代码

## 触发词

"提交" / "提交代码" / "push" / "commit" / "推送代码"

## 执行流程

1. `git status` 查看变更文件
2. 分析变更文件类型和内容，确定变更类型
3. 生成 commit message：`<type>: <简洁描述>`（50 字符内）
4. `git add . && git commit -m "<message>" && git push`

## Commit Message 类型

| 类型 | 场景 |
|------|------|
| `feat` | 新增文件/组件/模块/路由/API |
| `fix` | 修复逻辑错误/样式问题/配置错误 |
| `docs` | 修改 README / docs/ / CHANGELOG |
| `style` | 修改 CSS/样式文件、代码格式调整 |
| `refactor` | 重构代码结构、提取公共组件 |
| `perf` | 性能优化 |
| `test` | 测试文件变更 |
| `chore` | 构建配置、依赖更新 |

混合变更时按优先级选择：feat > fix > refactor > perf > style > docs > test > chore。变更过于复杂时询问用户确认。

## 参数

- `--message`：可选，手动指定 commit message（跳过自动生成）

## 注意事项

- 遇到错误时完整展示 Git 返回的错误信息，解释原因并提供解决方案
- 无变更时告知用户工作区干净
- 推送失败时建议先 `git pull`
