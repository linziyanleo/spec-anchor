# specanchor_init

初始化 `.specanchor/` 目录结构和 `config.yaml` 配置文件。

**用户可能这样说**: "帮我初始化规范管理" / "初始化 SpecAnchor" / "创建 .specanchor 目录" / "我要开始用 SpecAnchor"

## 参数

- `project_name`（可选）: 默认取当前目录名
- `scan`（可选）: 设为 `true` 时扫描项目自动生成 Global Spec 草稿（用户说"初始化并扫描项目"）

## 执行

1. 检查 `.specanchor/` 是否已存在。已存在则报错：`目录已存在，如需重新初始化请先手动删除`
2. 创建以下目录结构：

   ```
   .specanchor/
   ├── config.yaml
   ├── global/
   ├── modules/
   ├── tasks/
   │   └── _cross-module/
   ├── archive/
   ├── module-index.md
   └── project-codemap.md
   ```

3. 写入 `config.yaml`，根据项目实际情况调整 `scan_paths`：

   ```yaml
   specanchor:
     version: "0.2.0"
     project_name: "<project_name>"

     paths:
       global_specs: ".specanchor/global/"
       module_specs: ".specanchor/modules/"
       task_specs: ".specanchor/tasks/"
       archive: ".specanchor/archive/"
       module_index: ".specanchor/module-index.md"
       project_codemap: ".specanchor/project-codemap.md"

     coverage:
       scan_paths:
         - "src/modules/**"
         - "src/components/**"
       ignore_paths:
         - "src/components/ui/**"
         - "src/**/*.test.*"
         - "src/**/*.stories.*"

     check:
       stale_days: 14
       outdated_days: 30
       warn_recent_commits_days: 14
       task_base_branch: "main"

     sync:
       auto_check_on_mr: true
       sprint_sync_reminder: true
   ```

4. 若用户要求扫描：扫描项目，为检测到的规范类型生成 Global Spec 草稿
5. 输出完成信息和目录结构
