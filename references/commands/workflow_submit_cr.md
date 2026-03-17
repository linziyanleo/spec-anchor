# workflow_submit_cr - 提交代码评审

## 命令描述

自动提交代码评审，包括检查代码状态、提交未提交的变更、执行评审脚本、提取并展示 CR 链接。

## 触发词

- "提交代码评审"
- "评审代码"
- "提交 CR"
- "CR"
- "代码评审"
- "创建 CR"
- "发起代码评审"

## 执行流程

1. **检查 codereview.sh 文件是否存在**：
   - 检查项目根目录是否存在 codereview.sh 文件
   - 如果不存在，创建该文件（参照下方模板）
   - 给 codereview.sh 添加执行权限：`chmod +x codereview.sh`

2. **获取目标分支名**：
   - **优先级 1**：从 `package.json` 的 `scripts.cr` 中读取
     - 读取 `package.json` 文件
     - 解析 `scripts.cr` 字段（格式：`sh codereview.sh <目标分支> <用户名>`）
     - 提取第一个参数作为目标分支
     - 示例：`"cr": "sh codereview.sh feat/2.2.0 杭歌"` → 目标分支：`feat/2.2.0`
   - **优先级 2**：从当前分支名推断（当 package.json 中未配置时）
     - 使用 `git branch --show-current` 获取当前分支名
     - 提取规则：取当前分支最后一个下划线前面的部分
     - 示例：
       - `feat/v1.0.0_hungrated` → 目标分支：`feat/v1.0.0`
       - `fix/bf_hungrated` → 目标分支：`fix/bf`
       - `feat/2.2.0_test` → 目标分支：`feat/2.2.0`
   - **边界情况**：如果分支名不包含下划线，则使用 `develop` 作为目标分支
     - `feature-branch` → 目标分支：`develop`

3. **获取评审人**：
   - 从 `.specanchor/global/project-setup.spec.md` 文件中读取"默认代码评审人"字段
   - 如果文件不存在或字段为空，提示用户提供评审人信息

4. **检查代码状态**：使用 `git status` 检查是否有未提交的代码变更

5. **提交代码**（如有未提交变更）：
   - 分析变更内容生成 commit message
   - 执行 `git add . && git commit -m "<message>"`

6. **执行命令**：运行 `sh codereview.sh <目标分支> <评审人>`

7. **提取 CR 链接**：从命令行返回信息中提取代码评审链接

8. **运行 SA CHECK**：执行 SpecAnchor 代码质量检查
   - 调用 SpecAnchor 技能执行 `SA CHECK` 命令
   - 检查代码规范、架构合规性、测试覆盖率等
   - 将检查结果提示给用户，无需进一步操作

9. **告知用户**：将 CR 链接展示给用户，并询问是否打开链接

## codereview.sh 模板

如果项目中不存在 codereview.sh 文件，需要创建该文件，内容如下：

```bash
#!/bin/bash

# 显示使用说明
show_usage() {
    echo "使用方法: $0 <targetBranch> <reviewer>"
    echo "示例: $0 feat/0.4.0 雨临"
    echo ""
    echo "参数说明:"
    echo "  targetBranch  目标分支名"
    echo "  reviewer      评审人"
    exit 1
}

# 检查参数数量
if [ $# -ne 2 ]; then
    echo "错误: 需要提供 2 个参数"
    show_usage
fi

# 获取当前分支名，处理带空格或特殊字符的情况
currentBranch=$(git symbolic-ref --short HEAD 2>/dev/null)

# 从命令行参数获取目标分支名和评审人
targetBranch="$1"
reviewer="$2"

# 检查是否获取到有效分支名
if [[ -z "$currentBranch" ]]; then
  echo "当前不在 Git 仓库或无法获取分支名"
  exit 1
fi

# 在执行 push 之前先进行 git pull 和 merge 操作
echo "正在拉取最新代码并合并目标分支..."

# 执行 git pull
echo "执行 git pull..."
if ! git pull; then
    echo "错误: git pull 失败"
    exit 1
fi

# 执行 git merge origin/${targetBranch}
echo "执行 git merge origin/${targetBranch}..."
if ! git merge "origin/${targetBranch}"; then
    # 检查是否有冲突
    if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
        echo "错误: 合并时发生冲突，请手动解决冲突后重新运行脚本"
        echo "冲突文件:"
        git status --porcelain | grep "^UU\|^AA\|^DD"
        exit 1
    else
        echo "错误: git merge 失败"
        exit 1
    fi
fi

echo "代码拉取和合并完成，准备提交代码评审..."

# 构建完整命令（使用命令替换防止特殊字符问题）
command="git push origin HEAD:refs/for/${targetBranch}/${currentBranch} -o reviewer=${reviewer}"

# 执行命令并显示详细过程
echo "正在执行代码评审提交：$command"
eval "$command"
```

## CR 链接提取规则

从命令行输出中查找以下模式的链接：

- `https://code.alibaba-inc.com/*/merge_requests/*`
- `http://code.alibaba-inc.com/*/merge_requests/*`
- 包含 "merge request" 或 "MR" 关键词的 URL

## 执行示例

### 示例 1：标准流程

```
用户："提交代码评审"

你的处理流程：
1. 获取当前分支：feat/v1.0.0_hungrated
2. 提取目标分支：feat/v1.0.0
3. 从 project-setup.spec.md 读取评审人：杭歌
4. 执行：sh codereview.sh feat/v1.0.0 杭歌
5. 从输出中提取到链接：https://code.alibaba-inc.com/project/repo/merge_requests/123
6. 运行 SA CHECK：执行代码质量检查，提示检查结果
7. 告知用户："代码评审已创建成功！
   CR 链接：https://code.alibaba-inc.com/project/repo/merge_requests/123
   是否需要打开此链接？"
```

### 示例 2：简化触发

```
用户："帮我 CR 一下"

你的处理流程：
1. 获取当前分支：fix/bf_test
2. 提取目标分支：fix/bf
3. 从 project-setup.spec.md 读取评审人：杭歌
4. 执行：sh codereview.sh fix/bf 杭歌
5. 从输出中提取 CR 链接
6. 运行 SA CHECK：执行代码质量检查，提示检查结果
7. 展示链接并询问用户是否打开
```

## 错误处理

如果执行过程中出现错误，必须：

1. **明确告知用户错误信息**：完整显示命令返回的错误信息
2. **解释错误原因**：用通俗语言说明错误含义
3. **提供解决方案**：给出具体的解决步骤

### 常见错误处理示例

```
错误 1：nothing to commit, working tree clean
→ 告知用户："当前没有需要提交的代码变更，无法创建代码评审。"

错误 2：fatal: not a git repository
→ 告知用户："当前目录不是 Git 仓库，无法执行代码评审。"

错误 3：error: failed to push
→ 告知用户："推送失败，可能是网络问题或权限不足。请检查：
   1. 网络连接是否正常
   2. 是否有仓库推送权限
   3. 远程分支是否存在"

错误 4：merge conflict
→ 告知用户："合并目标分支时发生冲突，请先解决冲突：
   1. 查看冲突文件：git status
   2. 手动解决冲突
   3. 提交解决后的代码
   4. 重新执行代码评审"
```

## 链接处理

- 如果成功提取到 CR 链接：
  - 明确展示完整的 CR 链接
  - 询问用户："是否需要打开此链接？"
  - 如果用户确认，使用 `open` 命令打开链接

- 如果未能提取到 CR 链接：
  - 告知用户命令执行结果
  - 说明可能的原因（如：CR 创建失败、输出格式异常等）

## 参数

- `--reviewer`: 可选，指定评审人（覆盖 project-setup.spec.md 中的默认值）
- `--target-branch`: 可选，指定目标分支（覆盖自动提取的值）

## 注意事项

- **代码评审前必须先提交代码**：如果有未提交的变更，先自动执行 `commit_push` 命令
- 检测到触发词后，先检查代码状态，再决定是否需要提交
- 必须从命令行输出中提取 CR 链接并展示给用户
- 提取到链接后，询问用户是否打开
- 如果命令执行失败，需要展示完整错误信息并提供解决方案
- **重要提示**：代码评审前必须确保所有变更已提交到本地仓库
