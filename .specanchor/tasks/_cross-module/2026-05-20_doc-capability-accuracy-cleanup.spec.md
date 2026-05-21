---
specanchor:
  level: task
  task_name: "顶层文档能力准确性清理"
  author: "@maintainer"
  created: "2026-05-20"
  status: "done"
  last_change: "全部完成并提交；关闭 task"
  related_modules:
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  writing_protocol: "sdd-riper-one"
  branch: "fix/doc-capability-accuracy"
---

# SDD Spec: 顶层文档能力准确性清理

> Current RIPER Phase: EXECUTE

## 0. Open Questions
- [x] README_ZH.md 是否同步修改？→ 是。与 README.md 同轴同 commit
- [x] FLOWCHART.md 是直接修还是标注 stale 等 v0.6 重画？→ 局部修正：`module-index.md` → `spec-index.md`，`infer` 自动执行 → agent-guided protocol。不整图重画
- [x] codemap 是否进 SKILL 主命令表？→ 否。refs.spec 登记为 draft/deferred，SKILL 主表不加，避免把未实现协议包装成可路由能力

## 1. Requirements (Context)
- **Goal**: 消除 README / WHY / SKILL.md / FLOWCHART.md / references.spec.md 中与项目实际能力不符的描述。14 项偏差，来自两轮独立审查（人工审查 + Codex spec-anchor skill 只读审查）
- **In-Scope**:
  - Axis-A: P1 能力过度承诺修正（infer 自动化、check 签名级比对）
  - Axis-B: P2 事实性错误修正（三类 Context 位置、mydocs 虚构、版本号、加载措辞）
  - Axis-C: P2 SKILL.md 路由盲区补全（gemini / goal-hook / concepts / skills）+ Reference Index 加 draft protocols 提示（codemap 不进主命令表）
  - Axis-D: references.spec.md 接口表同步（codemap 标 draft/deferred / handoff / 计数）
  - Axis-E: P3 版本与图表局部修正（badge alt text / FLOWCHART module-index→spec-index + infer→agent protocol）
- **Out-of-Scope**:
  - 实现 specanchor-infer.sh 脚本（那是功能扩展不是文档修正）
  - 实现 AST/签名级别的 check 能力
  - README 整体重写或信息架构重构
  - control plane vs workflow-as-data 的深度区分文案（WHY.md / architecture.spec.md 级别的定位重构，留给独立 task）

## 1.1 Context Sources
- Requirement Source: 本 session 两轮审查（人工 + Codex spec-anchor skill）
- Chat/Business Refs: Codex findings P1×2 + P2×4 + P3×2；人工审查 11 项（重叠 6 项 + 独有 5 项）
- Extra Context: 上一 session Codex review 中关于 control plane vs workflow-as-data 的 argue 结论

## 1.2 Hard Boundaries
- 不改变项目核心定位描述（"Harness Context Control plane" 保留）
- 不删除功能条目，只修正描述精度（infer 保留但改为 "agent-guided protocol"）。例外：init 产物树中虚构的 `mydocs/evidence` / `mydocs/handoff` 可删除（不存在的目录不是功能条目）
- README_ZH.md 必须与 README.md 同步
- 不破坏 doctor / validate / tests

## 1.3 Allowed Freedom
- 措辞选择（只要准确即可）
- mydocs/ 段落的措辞选择（init 产物树删虚构子目录后的表述方式）
- FLOWCHART.md 局部修正的具体措辞

## 2. Research Findings

### 来源与方法
- 人工审查：逐文件读取 README / WHY / SKILL.md，交叉对比 references/commands/、references/schemas/、scripts/、references/agents/、references/integrations/、references/concepts/、references/skills/ 的实际内容
- Codex 审查：使用 spec-anchor skill 只读模式，Assembly Trace Global summary 加载，逐行核对代码实现

### 14 项偏差汇总

| # | 严重度 | 文件 | 偏差 | 来源 |
|---|--------|------|------|------|
| 1 | P1 | README L74,103 | `specanchor_infer` 写成已产品化自动能力，实际是纯 agent 协议 | Codex |
| 2 | P1 | README L92-104,129 | check 示例展示签名级源码比对 + "runs continuously"，实际是 command-triggered file-change/freshness/coverage | Codex |
| 3 | P2 | README L54 | "All three live inside Task Spec" 不准确，Spec Context 分布三层 | Codex |
| 4 | P2 | README L184-187 | mydocs/evidence/ 和 mydocs/handoff/ 不存在，init 不创建 | 两者 |
| 5 | P2 | README L40,153,161 | "loads itself" / "No shell commands" 混淆用户体验与技术实现 | Codex |
| 6 | P2 | README L42,44 | control plane 与 SDD toolkit 并列易混淆 | Codex |
| 7 | P1→P3 | README L20 | badge alt text 写 "Version 0.4.0-beta.2" 与实际 0.5.0-beta.1 不一致 | 人工 |
| 8 | P3 | WHY L59 | "v0.5.0-beta.2+" 版本号需拆语义：task-internal packet 标 beta.1；two-species framing / portfolio handoff schema 标 current main | 两者 |
| 9 | P2 | SKILL L66-78 | 命令表缺 specanchor_codemap（deferred/time-gated）→ 不进 SKILL 主表，仅 refs.spec 登记 draft/deferred | 人工 |
| 10 | P2 | SKILL L96 | Reference Index 缺 gemini.md | 人工 |
| 11 | P2 | SKILL L98-99 | Reference Index 缺 goal-hook.md | 人工 |
| 12 | P2 | SKILL | Reference Index 缺 concepts/ 和 skills/ | 人工 |
| 13 | P2 | refs.spec §3.1/§3.2/§7 | 命令表缺 codemap、Schema 表缺 handoff、文件计数错误 | 人工 |
| 14 | P3 | FLOWCHART | module-index.md 画为产出层（已 deprecated）+ infer 画为自动执行 | Codex |

### 判定说明
- #5 (加载措辞)：README 面向用户，"no shell commands" 对用户准确。改为 "natural language interface — agent invokes scripts internally" 同时保持用户友好和技术诚实
- #6 (control plane vs toolkit)：不在本 task 做深度重构，只加一句澄清 "ships sdd-riper-one as bundled default"
- #8 (handoff 版本)：beta.1 release note 只证明 task-internal handoff packet / specanchor_handoff。WHY 那段讲的是 "两类 handoff" 含 portfolio handoff schema，后者是 beta.1 之后在 main 上加的。不能一刀切改 beta.1+，需拆开标注
- #9 (codemap 路由)：codemap.md 是 Draft/time-gated 到 2026-06-15+。加进 SKILL 主命令表会把"未实现协议"包装成可路由能力——与本 task 修 infer 过度承诺的目标自相矛盾。refs.spec 登记 draft/deferred 即可

## 4. Plan (Contract)

### 4.1 File Changes

| File | Change |
|---|---|
| `README.md` | Axis-A: 改 infer/check 描述精度；Axis-B: 改 Context 位置描述 + 删 mydocs 虚构 + 改加载措辞 + 加 sdd-riper-one 澄清 + 改 badge alt text |
| `README_ZH.md` | 同 README.md 的中文版同步 |
| `WHY.md` | Axis-B: handoff 版本号拆语义（task-internal packet = beta.1；two-species framing = current main） |
| `WHY_ZH.md` | 同 WHY.md 同步 |
| `SKILL.md` | Axis-C: Reference Index 加 gemini / goal-hook / concepts / skills + draft protocols 提示（主命令表不加 codemap） |
| `FLOWCHART.md` | Axis-E: module-index.md → spec-index.md + infer 自动执行 → agent-guided protocol（局部修正，不整图重画） |
| `.specanchor/modules/references.spec.md` | Axis-D: §3.1 加 codemap (draft/deferred)、§3.2 加 handoff、§7 修计数 |

### 4.3 Implementation Checklist

- [ ] Step 1: Axis-A — README.md infer/check 描述精度修正
- [ ] Step 2: Axis-B — README.md 事实性错误修正（Context 位置 + mydocs + 加载措辞 + toolkit 澄清 + badge）
- [ ] Step 3: Axis-B — WHY.md handoff 版本号拆语义
- [ ] Step 4: Axis-C — SKILL.md Reference Index 补全（gemini / goal-hook / concepts / skills / draft protocols 提示；主命令表不动）
- [ ] Step 5: Axis-D — references.spec.md 接口表同步（codemap 标 draft/deferred）
- [ ] Step 6: Axis-E — FLOWCHART.md 局部修正（module-index → spec-index + infer → agent protocol）
- [ ] Step 7: README_ZH.md + WHY_ZH.md 中文版同步
- [ ] Step 8: 验证 — doctor --strict + validate --strict + tests/run.sh
- [ ] Step 9: bump references module last_synced_sha（若 references/ 有变更）
- [x] Step 10: commit（按轴拆分 or 单 commit，视变更量定）

### 4.7 Checkpoints — Contract

#### CP-1 Axis-A 完成（P1 修正）
- Output: README 中 infer/check 相关段落的 diff
- Awaits: pass / clarify / redirect

#### CP-2 全部英文文件完成
- Output: diff summary + doctor/validate 结果
- Awaits: pass / clarify / add-spec

#### CP-3 中文版同步 + 全部验证
- Output: tests/run.sh 结果 + git diff --stat
- Awaits: pass / redirect

## 5. Execute Log
- [x] Step 1: Axis-A — README.md infer → "agent drafts via protocol"; check → freshness/file-change/coverage 级
- [x] Step 2: Axis-B — README.md badge alt text 修正 + "loads itself" → "agents load on boot" + "SDD toolkit" → "SDD workflow preset" + Context 位置修正 + mydocs 虚构子目录删除 + "No shell commands" → "agent handles internally"
- [x] Step 3: Axis-B — WHY.md "v0.5.0-beta.2+" → "v0.5.0+" + handoff 版本拆语义（beta.1 = task-internal; main = two-species）
- [x] Step 4: Axis-C — SKILL.md Reference Index 加 gemini / goal-hook / concepts / skills + draft protocols 提示
- [x] Step 5: Axis-D — references.spec.md §3.1 加 codemap (draft/deferred) + §3.2 加 handoff + §7 修计数 12/7
- [x] Step 6: Axis-E — FLOWCHART.md "自动执行 specanchor_infer" → "agent 执行协议" + module-index.md → spec-index.md
- [x] Step 7: README_ZH.md + WHY_ZH.md 全部同步（badge/loads/toolkit/Context/infer/check/mydocs/对比表/shell commands/handoff version）
- [x] Step 8: 验证 — doctor ok + validate ok (36) + tests 32/32 + 负向 grep 0 匹配（golden fixture 行数同步更新 340→342）
- [x] Step 9: 不需要 — references/ 目录无新 commit，last_synced_sha 保持 b55f56c
- [x] Step 10: commit — 单 commit `docs(spec): correct 14 capability overclaims across README/WHY/SKILL/FLOWCHART`

## 5.2 Checkpoint Decisions Log

### Recent (active, hot)

- **plan-review-01** (2026-05-20, PLAN) [redirect, active] @§0+§1+§4
  - rule: "codemap 不进 SKILL 主命令表；WHY handoff 版本拆语义不一刀切；FLOWCHART 局部修正；mydocs 删虚构子目录但不违反不删功能条目原则；加负向 grep 验收；风险调 Medium"
  - by: human

### Earlier (audit only)

- (none)

## 6. Review Verdict
- Spec coverage: pending
- Behavior check: pending
- Regression risk: Medium（SKILL.md 是 agent 运行时入口，改 Reference Index 影响 agent 发现路径；README 是公开定位面）
- Module Spec 需更新: Yes — references.spec.md Axis-D 是变更内容之一
- Follow-ups: pending

## 6.2 Evidence Ledger

### Commands Run

| Command | Status | Output ref |
|---|---|---|
| `bash scripts/specanchor-doctor.sh --strict` | ✅ pass | doctor ok |
| `bash scripts/specanchor-validate.sh --strict` | ✅ pass | validate ok (36 files) |
| `bash tests/run.sh` | ✅ pass | 32 passed, 0 failed（golden fixture estimated_lines 340→342 同步更新后通过） |
| `rg -n "runs continuously\|signature ≠ code\|auto-filled\|No shell commands\|All three live inside\|v0.5.0-beta.2" README.md README_ZH.md WHY.md WHY_ZH.md SKILL.md` | ✅ pass | 0 matches — 旧 overclaim 全部清零 |

### Acceptance Criteria Mapping

| Criterion | Evidence | Status |
|---|---|---|
| P1 infer 描述改为 agent-guided protocol | README diff ✓ | ✅ pass |
| P1 check 描述改为 command-triggered alignment/freshness/coverage | README diff ✓ | ✅ pass |
| P2 Context 位置描述准确 | README diff ✓ | ✅ pass |
| P2 mydocs 虚构子目录删除 | README diff ✓ | ✅ pass |
| SKILL 命令表不含 codemap（deferred 协议不进主路由） | SKILL diff ✓ | ✅ pass |
| SKILL Reference Index 含 gemini / goal-hook / concepts / skills + draft protocols 提示 | SKILL diff ✓ | ✅ pass |
| references.spec.md 接口表含 codemap (draft/deferred) + handoff + 计数正确 | refs.spec diff ✓ | ✅ pass |
| README_ZH 与 README 同步 | diff 比对 ✓ | ✅ pass |
| doctor/validate/tests 全绿 | 命令输出 ✓ | ✅ pass |
| 负向 grep 旧 overclaim 清零或已降级 | rg 输出 0 matches | ✅ pass |

### Unverified Risks

- README_ZH.md 可能有独立于 README.md 的额外偏差（未在本轮审查中覆盖）

### Manual / External Checks Needed

- 发布前应人眼通读一遍 README 英文版完整流畅性

### Rollback / Follow-up Handle

- 纯文档变更，revert commit 即可

## 6.3 Capability Drift Check

- [ ] 本 spec 中描述的「现状 / 缺口 / 已知约束」是否仍然准确？
- [ ] 是否有「X 不感知 Y」/「需要 Step A/B/C」/「audit finding」类陈述已被后续代码超越？

## 7. Plan-Execution Diff
- Any deviation from plan: pending

## 7.2 Handoff Packet

> auto-generated by `specanchor-assemble.sh --mode=handoff`
> 不要手写。重新生成请运行 `specanchor_handoff`。
