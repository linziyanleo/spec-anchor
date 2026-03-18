# specanchor_task

创建 Task Spec，自动加载相关 Global + Module Spec 上下文，进入开发流程。

**用户可能这样说**: "我要做一个登录页增加验证码的任务" / "创建任务：修复订单列表分页 bug" / "开始新任务，给搜索模块加缓存" / "新建一个任务 Spec"

## 参数

- `name`（必须，从用户描述提取）: 任务名称
- `modules`（可选）: 关联模块路径列表。不指定则从任务描述自动推断

## 执行

1. 确定关联模块（用户指定 or 从任务描述自动推断目标文件路径）
2. **Module Spec 覆盖度检查**：
   - 扫描 `.specanchor/modules/` 下所有 `.spec.md` 文件，读取每个文件 frontmatter 中的 `module_path` 字段
   - 判断任务涉及的文件路径是否被某个 Module Spec 的 `module_path` 覆盖（文件路径以 `module_path` 为前缀即视为覆盖）
   - 例如：`module_path: "src/app/bloom/knowledge/components/mini-galaxy"` 覆盖该路径下所有文件和子目录
   - **已覆盖** → On-Demand 加载对应 Module Spec，继续后续步骤
   - **未覆盖** → 自动执行 `specanchor_infer` 为该模块生成 Module Spec 草稿（status=draft），然后加载并继续
3. 确定存储路径：
   - 单模块 → `.specanchor/tasks/<module_name>/YYYY-MM-DD_<task>.spec.md`
   - 多模块 → `.specanchor/tasks/_cross-module/YYYY-MM-DD_<task>.spec.md`
   - 目录不存在 → 自动创建
4. 使用 `references/task-spec-template.md` 生成 Task Spec：
   - 默认使用 SDD-RIPER-ONE 模板（含完整 RIPER 段）
   - 用户明确要求简化模式 → 使用简化模板
5. 填充 SpecAnchor frontmatter
6. 写入文件

## 覆盖度检查细节

覆盖度判断使用路径前缀匹配：

```
任务目标文件: src/app/bloom/knowledge/components/mini-galaxy/GalaxyView.tsx

已有 Module Spec:
  - module_path: "src/app/bloom/knowledge/components/mini-galaxy"  → ✅ 覆盖
  - module_path: "src/app/bloom/knowledge"                         → ✅ 覆盖（父级也覆盖）
  - module_path: "src/app/bloom/other-module"                      → ❌ 不覆盖
```

当有多个 Module Spec 可覆盖同一路径时，选择 `module_path` 最长（最精确）的那个。

## 自动生成 Module Spec 的行为

未覆盖时自动执行 `specanchor_infer`：
- 告知用户：`模块 <path> 尚无 Module Spec，正在从代码推断草稿...`
- 生成完成后告知用户：`Module Spec 草稿已生成（status=draft），建议后续人工确认`
- 然后继续创建 Task Spec 流程
