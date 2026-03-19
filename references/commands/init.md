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

4. **自动扫描外部 SDD 框架并导入配置**：
   - 检查 `openspec/` 目录是否存在
     - 存在 → 执行以下导入流程：
       a. 自动将 `external_sources` 配置追加到 `config.yaml`：

          ```yaml
          external_sources:
            - source: "openspec/specs"
              maps_to: module_specs
              format: "openspec"
              file_pattern: "**/spec.md"
            - source: "openspec/changes"
              maps_to: task_specs
              format: "openspec"
              file_pattern: "*"
              exclude: ["archive"]
          ```

       b. 扫描 `openspec/config.yaml`：
          - 提取 `context` 字段 → 自动转译为 Global Spec 草稿（`project-setup.spec.md`），合并到步骤 5 的自动生成流程中
          - 提取 `rules` 字段 → 合并到 `coding-standards.spec.md` 的建议章节
       c. 更新 `module-index.md`：将 `openspec/specs/` 下的模块追加到索引（标注 `来源: external:openspec`）
       d. 输出：`✅ 检测到 OpenSpec 目录 (openspec/)，已自动导入配置。`
   - 检查 `mydocs/specs/` 目录是否存在（SDD-RIPER-ONE 独立使用时的产出）
     - 存在 → 自动将以下配置追加到 `config.yaml` 的 `external_sources` 中：

       ```yaml
       external_sources:  # 追加到已有列表
         - source: "mydocs/specs"
           maps_to: task_specs
           format: "specanchor"
           file_pattern: "**/*.md"
       ```

     - 输出：`✅ 检测到 SDD-RIPER-ONE 产出 (mydocs/specs/)，已自动配置 external_sources 映射。`
     - 列出检测到的文件数量

5. **自动生成 Global Spec**：扫描项目代码，为检测到的所有适用规范类型自动生成 Global Spec 草稿
   - 扫描 `package.json` / `tsconfig.json` → 生成 `project-setup.spec.md`
   - 扫描代码文件模式、ESLint/Prettier 配置 → 生成 `coding-standards.spec.md`
   - 扫描目录结构、路由配置 → 生成 `architecture.spec.md`
   - 如步骤 4 已从 OpenSpec `context` / `rules` 提取内容，合并到对应 Global Spec 中
   - 每个 Global Spec 生成后输出 `📄 已生成: .specanchor/global/<type>.spec.md`
   - 最后检查所有 Global Spec 合计是否 ≤ 200 行，超出则警告并建议精简
   - 提示用户 Review 生成的内容

6. **Frontmatter 适配询问**（仅当步骤 4 检测到 `openspec/` 时）：
   - 统计 `openspec/specs/` 下缺少 YAML frontmatter 的文件数量
   - 询问用户：

     ```
     ℹ️ openspec/specs/ 下有 <N> 个文件缺少 YAML frontmatter。
     添加 frontmatter 后，这些文件将获得完整的 SpecAnchor 治理能力（版本追踪、负责人、状态管理、精确覆盖率检测）。
     不添加也可正常使用，但覆盖率检测基于文件存在性而非元信息。

     是否为这些文件添加 frontmatter？(Y/n)
     ```

   - 用户确认 → 遍历文件，根据文件内容和路径推断元信息，在文件头部插入 frontmatter：

     ```yaml
     ---
     specanchor:
       level: module
       module_name: "<从目录名推断>"
       module_path: "<从 coverage.scan_paths 模糊匹配>"
       version: "1.0.0"
       owner: "@team"
       status: active
       last_synced: "<当前日期>"
     ---
     ```

   - 每个文件处理后输出 `✏️ 已添加 frontmatter: openspec/specs/<path>`
   - 用户拒绝 → 跳过，输出：`⏭️ 跳过 frontmatter 添加，文件保持原样。可随时运行"为 OpenSpec 文件添加 frontmatter"手动执行。`

7. 输出完成信息和目录结构
