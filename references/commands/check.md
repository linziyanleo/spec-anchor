# specanchor_check

运行 Spec-Commit 对齐检测。通过比对 git 提交和 Spec 内容，检查代码变更是否与 Spec 计划一致、Module Spec 是否过期。

**用户可能这样说**: "检查一下 Spec 和代码是否对齐" / "看看模块规范是否过期了" / "全局覆盖率报告" / "PR 改动和 Spec 计划一致吗"

## 参数

- `level`（从用户意图推断）: `task` / `module` / `global`
- `spec`（task/module 级）: Spec 文件路径，或全部检查
- `base`（task 级可选）: git 基准分支，默认从 config.yaml 读取
- `stale-days`（module 级可选）: 过期天数阈值，默认从 config.yaml 读取（通常 14）

## 执行

调用 `scripts/specanchor-check.sh` 并传递参数。无脚本时由 Agent 直接执行等效 git 命令。

**脚本详细逻辑**: `scripts/specanchor-check.sh`

## 三个级别

**Task 级** — 检查 PR 改动和 Spec 计划是否一致：
- "检查一下这个任务 Spec 和代码改动是否对齐"
- "帮我看看 sms-login 这个任务的对齐情况"
- "用 develop 分支作为基准检查对齐"

**Module 级** — 检查模块规范是否过期：
- "看看 auth 模块的规范是否过期了"
- "检查所有模块规范的新鲜度"
- "用 60 天阈值检查模块规范"

**Global 级** — 查看整体覆盖率：
- "全局覆盖率报告"
- "看看哪些模块还没有规范"
