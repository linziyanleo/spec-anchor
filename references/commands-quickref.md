# SpecAnchor 意图映射

boot 输出已嵌入 `Available Commands:` 紧凑映射；本文件是 boot 缺失或需要人工查表时的 fallback。用户用自然语言描述意图时，根据下表匹配到对应命令，然后读取该命令的详细定义文件执行。所有详细定义路径都相对于 Skill 根目录（即主 `SKILL.md` 所在目录）。

命令语义统一如下：

- 自然语言是主用户接口。
- `specanchor_*` 是 Skill 内部命令 ID，用于路由意图。
- `SA:` 是可选的高级 shorthand，不是单独的 CLI 契约。
- `scripts/*.sh` 是实现辅助入口，不是用户命令语言。

本表只覆盖 SpecAnchor 主 Skill 的核心命令。

## 意图映射表

| 用户意图                                          | 执行动作            | 详细定义                          |
| ------------------------------------------------- | ------------------- | --------------------------------- |
| 初始化规范 / 开始用 SpecAnchor / 创建 .specanchor | `specanchor_init`   | `references/commands/init.md`     |
| 生成编码规范 / 推断架构约定 / 全局规范            | `specanchor_global` | `references/commands/global.md`   |
| 初始化项目信息 / 设置项目信息                     | `specanchor_global` | `references/commands/global.md`（project-setup 类型） |
| 创建模块规范 / 更新模块 Spec / 同步模块规范       | `specanchor_module` | `references/commands/module.md`   |
| 从代码推断模块规范 / 自动生成 Spec 草稿           | `specanchor_infer`  | `references/commands/infer.md`    |
| 创建任务 / 新建任务 Spec / 开始新任务             | `specanchor_task`   | `references/commands/task.md`     |
| 加载规范 / 读取 Spec 到上下文                     | `specanchor_load`   | `references/commands/load.md`     |
| 查看规范状态 / 覆盖率 / 哪些 Spec 加载了          | `specanchor_status` | `references/commands/status.md`   |
| 检测 Spec-代码对齐 / 检查过期 / 覆盖率报告        | `specanchor_check`  | `references/commands/check.md`    |
| 更新规范索引 / 刷新 spec-index                    | `specanchor_index`  | `references/commands/index.md`    |
| 导入 OpenSpec / 兼容 OpenSpec / 从 OpenSpec 迁移  | `specanchor_import` | `references/commands/import.md`   |
| 把任务交给新 chat 继续 / 导出 handoff packet / 跨 session 接手 | `specanchor_handoff` | `references/commands/handoff.md` |
| 写 portfolio handoff / deferred follow-up / cross-task roadmap / 下次会话开场包 | `specanchor_task`（schema=handoff） | `references/schemas/handoff/template.md` |
| 记录新发现 / 写 finding / 跨 session 工程记忆 | `specanchor_finding` → `bash scripts/specanchor-finding.sh new --topic=...` | `references/concepts/findings-ledger.md` |
| 把高价值 finding 转成 spec 变更建议 / 生成 sediment proposal | `specanchor_sediment_propose` → `bash scripts/specanchor-sediment.sh propose --finding=...` | `references/concepts/sediment-proposal.md` |
| 装配 context bundle / 给 agent 取上下文 / 输出 JSON v1 | `specanchor_assemble`（含 `--bundle-schema=context_bundle.v1`） | `references/agents/context-utilities.md` §2 |

## 按场景分组

### 项目初始化

"帮我初始化规范管理" / "初始化 SpecAnchor" → `specanchor_init`
"初始化项目信息" → `specanchor_global`（project-setup 类型）

### 全局规范

"帮我生成编码规范" / "从代码推断架构约定" → `specanchor_global`

### 模块规范

"帮我创建 auth 模块的规范" / "更新用户认证模块的 Spec" → `specanchor_module`
"帮我从代码推断模块规范" / "先自动生成草稿" → `specanchor_infer`

### 任务管理

"创建任务：登录页增加验证码" / "开始新任务" → `specanchor_task`
"加载 auth 模块的规范" → `specanchor_load`

### 状态与检测

"看看规范状态" / "覆盖率怎么样" → `specanchor_status`
"检查 Spec 和代码是否对齐" / "模块规范是否过期" → `specanchor_check`
"更新规范索引" → `specanchor_index`

### 外部导入

"导入 OpenSpec 配置" / "兼容 OpenSpec" / "从 OpenSpec 迁移" → `specanchor_import`

### Findings & Sediment（v0.6 新增）

"发现 auth spec 已过期" / "记一个发现" / "写 finding" → `specanchor_finding`

```bash
bash scripts/specanchor-finding.sh new --topic="auth-spec-stale" \
  --type=stale-claim --confidence=high --impact=medium --suggested-target=module
```

"把这个 finding 变成 spec 变更建议" / "生成 sediment proposal" → `specanchor_sediment_propose`

```bash
bash scripts/specanchor-sediment.sh propose --finding=F-20260524-001 \
  --target=.specanchor/modules/auth.spec.md --operation=replace \
  --topic="update-session-invariant"
```

review proposal 时：人按 batch review，决定 accept/reject/defer/merge-with-edit；accept 后**人手动 apply 到 spec**——脚本不自动改 spec。

### Context Bundle v1（v0.6 新增）

"给 agent 装配上下文" / "导出 context bundle JSON" → `specanchor_assemble --bundle-schema=context_bundle.v1`

```bash
bash scripts/specanchor-assemble.sh --files=src/auth/session.ts \
  --intent="add Google OAuth" --format=json --bundle-schema=context_bundle.v1
```

输出 layers / freshness / source_type / confidence；默认 `--bundle-schema=assembly.v1`（向后兼容）。

### 跨 session 接手

两类 handoff 物种，不要混：

- **Task-internal packet（单任务换 chat）**："把这个任务交给新 chat" / "导出 handoff packet" / "换个 session 接着做" → `specanchor_handoff`（自动生成 §7.2）
- **Portfolio handoff（跨任务 / release follow-up）**："做一个 deferred follow-up" / "下次会话的入口" / "cross-task roadmap" → `specanchor_task` 选 `handoff` schema

## 推荐流程

### 首次使用

1. "帮我初始化 SpecAnchor" → `specanchor_init`
2. "初始化项目信息" → `specanchor_global`（project-setup 类型）
3. "帮我生成编码规范" → `specanchor_global`（coding-standards 类型）
4. "帮我生成架构约定" → `specanchor_global`（architecture 类型）
5. 触碰模块时："帮我创建 auth 模块的规范" → `specanchor_module`

### 日常开发

1. "创建任务：XX功能" → `specanchor_task`
2. 按 Task Spec 开发
3. "检查 Spec 和代码对齐" → `specanchor_check`
