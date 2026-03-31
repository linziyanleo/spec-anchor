# specanchor_task

创建 Task Spec，自动加载相关 Global + Module Spec 上下文，进入开发流程。

**用户可能这样说**: "我要做一个登录页增加验证码的任务" / "创建任务：修复订单列表分页 bug" / "开始新任务，给搜索模块加缓存" / "新建一个任务 Spec"

## 参数

- `name`（必须，从用户描述提取）: 任务名称
- `modules`（可选）: 关联模块路径列表。不指定则从任务描述自动推断

## 执行

1. 确定关联模块（用户指定 or 从任务描述自动推断目标文件路径）
2. **Module Spec 覆盖度检查**：
   - 运行 `scripts/specanchor-check.sh coverage <file1> [file2] ...` 传入任务涉及的所有目标文件路径
   - 脚本自动扫描 `.specanchor/modules/` 中所有 Module Spec 的 `module_path` 字段，通过路径前缀匹配判断覆盖度
   - **已覆盖** → 输出 `✅ 已覆盖: <模块名> (<spec文件>)`，On-Demand 加载对应 Module Spec，继续后续步骤
   - **未覆盖** → 输出 `⚠️ 未覆盖: <路径> → 自动推断 Module Spec`，执行 `specanchor_infer` 生成草稿（status=draft），然后加载并继续
3. 确定存储路径：
   - 单模块 → `.specanchor/tasks/<module_name>/YYYY-MM-DD_<task>.spec.md`
   - 多模块 → `.specanchor/tasks/_cross-module/YYYY-MM-DD_<task>.spec.md`
   - 目录不存在 → 自动创建
4. Schema 加载：
   - **4a. Schema 已确认？**
     - 用户在工作流选择时已确认 Schema → 直接使用，跳到 4c
     - 用户显式指定了 Schema（如"用 refactor Schema 创建任务"）→ 直接使用，跳到 4c
     - 否 → 继续 4b
   - **4b. Schema 推荐（降级路径）**
     - 当直接调用 specanchor_task 未经工作流选择时执行
     - Agent 参考启动时发现的 Available Schemas（§1 步骤 4），结合任务描述判断：
       - 有明确最佳匹配 → 展示推荐，等待用户确认
       - 有多个接近匹配 → 展示推荐 + 备选
       - 无明确匹配 → 使用 `anchor.yaml` 的 `writing_protocol.schema` 默认值（默认 `sdd-riper-one`）
   - **4c. 加载选中 Schema**
     - 按查找顺序（`.specanchor/schemas/<name>/` → `references/schemas/<name>/`）定位 Schema
     - 读取 `schema.yaml` 和 `template.md`
     - 查找失败 → fallback 到默认 Schema（`sdd-riper-one`）
   - **4d. 设置后续 Agent 行为**
     - 根据 Schema 的 `philosophy` 字段：
       - `strict` → 启用门禁检查（Schema 中 `gate` 定义的所有门禁）
       - `fluid` → 无门禁，artifact 依赖关系仅作为建议
5. 填充 SpecAnchor frontmatter
   - 如果步骤 4d 产生了推荐（非默认 Schema），在 Task Spec 的 §1 Context 中记录：

     ```
     - **Schema**: <schema_name>（推荐原因：<模型判断的理由>）
     ```

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
