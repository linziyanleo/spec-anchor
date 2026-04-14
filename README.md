# SpecAnchor

[English](README_EN.md) | [为什么需要 SpecAnchor](WHY.md)

> Spec 是锚，代码是船。锚定住了，船才不会漂。

SpecAnchor 是一个 **AI Skill**，提供三级 Spec 管理体系（Global → Module → Task），在 AI 生成代码之前自动加载团队规范和模块契约。

它是 Spec 的"图书馆"，不是"写作工具"——兼容 SDD-RIPER-ONE、OpenSpec 及任何 Markdown 格式的 Spec。锚定的不只是 AI 上下文，更是人对代码的认知。

它只负责 Spec 治理，不承接提交、评审或启停项目这类开发工作流操作。

---

## 核心理念

与 RAG 式的"每次从代码重新推导"不同，SpecAnchor 采用**编译式知识**范式——把代码洞察提前编译为持久化的 Spec 文件，AI 编码前直接加载已编译的上下文。一次编写，反复使用，知识持续复利。（详见 [WHY.md §编译式知识 vs 检索式知识](WHY.md#编译式知识-vs-检索式知识)）

```
SpecAnchor = 组织管理层（Spec 放在哪、健不健康、谁有权改）
写作协议   = 可插拔（SDD-RIPER-ONE / OpenSpec / 自定义 Schema）
```

**三级 Spec 体系**：

| 层级  | 名称          | 内容              | 变更频率 | 路径                     |
| --- | ----------- | --------------- | ---- | ---------------------- |
| L1  | Global Spec | 编码标准、架构约定、项目配置  | 季度级  | `.specanchor/global/`  |
| L2  | Module Spec | 接口契约、业务规则、代码结构  | 迭代级  | `.specanchor/modules/` |
| L3  | Task Spec   | 单次变更的目标、计划、执行日志 | 每任务  | `.specanchor/tasks/`   |

---

## 快速安装

### Cursor

```bash
# 项目级安装
cp -r /path/to/SpecAnchor/ your-project/.cursor/skills/specanchor/

# 或 symlink（开发时推荐）
ln -s /path/to/SpecAnchor your-project/.cursor/skills/specanchor

# 或全局安装
cp -r /path/to/SpecAnchor/ ~/.cursor/skills/specanchor/
```

### Claude Code

```bash
cp -r /path/to/SpecAnchor/ your-project/.agents/skills/specanchor/
```

在 `CLAUDE.md` 或 `AGENTS.md` 中添加：`使用 SpecAnchor 管理 Spec：参考 .agents/skills/specanchor/SKILL.md`

### 其他 AI 工具

SpecAnchor 是纯文本 Skill，可在任何支持读取文件的 AI 工具中使用。将目录复制到项目中，在 AI 工具配置中引用 `SKILL.md` 即可。

---

## 推荐流程

### 首次使用

```
"帮我初始化 SpecAnchor"          → 生成 anchor.yaml + 可选 .specanchor/ + 自动生成 Global Spec
                                   （自动检测已有 spec 体系并写入 sources 配置）
"帮我创建 auth 模块的规范"        → 触碰模块时按需创建 Module Spec
```

### 日常开发

```
"创建任务：登录页增加验证码"      → 自动加载 Global + Module Spec，创建 Task Spec
 ↓ 按 Task Spec 开发
"检查 Spec 和代码对齐"           → Spec-代码一致性校验
```

### 命令速查

| 意图   | 说法示例                                |
| ---- | ----------------------------------- |
| 初始化  | "初始化 SpecAnchor" / "初始化项目信息"        |
| 全局规范 | "生成编码规范" / "生成架构约定"                 |
| 模块规范 | "创建 auth 模块规范" / "从代码推断模块规范"        |
| 任务   | "创建任务：XX功能"                         |
| 检测   | "检查 Spec 对齐" / "覆盖率报告" / "模块规范是否过期" |
| 外部导入 | "导入 OpenSpec 配置" / "兼容 OpenSpec"    |

---

## 使用策略

### 团队标准

| 操作             | 建议频率         | 负责人                 |
| -------------- | ------------ | ------------------- |
| Global Spec 更新 | 季度级          | 工程师（Peer Review）    |
| Module Spec 创建 | 触碰模块时        | 工程师 / 协作者（需 Review） |
| Task Spec 创建   | 每个任务         | 工程师 & 协作者           |
| 覆盖率检查          | 每个 Sprint 结束 | 工程师                 |
| Spec-代码对齐检测    | MR 提交时       | 自动 / 手动             |

### 渐进式覆盖

不追求 100% 覆盖，让最重要的模块先有 Spec。详见 [冷启动方案](WHY.md#存量项目冷启动方案)。

---

## 与 SDD-RIPER-ONE / OpenSpec 的关系

SpecAnchor 只管"组织"，不管"写作"——通过声明式 Schema 系统兼容任何 Spec 格式：

| 写作协议                  | 哲学     | 说明                                      | 切换方式                                         |
| --------------------- | ------ | --------------------------------------- | -------------------------------------------- |
| **SDD-RIPER-ONE**（默认） | strict | Research → Plan（门禁）→ Execute → Review   | 默认，无需配置                                      |
| **OpenSpec**          | fluid  | Proposal → Delta Specs → Design → Tasks | `writing_protocol.schema: "openspec-compat"` |
| **自定义**               | 用户定义   | 在 `.specanchor/schemas/` 下创建            | `writing_protocol.schema: "<name>"`          |

### 兼容 OpenSpec

已有 OpenSpec 项目可通过 `sources` 配置将 `openspec/` 目录纳入 SpecAnchor 治理，无需移动文件：

```yaml
# anchor.yaml（项目根目录）
specanchor:
  sources:
    - path: "openspec/specs"
      type: "openspec"
      maps_to: module_specs
      governance:
        stale_check: true
        frontmatter_inject: false
    - path: "openspec/changes"
      type: "openspec"
      maps_to: task_specs
      exclude: ["archive"]
      governance:
        stale_check: true
```

使用"导入 OpenSpec 配置"命令可自动生成以上配置。

### 兼容其他 Spec 体系

SpecAnchor 支持治理多种 spec 体系，初始化时自动检测：

| 体系 | 检测路径 | 说明 |
| ---- | ---- | ---- |
| OpenSpec | `openspec/` | Spec-Driven Development 框架 |
| spec-kit | `specs/` | 通用 spec 目录 |
| mydocs | `mydocs/specs/` | SDD-RIPER-ONE 独立使用时的产出 |
| qoder | `.qoder/specs/` | Qoder AI 框架 |
| 自定义 | 用户指定 | 任何 Markdown spec 目录 |

**两种运行模式**：
- **full** — 有 `.specanchor/` 自有 Spec 体系 + 可选治理外部来源
- **parasitic** — 无 `.specanchor/`，纯治理已有 spec 体系（腐化检测 + 扫描）

### SpecAnchor 的独有能力

OpenSpec 和 SDD-RIPER-ONE 都不提供以下治理功能：

- **Spec 覆盖率检测** — 哪些模块有 Spec、哪些没有
- **Spec 腐化检测** — 哪些 Spec 过期了（代码改了但 Spec 没同步）
- **角色权限矩阵** — 工程师 vs外部协作者的 Spec 操作权限
- **模块索引** — `module-index.md` 集中索引所有 Module Spec

---

## 目录结构

### Skill 本体

```
SpecAnchor/
├── SKILL.md                     ← Skill 入口
├── references/
│   ├── specanchor-protocol.md   ← 核心协议
│   ├── commands/                ← 命令定义（按需读取）
│   ├── schemas/                 ← 写作协议 Schema 定义
│   └── *.md                    ← 模板和参考文件
└── scripts/
    ├── specanchor-init.sh       ← 初始化脚本（目录+配置）
    ├── specanchor-boot.sh       ← 启动检查脚本
    ├── specanchor-status.sh     ← 状态报告脚本
    ├── specanchor-index.sh      ← 索引生成脚本
    ├── specanchor-check.sh      ← 对齐检测脚本
    ├── frontmatter-inject.sh    ← Frontmatter 注入
    └── frontmatter-inject-and-check.sh ← 注入+检测组合
```

### 安装后的项目结构（full 模式）

```
your-project/
├── anchor.yaml                  ← 配置（项目根目录，唯一入口）
├── .specanchor/                 ← 纯数据目录
│   ├── global/                  ← L1: Global Spec（≤200 行）
│   ├── modules/                 ← L2: Module Spec（集中存放）
│   ├── module-index.md          ← 模块索引
│   ├── tasks/                   ← L3: Task Spec（按模块分目录）
│   ├── archive/                 ← 已完成任务归档
│   ├── schemas/                 ← 用户自定义 Schema（可选）
│   └── scripts/                 ← 自动生成的扫描脚本
└── src/
```

### 安装后的项目结构（parasitic 模式）

```
your-project/
├── anchor.yaml                  ← 配置（仅此一个文件）
├── .specanchor/
│   └── scripts/                 ← 自动生成的扫描脚本
├── specs/                       ← 已有 spec 体系（不动）
└── src/
```

---

## 配置

项目根目录的 `anchor.yaml` 控制 SpecAnchor 的行为，完整配置见 `references/specanchor-protocol.md` 附录 A。

关键配置项：

```yaml
specanchor:
  version: "0.4.0"
  mode: "full"                      # full | parasitic
  sources:                          # 外部 spec 体系（可选）
    - path: "specs/"
      type: "spec-kit"
      governance:
        stale_check: true
  writing_protocol:
    schema: "sdd-riper-one"         # 写作协议：sdd-riper-one | openspec-compat | 自定义
  coverage:
    scan_paths: ["src/modules/**"]  # 覆盖率扫描范围
  check:
    stale_days: 14                  # Spec 过期天数阈值
    outdated_days: 30               # Spec 严重过期天数阈值
```

---

## License

MIT
