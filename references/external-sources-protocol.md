# Sources Protocol

当 `anchor.yaml` 中配置了 `sources` 时，SpecAnchor 将外部 spec 体系的目录纳入治理范围。

**设计原则**：不移动文件、不复制文件，纯读取映射。外部文件保持在原位，SpecAnchor 在扫描时将其纳入。

## §1 配置格式

```yaml
# anchor.yaml（项目根目录）
specanchor:
  sources:
    - path: "specs/"                       # 来源目录（相对项目根目录）
      type: "spec-kit"                     # 体系类型（参考 specanchor-protocol.md 附录 B type registry）
      maps_to: module_specs                # 映射目标：module_specs | task_specs | global_specs
      file_pattern: "**/*.spec.md"         # 文件匹配（type 有默认值，可覆盖）
      exclude: []                          # 排除的子目录或文件名
      governance:                          # 治理策略
        stale_check: true                  # 纳入腐化检测
        frontmatter_inject: false          # 是否注入 SpecAnchor frontmatter
        scan_on_init: true                 # init 时扫描并生成报告

    - path: ".qoder/specs/"
      type: "qoder"
      maps_to: module_specs
      file_pattern: "**/*.md"
      governance:
        stale_check: true
        frontmatter_inject: true
        scan_on_init: true
```

### 字段说明

| 字段 | 必须 | 类型 | 说明 |
| ---- | ---- | ---- | ---- |
| `path` | 是 | string | 来源目录路径，相对于项目根目录 |
| `type` | 是 | string | 体系类型，参考 type registry。影响默认 `file_pattern` 和 `maps_to` |
| `maps_to` | 否 | enum | 映射目标：`module_specs` / `task_specs` / `global_specs`。type 有默认值 |
| `file_pattern` | 否 | string | 文件匹配 glob 模式。type 有默认值，可覆盖。支持 `*`、`**`、`?` 通配符 |
| `exclude` | 否 | list | 排除的子目录或文件名列表 |
| `governance` | 否 | object | 治理策略对象，控制该来源的治理力度 |

### governance 字段说明

| 字段 | 默认 | 说明 |
| ---- | ---- | ---- |
| `stale_check` | `true` | 是否纳入腐化检测。启用后 `specanchor_check` 和 scan.sh 会扫描该来源 |
| `frontmatter_inject` | `false` | 是否注入 SpecAnchor YAML frontmatter。`specanchor_init` 时询问用户确认后，使用 `scripts/frontmatter-inject.sh` 自动注入。也可随时手动运行脚本批量注入 |
| `scan_on_init` | `true` | init 时是否扫描该来源并生成报告 |

## §2 启动检查扩展

当 `sources` 存在且非空时，启动检查流程（见 `specanchor-protocol.md` §1）的步骤 3 中：

```
mode: full 时:
  加载 Global Spec 后，检查 sources 配置
  ├─ 遍历每个 source 条目
  ├─ 检查 path 目录是否存在
  │   ├─ 不存在 → 警告但不阻塞：
  │   │   ⚠️ source "<path>" 目录不存在，跳过
  │   └─ 存在 → 记录为可用来源，统计匹配文件数
  └─ 在加载状态摘要中展示来源信息

mode: parasitic 时:
  sources 是核心功能，处理逻辑同上
```

## §3 降级解析规则

当外部文件不使用 SpecAnchor YAML frontmatter 时，采用以下降级策略推断元信息。

### 映射为 module_specs 时

| 元信息字段 | 降级推断方式 |
| ---------- | ------------ |
| `module_name` | 从目录名推断（如 `specs/auth/` → "auth"） |
| `module_path` | 从目录名推断，结合 `coverage.scan_paths` 模糊匹配找到最可能的模块路径 |
| `version` | 无版本信息，显示 "N/A" |
| `owner` | 无，显示 "unassigned" |
| `status` | 固定为 "active" |
| `last_synced` | 取文件的 git 最后修改日期 |

**模块路径模糊匹配**：从 `coverage.scan_paths` 中的每个路径模式提取模块名（如 `src/modules/**` → 扫描 `src/modules/` 下是否有与 spec 目录名同名的目录），找到则建立映射。找不到则 `module_path` 设为 "unknown"，仍然计入覆盖率统计但无法做路径精确匹配。

### 映射为 task_specs 时

| 元信息字段 | 降级推断方式 |
| ---------- | ------------ |
| `task_name` | 从文件名或目录名推断 |
| `status` | 检查文件中的 checklist：全部 `[x]` → "done"，否则 → "in_progress" |
| `created` | 取文件的 git 首次提交日期 |
| `related_modules` | 从文件内容中提取模块引用 |
| RIPER phase | 不注入 frontmatter；如使用 SDD 模式，写入正文 `> Current RIPER Phase: ...` marker |

## §4 spec-index.md 扩展

当存在 sources 时，`spec-index.md` 的 v3 格式在 `specs.modules[]` 数组中通过 `source` 字段区分来源：

```yaml
specs:
  modules:
    - path: "src/modules/auth"
      spec: "src-modules-auth.spec.md"
      summary: "用户认证与鉴权"
      source: native
      status: active
      health: FRESH
      # ...

    - path: "src/modules/payment"
      spec: "specs/payments/spec.md"
      summary: "支付处理"
      source: "external:spec-kit"
      status: active
      health: DRIFTED
      # ...

    - path: "src/modules/ui"
      spec: ".qoder/specs/ui.md"
      summary: "UI 组件库"
      source: "external:qoder"
      status: active
      health: FRESH
      # ...
```

- `native`：SpecAnchor 原生格式（有 YAML frontmatter），存放在 `.specanchor/modules/`
- `external:<type>`：外部来源，标注其类型。外部来源的 `spec` 字段指向原始路径而非 `.specanchor/modules/` 下的副本

## §5 命令行为扩展

### specanchor_status

输出中增加 sources 统计：

```
Sources:
  specs/ [spec-kit]: 12 files, stale_check: ✅, frontmatter_inject: ❌
  .qoder/specs/ [qoder]: 5 files, stale_check: ✅, frontmatter_inject: ✅
```

### specanchor_check

覆盖率计算时：
- `maps_to: module_specs` 的 source 文件计入模块覆盖率
- `maps_to: task_specs` 的 source 文件计入活跃任务统计（不影响覆盖率）

腐化检测时（仅 `governance.stale_check: true` 的来源）：
- 无 frontmatter 的文件使用 git 最后修改日期替代 `last_synced` 字段
- `stale_days` 和 `outdated_days` 阈值同样适用

`specanchor_check` 执行时自动调用 `.specanchor/scripts/scan.sh`（如存在）。

### On-Demand 加载

当用户提及的文件路径匹配到 source 的模块时：
1. 通过扩展后的 `spec-index.md` 查找
2. 找到 source 来源 → 从外部路径读取 spec 文件并注入上下文
3. 提示用户："ℹ️ 已加载外部来源的 Module Spec: `<path>`（来自 <type>，无 frontmatter）"

## §6 Frontmatter 注入工具

当 `governance.frontmatter_inject: true` 时，使用 `scripts/frontmatter-inject.sh`（Layer 1）自动注入 SpecAnchor YAML frontmatter。

### 基本用法

```bash
# $SA_SKILL_DIR = Skill 安装目录（见 SKILL.md「脚本调用约定」）

# 预览注入效果（不修改文件）
bash "$SA_SKILL_DIR/scripts/frontmatter-inject.sh" --dir <source_path> --dry-run

# 实际注入
bash "$SA_SKILL_DIR/scripts/frontmatter-inject.sh" --dir <source_path> --level module

# 注入 + 新鲜度检测一步完成（Layer 2）
bash "$SA_SKILL_DIR/scripts/frontmatter-inject-and-check.sh" --dir <source_path> --level module
```

### 自动推断字段

| 字段 | 推断方式 |
| ---- | ---- |
| `author` | `git config user.name` |
| `created` | git 首次提交日期 → 文件名日期前缀 → 当前日期 |
| `branch` | `git branch --show-current` |
| `task_name` / `module_name` | 从 H1 标题提取 → 从文件名推断 |
| `writing_protocol` | 从 `anchor.yaml` 的 `writing_protocol.schema` 读取 |
| `status` | 从 checklist 完成度推断（全部完成→done，部分→in_progress，无→draft） |
| `related_global` | 扫描 `.specanchor/global/` 列出所有 .spec.md |
| `related_modules` | 从文件内容匹配 spec-index.md |

### 三种情况处理

1. 文件无 frontmatter → 文件头部插入完整 frontmatter
2. 有 frontmatter 无 `specanchor:` 段 → 追加 `specanchor:` 段，不覆盖原有字段
3. 已有 `specanchor:` 段 → 跳过（幂等安全）

## §7 注意事项

- **不写入外部目录**：SpecAnchor 对 sources 中的目录只读，永远不写入或修改外部文件（frontmatter 注入除外，且需用户明确同意）
- **优先级**：当 native 和 source 同时覆盖同一模块路径时，native 优先
- **性能**：启动检查时只做目录存在性检查和文件计数，不解析文件内容。内容解析在 On-Demand 时进行
- **parasitic 模式**：sources 是 parasitic 模式的核心功能，所有治理能力（腐化检测、扫描、覆盖率）都通过 sources 提供
