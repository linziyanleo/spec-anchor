---
specanchor:
  level: task
  task_name: "Agent 循环补全——引入控制平面术语"
  author: "@fanghu"
  assignee: "@fanghu"
  reviewer: "@fanghu"
  created: "2026-04-27"
  status: "review"
  last_change: "Execute 完成，进入 Review"
  related_modules:
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
    - ".specanchor/global/architecture.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: ""
---

# SDD Spec: Agent 循环补全——引入控制平面术语

> Current RIPER Phase: REVIEW

## 0. Open Questions

- [x] Agent Contract 和 SKILL.md 的职责边界？→ Agent Contract 定义确定性循环，SKILL.md 定义入口/路由/策略
- [x] 是否需要改动 specanchor-protocol.md？→ 否
- [x] 是否改动 Assembly Trace 格式？→ 否（Step 3）
- [x] installed skill 与 repo SKILL.md 的关系？→ 本轮只更新 repo 源码；installed copy 需用户手动同步或下次安装时自动更新
- [x] agent entry docs (claude-code.md 等) 怎么处理？→ 各 entry doc 底部加一行指向 agent-contract.md 作为完整循环参考
- [x] 7 步循环中每步对应哪些具体命令/脚本？→ 见 Plan §4.1 注释

## 1. Requirements (Context)

- **Goal**: 将 Agent 完整循环（7 步）写入 `agent-contract.md`，SKILL.md 引入新术语，agent entry docs 指向 contract
- **In-Scope**:
  - `references/agents/agent-contract.md`：重写为 7 步循环 + Must Never Do
  - `SKILL.md`：description + 开头 + Loading Strategy + Workflow Selection 引入术语（仅更新 repo 源码）
  - `references/agents/claude-code.md`：底部加完整循环参考链接
  - `references/agents/cursor.md`：底部加完整循环参考链接
  - `references/agents/codex.md`：底部加完整循环参考链接
  - `references/agents/gemini.md`：底部加完整循环参考链接
- **Out-of-Scope**:
  - Assembly Trace 格式变更（Step 3）
  - specanchor-protocol.md 变更
  - installed skill 同步（用户自行操作）

## 1.1 Context Sources

- Requirement Source: `mydocs/idea.md` 附录 D.4 + D.2
- Design Refs: Step 1 Task Spec (已完成)
- Extra Context: Codex Review 4 条反馈

## 1.5 Codemap Used

- Key Index:
  - `references/agents/agent-contract.md` — 当前 30 行，3 段式
  - `SKILL.md` — 96 行，6 个 section
  - `references/agents/claude-code.md` — 48 行
  - `references/agents/cursor.md` — 33 行
  - `references/agents/codex.md` / `gemini.md` — 结构类似

## 2. Research Findings

### 2.1 7 步循环 ↔ 可执行检查映射

每一步必须映射到具体的脚本或动作，不能只是概念名：

| 步骤 | 概念名 | 具体动作 |
|------|--------|---------|
| 1. Enter Spec Landscape | boot | `specanchor-boot.sh` → 输出 Assembly Trace |
| 2. Resolve Anchors | assemble | `specanchor-assemble.sh --files=... --intent=...` → 输出 `files_to_read` |
| 3. Workflow Selection | decide | 根据任务范围选 `⚡ lightweight` 或 `📋 standard` |
| 4. Schema Gate | gate | 如 standard → 创建 Task Spec → 按 schema 走门禁 |
| 5. Execute | implement | 在 Global + Module Spec 约束下编码；运行目标测试 |
| 6. Alignment Check | check | 按条件选择：① Spec 文件被修改 → `specanchor-doctor.sh` + `specanchor-validate.sh`（格式/frontmatter 合规）；② 代码文件被修改 → `specanchor-check.sh task <spec-file>`（本次 Task Spec 涉及的模块是否对齐）；③ 始终：报告 anchors used / files changed / remaining drift |
| 7. Spec Sediment | sediment | 评估是否需要更新 Module/Global Spec；记录在 Review Verdict 的 Sediment bullets |

### 2.2 Agent Entry Docs 策略

当前 `claude-code.md` / `cursor.md` 等文件各自描述了简化版的 boot → assemble → read → edit 流程。如果在每个文件中重复完整 7 步循环，会产生多处维护点。

策略：每个 entry doc 保持现有的 quickstart 流程不变，底部加一行：

```markdown
For the full agent loop including Alignment Check and Spec Sediment, see `agent-contract.md`.
```

## 3. Innovate

### Skip
- Skipped: true
- Reason: 变更方向明确，不需多方案比较

## 4. Plan (Contract)

### 4.1 File Changes

1. **`references/agents/agent-contract.md`**：重写为 7 步确定性循环
   - §Startup → Enter Spec Landscape：`specanchor-boot.sh` + Assembly Trace
   - §Resolve → Resolve Anchors：`specanchor-assemble.sh` + read `files_to_read`
   - §Workflow → Workflow Selection：⚡/📋 判断
   - §Gate → Schema Gate：创建 Task Spec + 等 gate 通过
   - §Execute → Execute：在 Spec 约束下实现 + 运行测试
   - §Alignment → Alignment Check：`specanchor-check.sh` / `doctor.sh` / `validate.sh` + 报告
   - §Sediment → Spec Sediment：评估 Module/Global Spec 是否需更新
   - §Must Never Do：保留现有条目

2. **`SKILL.md`**（4 处微调）：
   - L3 description：追加"规格控制平面"
   - L8 开头段落：追加一句控制平面定位
   - L47 Loading Strategy 段首：加 Spec Landscape 概念句
   - L77 Workflow Selection 段尾：引用 Schema Gate 术语 + 提到 Alignment Check / Sediment 在 Agent Contract 中定义

3. **`references/agents/claude-code.md`**：末尾加 agent-contract.md 参考行
4. **`references/agents/cursor.md`**：末尾加 agent-contract.md 参考行
5. **`references/agents/codex.md`**：末尾加 agent-contract.md 参考行
6. **`references/agents/gemini.md`**：末尾加 agent-contract.md 参考行

### 4.2 Signatures

N/A

### 4.3 Implementation Checklist

- [x] 1. 重写 `references/agents/agent-contract.md`（7 步 + Must Never Do）
- [x] 2. 更新 `SKILL.md` description 字段
- [x] 3. 更新 `SKILL.md` 开头段落
- [x] 4. 更新 `SKILL.md` Loading Strategy
- [x] 5. 更新 `SKILL.md` Workflow Selection
- [x] 6. 4 个 agent entry docs 底部加参考行
- [x] 7. 自检术语一致性

## 5. Execute Log

- [x] Step 1: `agent-contract.md` 重写为 7 步确定性循环（Enter Spec Landscape → Resolve Anchors → Workflow Selection → Schema Gate → Execute → Alignment Check → Spec Sediment）+ Must Never Do 新增第 5 条
- [x] Step 2: `SKILL.md` L3 description 追加"规格控制平面"和 4 个术语
- [x] Step 3: `SKILL.md` L8 开头段落追加控制平面定位 + agent-contract.md 引用
- [x] Step 4: `SKILL.md` L49 Loading Strategy 段首加 Spec Landscape 概念句
- [x] Step 5: `SKILL.md` L83 Workflow Selection 加 Schema Gate 术语引用 + L85 加 Alignment Check / Sediment 跳转
- [x] Step 6: claude-code.md / cursor.md / codex.md / gemini.md 各加 "Full Agent Loop" section
- [x] Step 7: 自检确认 4 个术语在所有变更文件中一致

## 6. Review Verdict

- Spec coverage: PASS — 所有计划文件均已变更
- Behavior check: PASS — 纯文档变更，无运行时影响
- Regression risk: Low — 不改脚本或 Schema 结构
- Module Spec 需更新: Yes — `references.spec.md` 应记录"agent entry docs 必须指向 agent-contract.md 作为完整循环的 single source of truth"规则（Follow-up 处理）
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: No
  - 新发现的项目规则: agent entry docs (claude-code.md / cursor.md 等) 应始终指向 agent-contract.md 作为完整循环的 single source of truth，不要在各 entry doc 中重复完整循环
  - 值得记录的反模式: 在 SKILL.md description 字段中堆叠过多术语可能降低可读性；当前长度可接受但不宜再加
- Follow-ups:
  - Step 3: Assembly Trace 增加 Landscape Readiness 指标
  - installed skill 同步（用户自行操作）

## 7. Plan-Execution Diff

- 无偏差。所有 7 步 Checklist 按计划完成。
