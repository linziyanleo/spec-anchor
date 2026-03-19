# External Sources Protocol

当 `.specanchor/config.yaml` 中配置了 `external_sources` 时，SpecAnchor 将外部 SDD 框架的目录（如 OpenSpec 的 `openspec/`）中的文件映射为 SpecAnchor 三级体系的一部分。

**设计原则**：不移动文件、不复制文件，纯读取映射。外部文件保持在原位，SpecAnchor 在扫描时将其纳入。

## §1 配置格式

```yaml
# .specanchor/config.yaml
specanchor:
  external_sources:
    - source: "openspec/specs"           # 外部目录路径（相对项目根目录）
      maps_to: module_specs              # 映射目标：module_specs | task_specs | global_specs
      format: "openspec"                 # 文件格式：specanchor（默认）| openspec
      file_pattern: "**/spec.md"         # 文件匹配模式（glob 通配符）
      exclude: []                        # 排除的子目录或文件名

    - source: "openspec/changes"
      maps_to: task_specs
      format: "openspec"
      file_pattern: "*"                  # 每个子目录视为一个 Task
      exclude: ["archive"]
```

### 字段说明

| 字段 | 必须 | 类型 | 说明 |
|------|------|------|------|
| `source` | 是 | string | 外部目录路径，相对于项目根目录 |
| `maps_to` | 是 | enum | 映射目标：`module_specs` / `task_specs` / `global_specs` |
| `format` | 否 | enum | 文件格式，默认 `specanchor`。设为 `openspec` 时启用降级解析 |
| `file_pattern` | 否 | string | 文件匹配 glob 模式，默认 `**/*.md`。支持 `*`、`**`、`?` 通配符 |
| `exclude` | 否 | list | 排除的子目录或文件名列表 |

## §2 启动检查扩展

当 `external_sources` 存在且非空时，启动检查流程在原有步骤 3 和步骤 4 之间插入：

```
3.5 检查 external_sources 配置
    ├─ 遍历每个 source 条目
    ├─ 检查 source 目录是否存在
    │   ├─ 不存在 → 警告但不阻塞：
    │   │   ⚠️ external_source "<source>" 目录不存在，跳过
    │   └─ 存在 → 记录为可用来源，统计匹配文件数
    └─ 在加载状态摘要中展示外部来源信息
```

加载状态摘要扩展格式：

```
SpecAnchor 已加载
  Global Specs: coding-standards (v1.2), architecture (v1.0)
  Module Specs: (按需加载)
  External Sources:
    openspec/specs → module_specs (5 files)
    openspec/changes → task_specs (3 active, 12 archived)
  Config: .specanchor/config.yaml
```

## §3 降级解析规则

当 `format: "openspec"` 时，由于 OpenSpec 文件不使用 YAML frontmatter，SpecAnchor 采用以下降级策略推断元信息。

### 映射为 module_specs 时

| 元信息字段 | 降级推断方式 |
|-----------|------------|
| `module_name` | 从目录名推断（如 `specs/auth/` → "auth"） |
| `module_path` | 从目录名推断，结合 `coverage.scan_paths` 模糊匹配找到最可能的模块路径 |
| `version` | 无版本信息，显示 "N/A" |
| `owner` | 无，显示 "unassigned" |
| `status` | 固定为 "active"（因为在 `specs/` 目录下说明是当前有效的） |
| `last_synced` | 取文件的 git 最后修改日期 |

**模块路径模糊匹配**：从 `coverage.scan_paths` 中的每个路径模式提取模块名（如 `src/modules/**` → 扫描 `src/modules/` 下是否有与 spec 目录名同名的目录），找到则建立映射。找不到则 `module_path` 设为 "unknown"，仍然计入覆盖率统计但无法做路径精确匹配。

### 映射为 task_specs 时

| 元信息字段 | 降级推断方式 |
|-----------|------------|
| `task_name` | 从变更文件夹名推断（如 `changes/add-dark-mode/` → "add-dark-mode"） |
| `status` | 检查 `tasks.md` 中的 checklist：全部 `[x]` → "done"，否则 → "in_progress" |
| `created` | 取文件夹的 git 首次提交日期 |
| `related_modules` | 从 `changes/<name>/specs/` 下的子目录名推断关联模块 |
| `sdd_phase` | 不适用（OpenSpec 无 RIPER 阶段，显示 "N/A"） |

## §4 module-index.md 扩展

当存在 external_sources 时，`module-index.md` 的格式扩展，增加"来源"列：

```markdown
# Module Spec 索引

| 模块路径 | Spec 文件 | 来源 | 状态 |
|----------|----------|------|------|
| src/modules/auth | .specanchor/modules/src-modules-auth.spec.md | native | ✅ active |
| src/modules/payment | openspec/specs/payments/spec.md | external:openspec | ⚠️ 无 frontmatter |
| src/modules/ui | openspec/specs/ui/spec.md | external:openspec | ⚠️ 无 frontmatter |
```

- `native`：SpecAnchor 原生格式（有 YAML frontmatter），存放在 `.specanchor/modules/`
- `external:<format>`：外部来源，标注其格式。`⚠️ 无 frontmatter` 提示覆盖率检测基于文件存在性而非元信息

## §5 命令行为扩展

### specanchor_status

输出中增加 external_sources 统计：

```
External Sources:
  openspec/specs → module_specs: 5 files
  openspec/changes → task_specs: 3 active changes
```

### specanchor_check

覆盖率计算时：
- `maps_to: module_specs` 的 external 文件计入模块覆盖率
- `maps_to: task_specs` 的 external 文件计入活跃任务统计（不影响覆盖率）

腐化检测时：
- external 文件使用 git 最后修改日期替代 `last_synced` 字段
- `stale_days` 和 `outdated_days` 阈值同样适用

### On-Demand 加载

当用户提及的文件路径匹配到 external source 的模块时：
1. 通过扩展后的 `module-index.md` 查找
2. 找到 external 来源 → 从外部路径读取 spec 文件并注入上下文
3. 提示用户："ℹ️ 已加载外部来源的 Module Spec: `<path>`（来自 <source>，无 frontmatter）"

## §6 注意事项

- **不写入外部目录**：SpecAnchor 对 external_sources 只读，永远不写入或修改外部文件
- **优先级**：当 native 和 external 同时覆盖同一模块路径时，native 优先
- **性能**：启动检查时只做目录存在性检查和文件计数，不解析文件内容。内容解析在 On-Demand 时进行
