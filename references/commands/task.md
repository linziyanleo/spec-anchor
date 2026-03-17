# specanchor_task

创建 Task Spec，自动加载相关 Global + Module Spec 上下文，进入开发流程。

**用户可能这样说**: "我要做一个登录页增加验证码的任务" / "创建任务：修复订单列表分页 bug" / "开始新任务，给搜索模块加缓存" / "新建一个任务 Spec"

## 参数

- `name`（必须，从用户描述提取）: 任务名称
- `modules`（可选）: 关联模块路径列表。不指定则从任务描述自动推断

## 执行

1. 确定关联模块（用户指定 or 自动推断）
2. On-Demand 加载关联模块的 Module Spec（通过 `module-index.md` 定位）
3. 确定存储路径：
   - 单模块 → `.specanchor/tasks/<module_name>/YYYY-MM-DD_<task>.spec.md`
   - 多模块 → `.specanchor/tasks/_cross-module/YYYY-MM-DD_<task>.spec.md`
   - 目录不存在 → 自动创建
4. 使用 `references/task-spec-template.md` 生成 Task Spec：
   - 默认使用 SDD-RIPER-ONE 模板（含完整 RIPER 段）
   - 用户明确要求简化模式 → 使用简化模板
5. 填充 SpecAnchor frontmatter
6. 写入文件
