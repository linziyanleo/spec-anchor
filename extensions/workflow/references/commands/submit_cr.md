# workflow_submit_cr - 提交代码评审

## 触发词

"提交代码评审" / "评审代码" / "CR" / "代码评审" / "创建 CR"

## 执行流程

1. **检查 CR 脚本**：检查项目根目录是否存在 CR 脚本（路径从 `project-setup.spec.md` 的「CR 脚本路径」字段读取，默认 `codereview.sh`）。不存在则提示用户创建或配置
2. **获取目标分支**：
   - 优先从 `project-setup.spec.md` 的「CR 目标分支」字段读取
   - 其次从 `package.json` 的 `scripts.cr` 中提取
   - 再次从当前分支名推断：取最后一个下划线前的部分（如 `feat/v1.0.0_hungrated` → `feat/v1.0.0`）
   - 分支名不含下划线时使用 `develop`
3. **获取评审人**：从 `project-setup.spec.md` 的「默认代码评审人」字段读取。未配置则提示用户提供
4. **检查代码状态**：`git status`，有未提交变更则先执行 `workflow_commit_push`
5. **执行 CR 命令**：运行 CR 脚本（如 `sh codereview.sh <目标分支> <评审人>`）
6. **提取 CR 链接**：从命令输出中提取 merge request / code review 链接
7. **运行质量检查**：执行 `specanchor_check` 进行 Spec-代码对齐检测，将结果提示给用户
8. **展示结果**：显示 CR 链接，询问是否打开

## 平台适配

CR 的具体执行方式由用户项目配置驱动。`project-setup.spec.md` 中需包含：

```markdown
## 代码评审配置
- CR 脚本路径: codereview.sh
- CR 目标分支: feat/2.2.0
- 默认代码评审人: 张三
```

`codereview.sh` 在 `specanchor_global`（project-setup 类型）执行时已自动生成到用户项目根目录。如果执行 CR 时发现脚本不存在，提示用户先执行"初始化项目信息"生成配置和脚本。

## 参数

- `--reviewer`：指定评审人（覆盖配置值）
- `--target-branch`：指定目标分支（覆盖推断值）

## 注意事项

- 代码评审前必须确保所有变更已提交
- 遇到合并冲突时告知用户手动解决
- 如果 CR 脚本执行失败，完整展示错误信息并提供解决方案
