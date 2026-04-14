# specanchor_init

初始化 SpecAnchor 配置。根据用户选择的模式，生成根目录 `anchor.yaml` 和可选的 `.specanchor/` 目录结构。

**用户可能这样说**: "帮我初始化规范管理" / "初始化 SpecAnchor" / "创建 anchor.yaml" / "我要开始用 SpecAnchor"

## 参数

- `project_name`（可选）: 默认取当前目录名
- `scan`（可选）: 设为 `true` 时扫描项目自动生成 Global Spec 草稿（用户说"初始化并扫描项目"）

## 执行

**首选方式**：先运行 `scripts/specanchor-init.sh` 完成目录结构和配置的确定性部分，再由 Agent 完成 Global Spec 生成等需要代码分析的步骤：

```bash
# 步骤 1: 脚本完成目录和配置初始化
bash "<skill_install_dir>/scripts/specanchor-init.sh" --project=<name> [--scan-sources]

# 步骤 2: Agent 扫描代码生成 Global Spec（需要代码语义分析）
# 由 Agent 执行 specanchor_global 命令
```

**脚本处理的部分**（步骤 1, 4-6）：检查已初始化、目录结构创建、anchor.yaml 生成、module-index.md 初始化、外部来源检测。
**Agent 处理的部分**（步骤 2-3, 7-12）：来源治理策略确认、模式选择（需交互）、scan.sh 生成、git hook 配置、Global Spec 生成、Frontmatter 注入。

### 详细步骤

1. **检查是否已初始化**。检查项目根目录 `anchor.yaml` 是否已存在。已存在则报错：`anchor.yaml 已存在，如需重新初始化请先手动删除`

2. **扫描项目根目录，自动检测已有 spec 体系**（基于 Type Registry，见 `specanchor-protocol.md` 附录 B）：

   ```
   扫描路径:
   ├─ openspec/          → type: "openspec"
   ├─ specs/             → type: "spec-kit"
   ├─ mydocs/specs/      → type: "mydocs"
   ├─ .qoder/specs/      → type: "qoder"
   ├─ docs/specs/        → type: "generic"
   └─ 用户手动指定       → type: "custom"
   ```

   - 每发现一个目录，统计匹配文件数（使用 type registry 中的默认 `file_pattern`）
   - 输出检测结果：

     ```
     🔍 检测到以下 spec 体系:
       specs/          [spec-kit]    12 个 spec 文件
       .qoder/specs/   [qoder]       5 个 spec 文件
     ```

   - 未发现任何外部 spec 体系 → 跳过 sources 配置，直接到步骤 4

3. **确认治理策略**（仅当步骤 2 检测到外部来源时）：

   逐个询问用户每个来源的治理策略：

   ```
   specs/ [spec-kit] — 是否纳入 SpecAnchor 治理？(Y/n)
     ├─ 纳入腐化检测 (stale_check)？(Y/n)
     ├─ 注入 SpecAnchor frontmatter？(y/N)
     └─ init 时扫描并生成报告？(Y/n)
   ```

   用户选择拒绝纳入的来源不写入 `sources` 段。

4. **选择运行模式**：

   ```
   请选择 SpecAnchor 运行模式:
     [1] full — 创建 .specanchor/ 自有 Spec 体系 + 治理外部来源（推荐）
     [2] parasitic — 仅治理已有 spec 体系，不创建 .specanchor/
   ```

   - 如果步骤 2 未检测到任何外部来源 → 自动选择 full 模式，跳过此询问
   - parasitic 模式提示：`parasitic 模式只提供腐化检测和扫描能力，不支持创建 Spec。如需创建 Spec，后续可运行 "升级到 full 模式" 进行升级。`

5. **生成根目录 `anchor.yaml`**：

   根据步骤 2-4 的结果生成配置。模板见 `specanchor-protocol.md` 附录 A。

   - `mode` 设为用户选择的模式
   - `sources` 段根据步骤 3 的确认结果生成
   - `scan_paths` 根据项目实际目录结构调整
   - parasitic 模式下 `paths` 段注释掉

6. **创建 `.specanchor/` 目录结构**（仅 mode: full）：

   ```
   .specanchor/
   ├── global/
   ├── modules/
   ├── tasks/
   │   └── _cross-module/
   ├── archive/
   ├── scripts/
   ├── module-index.md
   └── project-codemap.md
   ```

   parasitic 模式跳过此步，但仍创建 `.specanchor/scripts/` 用于存放扫描脚本。

7. **生成扫描脚本** `.specanchor/scripts/scan.sh`：

   根据 `anchor.yaml` 的 `sources` 和 `coverage` 配置自动生成。脚本功能：
   - 扫描所有 sources 中的文件，检测腐化状态（基于 git 最后修改日期 vs `check.stale_days`）
   - mode: full 时同时扫描 `.specanchor/modules/` 中的 native spec
   - 输出腐化报告（FRESH / STALE / OUTDATED）

   脚本可独立运行（`bash .specanchor/scripts/scan.sh`），也可被 `specanchor_check` 命令自动调用。

8. **可选：配置 git hook**：

   ```
   是否配置 git pre-commit hook 自动运行腐化检测？(y/N)
   ```

   用户确认 → 在 `.git/hooks/pre-commit`（或 `.husky/pre-commit`，如检测到 husky）中追加 scan.sh 调用。
   用户拒绝 → 跳过，输出：`⏭️ 可随时手动配置 git hook。`

9. **自动生成 Global Spec**（仅 mode: full）：

   扫描项目代码，为检测到的所有适用规范类型自动生成 Global Spec 草稿：
   - 扫描 `package.json` / `tsconfig.json` → 生成 `project-setup.spec.md`
   - 扫描代码文件模式、ESLint/Prettier 配置 → 生成 `coding-standards.spec.md`
   - 扫描目录结构、路由配置 → 生成 `architecture.spec.md`
   - 如步骤 2 检测到 OpenSpec 且其 `config.yaml` 含 `context` / `rules`，合并到对应 Global Spec
   - 每个 Global Spec 生成后输出 `📄 已生成: .specanchor/global/<type>.spec.md`
   - 检查所有 Global Spec 合计是否 ≤ 200 行，超出则警告并建议精简
   - 提示用户 Review 生成的内容

10. **可选：Frontmatter 注入**（仅当 sources 中有 `frontmatter_inject: true` 的来源时）：

    使用 frontmatter-inject.sh 脚本自动注入（`$SA_SKILL_DIR` 定义见 SKILL.md「脚本调用约定」）。对每个启用了 frontmatter_inject 的来源：

    ```bash
    # 先 dry-run 预览
    bash "$SA_SKILL_DIR/scripts/frontmatter-inject.sh" --dir <source_path> --level <maps_to_level> --dry-run

    # 确认后实际注入
    bash "$SA_SKILL_DIR/scripts/frontmatter-inject.sh" --dir <source_path> --level <maps_to_level>
    ```

    脚本自动处理三种情况：
    - **文件无 frontmatter** → 在文件头部插入完整 `specanchor:` frontmatter
    - **文件有 frontmatter 但无 `specanchor:` 段** → 在已有 frontmatter 中追加 `specanchor:` 段，不覆盖原有字段
    - **文件已有 `specanchor:` 段** → 跳过（幂等安全）

    脚本自动推断以下字段：`author`（git config）、`created`（git 首次提交日期或文件名日期前缀）、`branch`（当前分支）、`task_name`/`module_name`（从 H1 标题或文件名推断）、`writing_protocol`（从 anchor.yaml 读取）、`status`（从 checklist 完成度推断）、`sdd_phase`（从已完成章节推断）。

    注入完成后自动输出摘要（N injected / M skipped / K failed）。

11. **可选：注入后新鲜度检测**：

    使用 frontmatter-inject-and-check.sh（Layer 2）可一步完成注入 + 检测：

    ```bash
    # 注入后自动运行新鲜度检测
    bash "$SA_SKILL_DIR/scripts/frontmatter-inject-and-check.sh" --dir <source_path> --level <maps_to_level>

    # 或单独运行检测
    bash "$SA_SKILL_DIR/scripts/specanchor-check.sh" global
    ```

    检测结果展示各 spec 文件的新鲜度状态（FRESH / STALE / OUTDATED），Agent 根据检测结果向用户报告需要关注的腐化 spec。

12. **输出完成信息**：

    ```
    ✅ SpecAnchor 初始化完成 [<mode>]
      配置: anchor.yaml
      目录: .specanchor/ (仅 full 模式显示)
      来源: <N> 个外部 spec 体系已纳入治理
      脚本: $SA_SKILL_DIR/scripts/ (见 SKILL.md「脚本调用约定」)
      Git Hook: 已配置 / 未配置
    ```
