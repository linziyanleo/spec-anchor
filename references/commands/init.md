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

4. **自动扫描外部 SDD 框架**：
   - 检查 `openspec/` 目录是否存在
     - 存在 → 提示：`ℹ️ 检测到 OpenSpec 目录 (openspec/)。建议运行"导入 OpenSpec 配置"（specanchor_import）生成 external_sources 映射，将 OpenSpec 的 Spec 纳入 SpecAnchor 管理。`
   - 检查 `mydocs/specs/` 目录是否存在（SDD-RIPER-ONE 独立使用时的产出）
     - 存在 → 提示：`ℹ️ 检测到 SDD-RIPER-ONE 产出 (mydocs/specs/)。建议将活跃的 Task Spec 迁移到 .specanchor/tasks/ 目录下，归档的移到 .specanchor/archive/。`，并列出检测到的文件

5. **自动生成 Global Spec**：扫描项目代码，为检测到的所有适用规范类型自动生成 Global Spec 草稿
   - 扫描 `package.json` / `tsconfig.json` → 生成 `project-setup.spec.md`
   - 扫描代码文件模式、ESLint/Prettier 配置 → 生成 `coding-standards.spec.md`
   - 扫描目录结构、路由配置 → 生成 `architecture.spec.md`
   - 每个 Global Spec 生成后输出 `📄 已生成: .specanchor/global/<type>.spec.md`
   - 最后检查所有 Global Spec 合计是否 ≤ 200 行，超出则警告并建议精简
   - 提示用户 Review 生成的内容

6. 输出完成信息和目录结构
