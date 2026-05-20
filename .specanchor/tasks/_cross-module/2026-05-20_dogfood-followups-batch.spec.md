---
specanchor:
  level: task
  task_name: "Dogfood Followups Batch (F3-F10)"
  author: "@方壶"
  created: "2026-05-20"
  status: "draft"
  last_change: "起 spec：聚合 dogfood-notes-2026-05-19 §F3-F10 八个 finding"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
  writing_protocol: "sdd-riper-one"
  branch: "feat/dogfood-followups-batch"
---

# SDD Spec: Dogfood Followups Batch (F3-F10)

> Current RIPER Phase: PLAN

## 0. Open Questions

- [x] 八个 finding 拆 8 个 spec 还是聚一个？— 聚一个：避免任务碎片化；按修复轴线分四组实施，每组独立 commit。
- [x] 是否包含 F2 (Capability Drift) 与 F1 (Active Tasks 段)？— 否，已分别落在 [[2026-05-19_boot-active-tasks-and-capability-drift]] 与 sdd-riper-one schema §6.3。
- [ ] F6 (assemble intent 解析) 涉及 codemap 推荐逻辑改造，是否单独抽出 task？— 在 Research 阶段评估改动深度后定。
- [ ] F9 (specanchor-check.sh task 输出引导) 是否依赖 §4.1 File Changes 模板稳定？— 是。需先确认 sdd-riper-one template.md §4.1 表头不再变化。

## 1. Requirements (Context)

- **Goal**: 把 dogfood-notes-2026-05-19 §F3-§F10 八个 finding 推进至关闭，分四组按修复轴线实施。
- **In-Scope** (按轴线分组):
  - **Axis-A 输出一致性**：F3 (status 缺 Available Commands)、F4 (assemble trace 路径前缀)、F5 (Module 段 full/summary 语义)
  - **Axis-B 信息密度**：F8 (Available Schemas 描述过长)、F10 (doctor 默认 mode 静默)
  - **Axis-C Next-Action 推断**：F7 (boot 末尾 Next Suggested Action)、F9 (check.sh 缺 File Changes 引导)
  - **Axis-D Intent 解析精度**：F6 (assemble intent 关键词反向过滤 codemap)
- **Out-of-Scope**:
  - 任何 schema 协议层改造
  - 新增脚本 / 命令
  - F6 若发现需要重写 resolver 优先级模型 → 转独立 task

## 1.1 Context Sources

- Requirement Source: `mydocs/reports/dogfood-notes-2026-05-19.md` §F3-§F10
- Related Spec: `.specanchor/tasks/_cross-module/2026-05-19_boot-active-tasks-and-capability-drift.spec.md` (姐妹 task，先行处理 F1+F2)
- Related Protocol: `references/integrations/superpowers.md` (一致性提升对 prelude skill 落地至关键)

## 1.2 Hard Boundaries

- 不破坏现有 JSON schema 字段（仅追加 / 仅修改 description 类）
- 不引入新依赖
- 每轴线独立 commit，便于按需 revert
- F6 不许"猜测"用户意图——只过滤明显不相关的 codemap，不主动新增

## 1.3 Allowed Freedom

- 输出格式微调（颜色 / 缩进 / 分隔符）自决
- Next Suggested Action 文案表述自决（贴近 boot 已有风格）
- F4/F5 选择"全部带前缀"还是"全部不带前缀"自决（一致即可）

## 2. Research Findings

(待 Research 阶段填充)

预期重点：
- `scripts/specanchor-status.sh` 是否 source `specanchor-boot.sh` 的 emit_* 函数？若已 source，F3 可直接复用。
- `scripts/specanchor-assemble.sh` 中 trace 输出函数 (F4/F5 共同改造点)
- `scripts/specanchor-resolve.sh:681+` codemap 推荐逻辑 (F6)
- `scripts/specanchor-check.sh` task 模式输出函数 (F9)
- `scripts/specanchor-doctor.sh` summary 输出 (F10)

## 4. Plan (Contract)

### 4.1 File Changes

| Axis | File | Change |
|---|---|---|
| A (F3) | `scripts/specanchor-status.sh` | 补 Available Commands 段（复用 boot 函数）或 emit 一行 "for commands see boot" |
| A (F4) | `scripts/specanchor-assemble.sh` | trace 路径前缀统一为 `.specanchor/global/<file>`（与 boot 对齐） |
| A (F5) | `scripts/specanchor-assemble.sh` | Module 段 mixed 标注：`Module: mixed -> a.spec.md [summary], b.spec.md [full]` |
| B (F8) | `scripts/specanchor-boot.sh` | Available Schemas 在 summary 模式仅显示 `name [philosophy]: <一句话>`；full 模式保持完整 |
| B (F10) | `scripts/specanchor-doctor.sh` | 默认 mode 至少打印 `scanned: N, ok: N, issues: M`（无论是否有 issue） |
| C (F7) | `scripts/specanchor-boot.sh` | 末尾根据 Active Tasks + Landscape Readiness 输出 `Next: ...` 一行（仅 summary/full 模式） |
| C (F9) | `scripts/specanchor-check.sh` | warning 后追加引导 `Tip: 在 §4.1 添加 \| path \| change \| 表格行；模板见 references/schemas/sdd-riper-one/template.md` |
| D (F6) | `scripts/specanchor-resolve.sh` | intent 关键词与 codemap 文件名相关性低于阈值时不主动推荐 codemap |
| - | `.specanchor/modules/scripts.spec.md` | bump `last_synced_sha`（按 axis 分次或末次统一） |

### 4.3 Implementation Checklist

- [ ] Axis-A Step 1: F3 status 一致化
- [ ] Axis-A Step 2: F4 assemble 路径前缀
- [ ] Axis-A Step 3: F5 Module 段 mixed 标注
- [ ] Axis-A Step 4: 跑 boot/status/assemble 验证输出对齐 → commit "feat(scripts): align boot/status/assemble output (F3 F4 F5)"
- [ ] Axis-B Step 5: F8 schema 描述精简
- [ ] Axis-B Step 6: F10 doctor 默认 mode 计数输出
- [ ] Axis-B Step 7: 验证 → commit "feat(scripts): trim noise & add scan counters (F8 F10)"
- [ ] Axis-C Step 8: F7 boot Next Suggested Action
- [ ] Axis-C Step 9: F9 check.sh 引导文案
- [ ] Axis-C Step 10: 验证 → commit "feat(scripts): next-action hints (F7 F9)"
- [ ] Axis-D Step 11: F6 intent-codemap 相关性过滤（先 Research 评估深度）
- [ ] Axis-D Step 12: 验证 → commit "feat(scripts): intent-aware codemap filter (F6)" 或转独立 task
- [ ] Final: bump scripts.spec.md last_synced_sha
- [ ] Final: 跑 doctor/validate --strict 全绿

### 4.7 Checkpoints — Contract

#### CP-A 输出一致性轴完成
- Output: boot/status/assemble 三命令输出对照表（路径前缀 / Module 段标注 / Available Commands 是否同时可见）
- Awaits: pass / clarify / redirect

#### CP-B 信息密度轴完成
- Output: 精简前后字符数对比；doctor 默认 mode 输出样本
- Awaits: pass

#### CP-C Next-Action 推断完成
- Output: 在 3 种 Landscape 状态下（0 active / 1 in_progress / >1 mixed phase）的 Next 文案样本
- Awaits: pass / clarify

#### CP-D Intent 过滤评估
- Output: Research 报告——改动深度估计 + 是否分拆建议
- Awaits: pass / split-to-new-task

## 5. Execute Log

- [ ] (待 Execute 阶段填充)

## 5.2 Checkpoint Decisions Log

### Recent (active, hot)

- **cp-00** (2026-05-20, PLAN) [decision, active] @§1.2
  - rule: "F2 (Capability Drift) 与 F1 (Active Tasks) 已分别独立处理，本 batch 仅含 F3-F10"
  - by: agent

### Earlier (audit only)

- (none)

## 6. Review Verdict

- Spec coverage: (pending)
- Behavior check: (pending)
- Regression risk: Medium (跨 5 个脚本，输出格式变化可能影响外部消费者)
- Module Spec 需更新: Yes — scripts.spec.md `last_synced_sha`
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: No
  - 新发现的项目规则: (待执行后填)
  - 值得记录的反模式: (待执行后填)
- Follow-ups: (按 axis 完成情况决定)

## 6.2 Evidence Ledger

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-boot.sh --format=summary` | pending | (待跑) |
| `bash scripts/specanchor-status.sh` | pending | (待跑) |
| `bash scripts/specanchor-assemble.sh --files=...` | pending | (待跑) |
| `bash scripts/specanchor-doctor.sh` | pending | (待跑) |
| `bash scripts/specanchor-check.sh task <spec>` | pending | (待跑) |
| `bash scripts/specanchor-validate.sh --strict` | pending | (待跑) |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| F3: status 输出 Available Commands 段（或显式指引） | status 输出 | pending |
| F4: boot 与 assemble 的 Global file 路径前缀一致 | 输出对照 | pending |
| F5: assemble Module 段在 mixed 时分别标 [summary]/[full] | assemble 输出 | pending |
| F6: assemble intent 不再推荐与意图无关的 codemap | dogfood 重跑场景 | pending |
| F7: boot 末尾出现 Next Suggested Action 一行 | boot 输出 | pending |
| F8: boot Available Schemas summary 模式每行 ≤120 字符 | boot 输出 | pending |
| F9: check.sh task warning 含「在 §4.1 添加」引导 | check.sh 输出 | pending |
| F10: doctor 默认 mode 含 `scanned/ok/issues` 计数 | doctor 输出 | pending |

### Unverified Risks

- 外部下游若直接 grep boot 输出文本，路径前缀变化会破坏其解析
- Next Suggested Action 误判会引导错误方向（如把 review 状态的 task 当成"该恢复执行"）

### Manual / External Checks Needed

- 在第三方 consumer project 实测各命令输出（与 F1 follow-up 合并验证）

### Rollback / Follow-up Handle

- 按 axis commit 拆分，可逐个 revert
- 若 Axis-D 评估超预算，转新 task `intent-aware-codemap-recommendation`

## 6.3 Capability Drift Check

> 模板由 sdd-riper-one schema v3 起强制要求；本 task 完成 Review 时回填。

- [ ] 本 spec 中描述的「现状/缺口/已知约束」是否仍然准确？
- [ ] 是否有 audit finding 已被后续代码超越？

## 7.2 Handoff Packet

> 待 specanchor_handoff 生成
