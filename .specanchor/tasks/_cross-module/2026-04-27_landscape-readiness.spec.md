---
specanchor:
  level: task
  task_name: "Assembly Trace 增加 Landscape Readiness"
  author: "@fanghu"
  assignee: "@fanghu"
  reviewer: "@fanghu"
  created: "2026-04-27"
  status: "review"
  last_change: "Execute 完成，进入 Review"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/coding-standards.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: ""
---

# SDD Spec: Assembly Trace 增加 Landscape Readiness

> Current RIPER Phase: REVIEW

## 0. Open Questions

- [x] Landscape Readiness 是纯信息性还是阻断性？→ **信息性**，不 exit 1。boot 定位为"报告"，阻断行为由 Agent Contract 层面约定。
- [x] assemble.sh 的 Assembly Trace 是否也要加 Readiness？→ **否**，assemble 的粒度是 files_to_read，不是 landscape 级别。Readiness 仅 boot 产出。
- [x] Readiness 判定阈值怎么定？→ **硬编码**（DRIFTED/STALE → ATTENTION，OUTDATED → NOT_READY），后续可扩展 anchor.yaml 可配。
- [x] JSON 输出中新增字段的命名？→ `landscape_readiness` 对象，置于 `assembly_trace` 内部。
- [x] parasitic mode 怎么处理？→ 输出 `N/A`，不套 full-mode 的三维度判定。

## 1. Requirements (Context)

- **Goal**: 在 boot 输出的 Assembly Trace 中增加 Landscape Readiness 汇总行，让 Agent 一眼判断 Spec 地形的完备度和新鲜度，决定是否需要先修补 Spec 再动手编码
- **In-Scope**:
  - `scripts/specanchor-boot.sh`：summary/full/json 三种格式增加 Landscape Readiness 行
  - `references/assembly-trace.md`：Assembly Trace 格式定义增加 Readiness 段
  - `references/agents/agent-contract.md` §1：Enter Spec Landscape 步骤中引用 Readiness
- **Out-of-Scope**:
  - `specanchor-assemble.sh` 的 Assembly Trace（assemble 的粒度是 files_to_read，不是 landscape 级别）
  - anchor.yaml schema 变更（阈值硬编码，后续 anchor.yaml 扩展可配）
  - 新增 CLI 参数
  - spec-index.sh 的 health 计算逻辑（已有，直接复用）

## 1.1 Context Sources

- Requirement Source: `mydocs/idea.md` 附录 D.6 Step 3
- Design Refs: Step 2 Task Spec Review Verdict Follow-ups
- Existing Implementation: `specanchor-boot.sh` lines 181-202 (emit_assembly_trace), lines 500-502 (Spec Index health output)

## 1.5 Codemap Used

- Key Index:
  - `scripts/specanchor-boot.sh` — 698 行，已有 `B_INDEX_HEALTH_*` 4 个计数器 + `emit_assembly_trace()` 函数
  - `scripts/specanchor-index.sh` — `compute_module_health()` / `compute_global_health()` 函数（boot 通过 spec-index 数据复用）
  - `references/assembly-trace.md` — 31 行，Assembly Trace 格式定义
  - `references/agents/agent-contract.md` — 73 行，§1 Enter Spec Landscape

## 2. Research Findings

### 2.1 当前 boot 输出中已有的健康数据

boot 已经收集了以下数据（全局变量）：

| 变量 | 含义 | 来源 |
|------|------|------|
| `B_GLOBAL_COUNT` | Global Spec 数量 | `boot_global_specs()` |
| `B_MODULE_COUNT` | Module Spec 文件数 | `boot_specanchor_dir()` |
| `B_INDEX_HEALTH_FRESH` | 健康模块数 | spec-index 解析 |
| `B_INDEX_HEALTH_DRIFTED` | 轻微漂移模块数 | spec-index 解析 |
| `B_INDEX_HEALTH_STALE` | 过期模块数 | spec-index 解析 |
| `B_INDEX_HEALTH_OUTDATED` | 严重过期模块数 | spec-index 解析 |
| `B_SPEC_INDEX` | spec-index 是否存在 | `boot_specanchor_dir()` |

但这些数据**分散在多个输出行**，Agent 需要自己综合判断。缺少一个汇总。

### 2.2 Landscape Readiness 定义

Landscape Readiness 是对 Spec Landscape 完备度和新鲜度的**单行汇总判断**，基于以下维度：

| 维度 | READY 条件 | ATTENTION 条件 | NOT_READY 条件 |
|------|-----------|---------------|---------------|
| Global Specs | ≥1 个文件 | — | 0 个文件 |
| spec-index | 存在且为 v3 | 存在但 legacy 格式 | 不存在 |
| Module 健康度 | DRIFTED + STALE + OUTDATED = 0（全部 FRESH） | DRIFTED > 0 或 STALE > 0，但 OUTDATED = 0 | OUTDATED > 0 |

- **READY (🟢)**: 所有维度满足 READY → Agent 可以放心进入编码（所有模块 FRESH）
- **ATTENTION (🟡)**: 任一维度为 ATTENTION，无 NOT_READY → Agent 可以编码但建议先处理告警（有 DRIFTED/STALE 模块或 legacy index）
- **NOT_READY (🔴)**: 任一维度为 NOT_READY → Agent 应先补 Spec 再编码

> **parasitic mode 特殊处理**：parasitic mode 不使用 Global Spec 和 spec-index，因此上述三维度不适用。parasitic boot 时 Landscape Readiness 行输出 `N/A — parasitic mode (sources-only governance)`，不计算三档判定。

**设计决策**：Readiness 是**信息性**的，不阻断 boot（不 exit 1）。理由：
- boot 当前设计是"报告"而非"门禁"，阻断行为由 Agent Contract 中的 Schema Gate 负责
- Agent 应自主判断是否先修 Spec，而非被 boot 强制停止
- 未来如需阻断，可在 agent-contract.md 层面约定"NOT_READY 时不得进入 Execute"

### 2.3 输出格式设计

**summary/full 模式**新增一行（在 Assembly Trace 段落内）：

```text
  Assembly Trace:
    - Global: summary -> coding-standards.spec.md, architecture.spec.md
    - Module: deferred -> none (on-demand after module/path match)
    - Landscape Readiness: 🟢 READY (2 globals, 3/3 modules fresh)
```

ATTENTION 示例：
```text
    - Landscape Readiness: 🟡 ATTENTION — 1 STALE module, spec-index is legacy format
```

NOT_READY 示例：
```text
    - Landscape Readiness: 🔴 NOT_READY — no global specs, 2 OUTDATED modules
```

parasitic 示例：
```text
    - Landscape Readiness: ⚪ N/A — parasitic mode (sources-only governance)
```

**JSON 模式**新增 `landscape_readiness` 对象：

```json
{
  "assembly_trace": {
    "global": {"mode":"summary","files":[...]},
    "module": {"mode":"deferred","files":[]},
    "landscape_readiness": {
      "status": "READY",
      "global_count": 2,
      "module_total": 3,
      "module_fresh": 3,
      "module_drifted": 0,
      "module_stale": 0,
      "module_outdated": 0,
      "index_format": "v3",
      "reasons": []
    }
  }
}
```

### 2.4 assembly-trace.md 格式扩展

新增 `Landscape Readiness` 字段到标准格式定义。这是一个**可选行**，仅 boot 级别产出（assemble 不产出）。

### 2.5 agent-contract.md §1 的影响

当前 §1 Enter Spec Landscape 只说"Run boot → Output Assembly Trace → Don't edit if blocking errors"。新增 Readiness 后，应增加一条：

> 3. Note the Landscape Readiness status. If `NOT_READY`, prioritize fixing spec coverage before implementation.

## 3. Innovate

### Skip
- Skipped: true
- Reason: 方向明确（单行汇总 + 三档判定），不需多方案比较。唯一的设计选择（信息性 vs 阻断性）在 Research 中已决策。

## 4. Plan (Contract)

### 4.1 File Changes

1. **`scripts/specanchor-boot.sh`**：
   - 新增 `compute_landscape_readiness()` 函数：基于 `B_GLOBAL_COUNT`、`B_SPEC_INDEX`、`B_SPEC_INDEX_FORMAT`、`B_INDEX_HEALTH_*` 计算 readiness status + reasons
   - 修改 `emit_assembly_trace()`：在 Module trace 行后追加 `Landscape Readiness` 行
   - 修改 `output_json()`：在 `assembly_trace` 对象中追加 `landscape_readiness` 子对象

2. **`references/assembly-trace.md`**：
   - 标准格式段追加 `Landscape Readiness` 可选行
   - 语义段追加 READY / ATTENTION / NOT_READY 的定义
   - 规则段注明"仅 boot 产出，assemble 不产出"

3. **`references/agents/agent-contract.md`** §1：
   - 第 3 条修改为包含 Readiness 指引

### 4.2 Signatures

```bash
# scripts/specanchor-boot.sh 新增函数
compute_landscape_readiness()
# 写入全局变量：
#   B_READINESS_STATUS  — "READY" | "ATTENTION" | "NOT_READY"
#   B_READINESS_REASONS — array of reason strings
```

### 4.3 Implementation Checklist

- [x] 1. `specanchor-boot.sh` 新增 `compute_landscape_readiness()` 函数
- [x] 2. `specanchor-boot.sh` 修改 `emit_assembly_trace()` 追加 Readiness 行
- [x] 3. `specanchor-boot.sh` 修改 `output_json()` 追加 `landscape_readiness` JSON
- [x] 4. `references/assembly-trace.md` 更新标准格式 + 语义 + 规则
- [x] 5. `references/agents/agent-contract.md` §1 增加 Readiness 指引
- [x] 6. 运行 boot `--format=summary` 验证 Readiness 行在 Assembly Trace 中正确显示
- [x] 7. 运行 boot `--format=json` 验证 `landscape_readiness` JSON 字段完整
- [x] 8. 验证 parasitic fixture 下 boot 输出 `N/A`（不误判为 NOT_READY）
- [x] 9. 验证存量测试通过（`bash tests/run.sh`），确保输出契约变更不破坏现有断言

## 5. Execute Log

- [x] Step 1: `specanchor-boot.sh` 新增 `compute_landscape_readiness()` 函数（幂等保护：已计算则跳过），加上 `readiness_icon()` 和 `readiness_detail()` 辅助函数
- [x] Step 2: `emit_assembly_trace()` 末尾追加 `Landscape Readiness: <detail>` 行，full 和 parasitic 模式统一输出
- [x] Step 3: `output_json()` 在 `assembly_trace` 对象内追加 `landscape_readiness` 子对象（status/global_count/module_*/index_format/reasons）
- [x] Step 4: `assembly-trace.md` 更新标准格式新增 Readiness 行 + Landscape Readiness 语义定义（READY/ATTENTION/NOT_READY/N/A）+ 规则 5（仅 boot 产出）
- [x] Step 5: `agent-contract.md` §1 从 3 条变 4 条，新增"Note the Landscape Readiness status"指引
- [x] Step 6-9: 验证通过 — summary 显示 `🟡 ATTENTION — 2 DRIFTED module(s)`；JSON 合法解析且字段完整；parasitic 输出 `⚪ N/A`；29 个存量测试全部通过

## 6. Review Verdict

- Spec coverage: PASS — 所有计划文件均已变更
- Behavior check: PASS — boot summary/full/json 三种格式均正确输出 Landscape Readiness
- Regression risk: Low — 新增输出行不影响已有解析契约，JSON 字段为追加型
- Module Spec 需更新: Yes — `scripts.spec.md` 应记录 `compute_landscape_readiness()` 作为 boot 的新增计算步骤（Follow-up）
- Spec Sediment（经验沉淀）:
  - Global Spec 需更新: No
  - 新发现的项目规则: boot 输出新增行应尽量追加而非插入，避免破坏已有行号依赖的测试断言
  - 值得记录的反模式: StrReplace 对包含中文引号（""）的字符串匹配不稳定，需用 Python fallback
- Follow-ups:
  - `scripts.spec.md` 补充 `compute_landscape_readiness()` 接口说明
  - 考虑为 Landscape Readiness 添加专用 bats 测试用例（覆盖 READY/ATTENTION/NOT_READY 边界）

## 7. Plan-Execution Diff

- 无偏差。所有 9 步 Checklist 按计划完成。

## 1.2 Hard Boundaries

> not applicable — legacy task (predates v0.5.0-beta.1 Harness Context Control schema)

- (none)

## 1.3 Allowed Freedom

> not applicable — legacy task

- (none)

### 4.7 Checkpoints — Contract

> not applicable — legacy task

#### CP-1 (legacy, no checkpoint contract recorded)
- Output: (none)
- Awaits: pass

## 5.2 Checkpoint Decisions Log

> not applicable — legacy task; no per-checkpoint decisions recorded

### Recent (active, hot)

- (none)

## 6.2 Evidence Ledger

> not applicable — legacy task; evidence (if any) recorded inline above

### Commands Run

| Command | Status | Output ref |
|---|---|---|

## 7.2 Handoff Packet

> not applicable — legacy task (auto-generated section, no handoff produced)
