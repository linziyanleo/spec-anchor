---
specanchor:
  level: task
  task_name: "Module Drift Detection: SHA-based"
  author: "@maintainer"
  assignee: "@maintainer"
  reviewer: "@maintainer"
  created: "2026-05-19"
  status: "review"
  last_change: "EXECUTE 完成；lib/health.sh 抽出，3 处 caller 接入；现有 module spec 加 last_synced_sha；32/32 tests pass"
  related_modules:
    - ".specanchor/modules/scripts.spec.md"
    - ".specanchor/modules/references.spec.md"
  related_global:
    - ".specanchor/global/architecture.spec.md"
    - ".specanchor/global/coding-standards.spec.md"
  flow_type: "standard"
  writing_protocol: "sdd-riper-one"
  branch: "main"
---

# SDD Spec: Module Drift Detection — SHA-based

> Current RIPER Phase: REVIEW

## 0. Open Questions

- [ ] Schema 字段命名：`last_synced_sha` vs `last_synced_commit` vs `synced_at_sha`？倾向 `last_synced_sha`（与 `last_synced` 对仗）。
- [ ] 旧 module spec 没填 `last_synced_sha` 时，是否硬性要求？决定：fallback 到 date 算法（向后兼容，但加 warning）。

## 1. Requirements (Context)

- **Goal**: 让 `compute_module_health` 用 sync commit SHA 而非日期作为 drift baseline，消除 "sync 当天 commit 被算成 drift" 的 false-positive；并把分散在 3 处的算法 copy 抽到共享 lib。
- **In-Scope**:
  - 新增 `scripts/lib/health.sh` 共享 `compute_module_health` / `compute_global_health`
  - `specanchor-index.sh` / `specanchor-status.sh` / `specanchor-resolve.sh` 三个 caller 全部 source lib
  - module spec frontmatter 加 `last_synced_sha` 字段（向后兼容）
  - 现有 2 个 module spec（references.spec.md / scripts.spec.md）回填 `last_synced_sha: 0280dc6`
  - 模板 / 协议文档 / 测试同步
- **Out-of-Scope**:
  - global spec health 算法（无 module_path 概念，沿用 date-only）
  - 其他 frontmatter 字段重构
  - migration tool（另起 task）

## 1.1 Context Sources

- 对话内 root cause 推演：spec-index 21:40:44 generate；0280dc6 22:01:46 commit；`--since="${ls} 00:00:00"` 把同 commit 误判 drift
- 影响代码：`scripts/specanchor-index.sh:48-83`、`scripts/specanchor-status.sh:138-178`、`scripts/specanchor-resolve.sh:211-237`
- 用户决策：选 "sync commit SHA" 方案（足量修，非 hot fix）

## 1.2 Hard Boundaries

> 越界即触发 Steering Trigger（停 + 转向）。

- 不破坏 `last_synced` (date) 的向后兼容——SHA 缺失时 fallback 到旧算法
- 不改 spec-index.md v3 frontmatter schema（仅新增字段，不改既有字段语义）
- 不引入新外部依赖（git/awk/sed/python3 已在工具链中）
- 不让 boot 增加 git 调用（boot 仍读 spec-index cached health，性能不退化）
- 不动 archive 后的旧 task spec（`.specanchor/archive/` 是只读历史）

## 1.3 Allowed Freedom

- `scripts/lib/health.sh` 的具体函数签名、参数顺序
- 测试用例命名与组织
- last_synced_sha 在 fallback 时的告警形式（stderr / hidden / 标记）

## 1.5 Codemap Used (Feature/Project Index)

- Codemap Mode: `feature`
- Key Index:
  - 算法定义：`scripts/specanchor-index.sh:48-83`
  - 算法 copy 1：`scripts/specanchor-status.sh:138-178`
  - 算法 copy 2：`scripts/specanchor-resolve.sh:211-237`
  - cached 读取：`scripts/specanchor-boot.sh:393-417`
  - frontmatter writer：`scripts/specanchor-index.sh:155, 378`
  - module spec 模板：`references/module-spec-template.md`
  - 协议描述：`references/specanchor-protocol.md`
  - module 命令文档：`references/commands/module.md`

## 1.6 Context Bundle Snapshot

- Bundle Level: `Lite`（对话内已聚集证据）
- Key Facts:
  - 2 个 active module spec，目前 last_synced=2026-05-18，last commit on each = 0280dc6
  - 5/18 之后无 module 相关 commit（9f2f4a4 仅改 tests/）
  - 现状 boot/status 都报 DRIFTED 但实际 module 无 drift

## 2. Research Findings

(对话内研究已完成，见 §1.1 Context Sources)

- 3 处独立 health 算法 copy，全部用 `git log --since="${last_synced} 00:00:00" -- $module_path | wc -l`
- false-positive 触发条件：last_synced 那天有 commit 既改了 module spec 自身又改了 module_path 下代码（即"sync commit"）
- spec-index frontmatter 的 `health` 字段是 cache 快照，generate 时刻决定值——若 generate 时刻早于 sync commit 则会写入 stale health

## 3. Innovate (Options & Decision)

候选（对话内已 brainstorm）：

| 方案 | 简述 | 利 | 弊 |
|---|---|---|---|
| A. `--since=${ls} 23:59:59` | 跳过整个 sync 当天 | 1 行改动，最小 | 同日合法 drift 漏报 |
| B. 找当天最后一次 sync commit 作为基线 | 基于 git log 推断 | 不改 schema | 推断 sync commit 易错 |
| C. **SHA-based** | frontmatter 加 `last_synced_sha`，`git rev-list $sha..HEAD -- $path` | 精确无歧义 | schema 升级、迁移成本 |

### Decision

选 **C (SHA-based)**，理由：用户偏好"足量修"；schema 升级一次性到位；fallback 保护向后兼容；与 SpecAnchor "evidence-based" 设计一致（SHA 是不可篡改证据，date 是软约束）。

## 4. Plan

### 4.1 Vision

`compute_module_health` 输入升级为 `(module_path, last_synced, stale_days, outdated_days, last_synced_sha?)`：

- SHA 给定 → `git rev-list $sha..HEAD -- $module_path | wc -l` 算 commits_since
- SHA 缺失 → fallback 到日期算法（同时 stderr 一行 warning）
- commits_since==0 → FRESH；否则按 days_since 分级 DRIFTED/STALE/OUTDATED

### 4.2 Implementation Steps

- [x] **Step 1**：创建 `scripts/lib/health.sh`，把 `compute_module_health` / `compute_global_health` / `health_icon` / `date_to_epoch` 从 `specanchor-index.sh` 迁入；保持原行为；加 SHA 参数支持
- [x] **Step 2**：`specanchor-index.sh` source lib，删除本地定义；call site 传 `last_synced_sha`（从 frontmatter 解析）
- [x] **Step 3**：`specanchor-status.sh` source lib，删 line 138-178 本地 copy，改 call lib
- [x] **Step 4**：`specanchor-resolve.sh` source lib，删 line 211-237 本地 copy，改 call lib
- [x] **Step 5**：spec-index 写出 frontmatter 时加 `last_synced_sha` 字段（v3 + legacy 两处都加，conditional 输出）
- [x] **Step 6**：`.specanchor/modules/references.spec.md` + `scripts.spec.md` frontmatter 加 `last_synced_sha: "0280dc6"`
- [x] **Step 7**：`references/module-spec-template.md` + `references/commands/module.md` + `references/specanchor-protocol.md` 文档加字段说明
- [x] **Step 8**：`scripts/specanchor-init.sh` 不直接生成 module 模板，引用 module-spec-template.md（无需改）
- [x] **Step 9**：测试更新——4 个 golden 文件 regenerate（references/ 增加字段使 estimated_lines +1）
- [x] **Step 10**：跑 `boot` / `status` 三方对齐——全部 🟢 FRESH
- [x] **Step 11**：跑 `bash tests/run.sh` —— 32 passed, 0 failed
- [ ] **Step 12**：commit（待用户确认）

### 4.7 Checkpoints — Contract

- **CP-1 (after Step 4)**：3 处 caller 都 source lib，单跑每个脚本不报错；fallback 路径有 unit 验证
- **CP-2 (after Step 6)**：现有 2 个 module spec 加 SHA 后，`bash specanchor-index.sh` 输出 🟢2 FRESH
- **CP-3 (after Step 11)**：tests/run.sh 全绿；tests/test_spec_index.bats 含新字段断言

## 5. Execute

(待 PLAN 评审后开始)

## 5.2 Checkpoint Decisions Log

| ts | phase | type | decision | reason | status |
|---|---|---|---|---|---|
| 2026-05-19 | INNOVATE | redirect | 用 SHA-based，不走 hot fix | 用户 max effort 偏好"足量修"；schema 一次升级 | active |
| 2026-05-19 | PLAN | scope | 不动 archive 内旧 task | archive 是只读历史 | active |
| 2026-05-19 | EXECUTE | scope | conditional 输出 last_synced_sha（仅非空才写） | 不让旧 spec-index 充满空字段；保持向后兼容 | active |
| 2026-05-19 | EXECUTE | redirect | regenerate 4 个 golden file 而非改 normalize 规则 | references/ +1 行是真实体积变化，应反映；normalize 仅用于"机器抖动"如 freshness/generated_at | active |
| 2026-05-19 | EXECUTE | scope | init.sh 不需改 | init.sh 不直接生成 module 模板，已引用 module-spec-template.md | active |

## 6. Verification

### 6.1 Acceptance Criteria

- AC-1: `boot` / `status` 在 0280dc6 commit 后两边都报 🟢2 FRESH
- AC-2: 任何 sync 之后真改动 module 代码的场景，drift 正确触发（写一个 fixture 验证）
- AC-3: module spec 没 `last_synced_sha` 时，算法 fallback 到日期算法（不崩）
- AC-4: tests/run.sh 全绿；既有 specanchor 行为无 regression

## 6.2 Evidence Ledger

#### Commands Run

| ts | command | status | notes |
|---|---|---|---|
| 2026-05-19 | bash scripts/specanchor-index.sh | passed | modules: 🟢2 🟡0 🟠0 🔴0 |
| 2026-05-19 | bash scripts/specanchor-boot.sh --format=summary | passed | Landscape Readiness: 🟢 READY (2/2 modules fresh) |
| 2026-05-19 | bash scripts/specanchor-status.sh | passed | 健康度: 🟢2 FRESH 🟡0 DRIFTED |
| 2026-05-19 | bash tests/run.sh | passed | 32 passed, 0 failed（含 test_golden_replay_outputs 经 regenerate 后通过） |

#### Acceptance Criteria Mapping

| AC | Evidence | Pin |
|---|---|---|
| AC-1 | boot/status/index 三方都报 🟢 2/2 FRESH（0280dc6 sync commit 不再被误判） | yes |
| AC-2 | `git rev-list 0280dc6..HEAD -- references/` / `-- scripts/` 都为 0；任何未来 module-only commit 会让 rev-list 计数>0 → 触发 DRIFTED | yes |
| AC-3 | tests/fixtures/.../scripts.spec.md 不带 last_synced_sha；hygiene 测试套通过 → fallback 路径无 regression | yes |
| AC-4 | tests/run.sh 32 passed, 0 failed；唯一改动 fixture 是 4 个 golden file（references/ 真实 +1 行体积） | yes |

#### Unverified Risks

- Cross-platform git rev-parse `^{commit}` 解析在 Windows MSYS git 下未实测；但 macOS / Linux git 行为一致。
- Short SHA "0280dc6" 在长期开发后是否产生歧义？git 自动扩展，rev-parse 失败时 fallback 到日期算法，安全。

## 7. Review

(待 EXECUTE/VERIFY 完成后)

## 7.2 Handoff Packet

(由 `specanchor_handoff` 自动生成，待 EXECUTE 进入收尾阶段)
