---
specanchor:
  level: task
  task_name: "Session 上下文膨胀控制（F-20260530-001）：契约优先、分阶段"
  author: "@方壶"
  created: "2026-05-31"
  status: "in_progress"
  writing_protocol: "simple"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
---

> **Intent**：控制同一 agent session 内 boot/assemble 多轮全量重印导致的上下文线性增长。契约优先——先固化加载契约（Sediment Proposal + 文档）再改脚本；保留 fail-fast、每次调用 bounded 输出、scripts.spec.md §4「无持久化状态」硬契约。

# Session 上下文膨胀控制（F-20260530-001）

## 来源

- Finding **F-20260530-001**（session-context-bloat）。
- 双 agent 评审 3 轮收敛 `CONVERGED_APPROVE`：`agent_review_20260530-234214-pane-p_1-710b/final.md`（= v3）。
- Sediment Proposal：**SP-20260531-001**（target scripts.spec.md §2，operation append，待人 review）。

## 子问题与硬约束

4 个独立子问题：P1 重复全量重印 / P2 脚本无跨 call 状态 / P3 skill 双注册 / P4 install 滞后。

硬约束：①只改加载契约 + 协议层，不动 Global/Module spec 正文语义；②保 fail-fast + 每次调用 bounded；③scripts.spec.md §4「无持久化状态」→ 禁止脚本自管缓存；④boot json/summary/full 三态向后兼容。

## 分阶段实施 + 状态

| Phase | 内容 | 风险 | 状态 |
|---|---|---|---|
| **0** | 核实 P4 install 滞后 + P3 双注册来源（只读） | 无 | ✅ done（见下） |
| **1a** | 活契约文档入口改为「boot once/preflight + delta trace」（SKILL.md / agent docs / context-utilities.md / assembly-trace.md）；产出 SP | 低 | 🔄 in-progress |
| **1b** | boot-install 注入模板携带新契约文案（脚本行为变更，需 focused 测试） | 中 | ⏸ pending（checkpoint 后） |
| **2** | boot `--tasks=open\|all\|none`（终态排除式，保 draft；仅 inline-brief 默认 open）+ assemble `--budget` 收紧 + scripts.spec.md §3 补 inline-brief | 中 | ⏸ pending（checkpoint 后） |
| **3** | opt-in stateless delta（agent 传 trace/指纹，脚本纯函数） | 中 | ⛔ deferred（实测不足才上） |
| **D** | P3/P4 安装卫生 | — | ✅ 判定为**本机操作，零 repo 改动**（见下） |

## Phase 0 核实结论（2026-05-31）

- **P4 = install 滞后（确认）**：`~/.claude` 与 `~/.codex` 的 spec-anchor 均 symlink → `~/.skills-manager/skills/spec-anchor`（真实拷贝，5/27，hook 无 inline-brief、boot 不支持 inline-brief）。另有 plugin 安装 `spec-anchor@spec-anchor`（cache 0.7.0）。repo HEAD 已含 inline-brief（commit 9477706）。→ 修复 = 重新 sync 安装，**非 repo 代码**。
- **P3 = 双安装机制（确认）**：`spec-anchor`（裸）来自 skills-manager symlink；`spec-anchor:spec-anchor` 来自 plugin marketplace（`.claude-plugin/` + `skills/spec-anchor/SKILL.md` wrapper delegate 到 `../../SKILL.md`）。repo 打包**正确**，wrapper 是 plugin 必需入口。**原 D1「删 wrapper」作废**（会打断 plugin 发现）。→ 修复 = 本机只保留一种安装机制，**非 repo 代码**。

## File Changes（计划）

见 scope。其中 Phase 1a 为纯文档；Phase 1b/2 为脚本行为变更，须过 §F-5 回归门禁。

## Verification（门禁）

- Phase 1a：`specanchor-validate.sh --path <SP>`；`specanchor-hygiene.sh` 文档无断链；人工核对活契约文案一致（R4）。
- Phase 1b：临时项目对 claude/codex/gemini/cursor 跑 `specanchor-boot-install.sh`，断言注入块含新契约 + 幂等原位替换 + `--remove` 清理；`bash tests/run.sh`。
- Phase 2/3（脚本行为，来自 coding-standards.spec.md:46/50 强制）：`bash tests/run.sh` + `SPECANCHOR_RUN_BATS=1 bash tests/run_all.sh`；新增 `--tasks`（fixture 覆盖 draft/review/done/unknown）/ json 兼容 / budget focused 测试；构造 🟡/🔴 模块验 Landscape Readiness 不退化；`specanchor-check.sh module scripts.spec.md` FRESH。

## Open Questions

- R4：活契约文案分散在 5+ 文件需保持一致（缓解：boot-install 注入块为单一来源）。
- OQ2：D2 install sync 是否在 repo 职责内？→ Phase 0 已判定为本机操作。
- OQ3：Phase 3 入口选 boot `--format=delta` 还是 assemble `--already-loaded=`，二选一。
