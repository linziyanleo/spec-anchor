# Handoff Spec 模板

此模板由 Schema 系统自动引用。用于 portfolio / cross-session handoff —— 给下一会话的 entry point。

> **概念区分**：
>
> - **Task-internal handoff packet（§7.2）**：单个 task 在跨 session 切换时由 `specanchor_handoff` 命令自动生成的精炼视图（hot decisions / read next / next step）。属于 sdd-riper-one v2 的一部分。
> - **Portfolio handoff spec（本 schema）**：跨 task / 跨 release 的独立 entry point spec，承载 deferred items 矩阵和 next-session 开场顺序。是独立的 spec 物种。

## 模板

```markdown
---
specanchor:
  level: task
  task_name: "<handoff 名称>"
  author: "<@git_user>"
  created: "<YYYY-MM-DD>"
  updated: "<YYYY-MM-DD>"
  status: "in_progress"               # draft | in_progress | done | archived
  target_session_window: "<下一会话目标 / target release / time window>"
  related_modules:
    - ".specanchor/modules/<module-id>.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "handoff"
  branch: "<branch_name>"
---

# <handoff 名称>

> 本 spec 是给下一会话的 entry point。下次 boot 时会在 Task Specs 中看到这一项；
> 按 §下次会话开场顺序 推进。

## 目标

<这次 handoff 想让下次会话推进到哪里。1-3 句话，不做 deferred items 详细描述（那是 §Items）>

## Context Snapshot

> 给下次会话恢复初始坐标。所有时间敏感事实集中在此段。

- **时间**: <YYYY-MM-DD HH:MM>
- **当前分支 / commit**: <branch>; HEAD = <SHA>
- **未 push commit**:
  ```
  <git log --oneline origin/main..HEAD>
  ```
- **repo state**: <clean / dirty>; <ahead/behind>
- **Module health**: <FRESH/DRIFTED/STALE/OUTDATED 计数>
- **已知风险 / 开放问题**:
  - ...

## Items

> 每一项是下次会话可独立推进的工作单元。

### Item 1: <名称> [unblocked | blocked | time-gated | corpus-gated | recommended]

- **现状**: ...
- **阻塞**: ...（如无阻塞写"无"；不要省略此字段）
- **预估**: <单会话 N 小时 / 跨会话>
- **入口**: <起 task spec 路径 / 起 references/... 草稿 / 直接改 scripts/...>
- **完成判据**: <可观测、可验证的判据>

### Item 2: ...

(每个 Item 同样 5 字段)

## 关键文件指针

> 下次会话需要查的核心文件。可选，按需。

| 用途 | 路径 |
|---|---|
| ... | ... |

## 下次会话开场顺序

> 推荐的 checklist —— 让下次会话第一句话开始就有坐标。

- [ ] 1. 读本 spec（boot 自动 surface），确认 §Context Snapshot 仍准确（git log -3 / status）
- [ ] 2. 决定本会话精力（推荐 Item ?）
- [ ] 3. ...
- [ ] 4. 推进结束后：本 spec 的 §Items 对应项打 ✅ 或更新阻塞描述；如全部 Items 进入下一阶段则归档本 spec

## 完成确认

- 当全部 Items 都进入下一阶段（实现 / 推迟 / 关闭）时，本 spec 归档到 `.specanchor/archive/<year-month>/_cross-module/`
- 在 §Items 内每项标记进入下一阶段的 commit 或新 task spec 链接

## 注意事项 / 已知约束

> 下次会话需要避免的坑、scope 白名单、hook 副作用等。

- ...
```

## Frontmatter 字段说明

| 字段 | 必须 | 说明 |
|------|------|------|
| `level` | 是 | 固定为 `task`（handoff 物理位置仍在 `.specanchor/tasks/`） |
| `task_name` | 是 | handoff 名称（建议格式：`vX.Y deferred items` / `<release> follow-up` / `<topic> roadmap`） |
| `author` | 是 | 创建者 |
| `created` | 是 | 创建日期 |
| `updated` | 否 | 最近一次更新 |
| `status` | 是 | 任务状态（`in_progress` / `done` / `archived`） |
| `target_session_window` | 否 | 下一会话目标 release / 时间窗口 |
| `related_modules` | 否 | 关联 Module Spec 路径列表 |
| `related_global` | 否 | 引用的 Global Spec 路径列表 |
| `writing_protocol` | 否 | 固定为 `"handoff"` |
| `branch` | 否 | 关联 git 分支名 |

## 与其他 schema 的关系

| 场景 | 选哪个 schema |
|---|---|
| 单 task 内跨 session 接力 | `sdd-riper-one` 的 §7.2（由 `specanchor_handoff` 自动生成 packet） |
| Release 后的 deferred follow-up roadmap | **`handoff`（本 schema）** |
| 多 deferred items 集合，需作为下次 boot 的 entry point | **`handoff`（本 schema）** |
| 真实工作 task（有 EXECUTE / 需 Hard Boundaries） | `sdd-riper-one` |
| 简单单文件改动 | `simple` |
| 不产出代码的技术调研 | `research` |

## 与 §7.2 Handoff Packet 的对位

| 维度 | §7.2 Handoff Packet | Handoff Schema（本模板） |
|---|---|---|
| 物理位置 | sdd-riper-one task 内的一个 section | 独立的 spec 文件 |
| 生成方式 | tool（`assemble.sh --mode=handoff`） | author（手写） |
| 内容范围 | 单 task 的 hot 视图 | Cross-task / portfolio roadmap |
| 字段 | task / spec landscape / hot decisions / evidence status / read next / don't read / next step | goal / context_snapshot / items / pointers / next_session_checklist |
| 触发命令 | `specanchor_handoff` | `specanchor_task --schema=handoff` 或自然语言匹配 |
