---
id: F-YYYYMMDD-NNN
summary: <120 字符以内单行：主语 + 事实 + 锚点（路径/数字/对比）>
type: fact            # fact | contradiction | stale-claim | risk | reuse-opportunity | pattern
status: candidate     # candidate | accepted | rejected | superseded | archived
confidence: medium    # low | medium | high
impact: medium        # low | medium | high
visibility: handoff   # hidden | handoff | sediment_queue | immediate
affects:
  - module: <module-name>
  # 或 path: <file-path>
  # 或 contract: <contract-name>
evidence_ref:
  - type: diff        # diff | command | test | file-snapshot
    ref: <git-sha-or-file-or-command>
suggested_target: none  # none | task | module | global | codemap
created: YYYY-MM-DD
updated: YYYY-MM-DD
source_task: null     # task spec path 或 null
---

# Finding: <短描述>

## Observation

（具体观察到什么——客观事实陈述，避免推测）

## Why It Matters

（为什么这个发现重要——影响范围、风险、机会）

## Evidence

（具体证据：命令输出、test 结果、git diff、文件快照引用）

## Implications

（如果接受这个 finding，对哪些代码 / spec / 决策有影响）

## Proposed Action

（建议的处置方式——是否应该 sediment、是否需要更多验证、是否需要立即处理）

---

> **填写指引**（删除此段）：
>
> - **summary 写作准则**：
>   - ≤120 字符单行；主语 + 事实 + 锚点（路径/数字/对比），让 sediment_queue / handoff 层只读 summary 也能判断是否值得展开。
>   - ✓ `session TTL mismatch: doc=1h, code=24h (auth/session.go:42)`
>   - ✓ `validate.sh skips evidence_ref shape check on multiline lists (lib/finding-parser.sh)`
>   - ✗ `auth issue`（无锚点、无对比）
>   - ✗ `发现一个 bug 需要修复`（无主语、无事实）
> - **visibility 默认值参考**：
>   - `confidence=low` 或 `impact=low` → `hidden`
>   - `confidence=medium` → `handoff`
>   - `confidence=high + evidence + impact>=medium` → `sediment_queue`
>   - 触发 stop trigger 的 finding → `immediate`
> - **status=candidate** 是新建默认。`accepted` 必须有 evidence_ref。`rejected` 保留文件做证据。
> - **suggested_target** 是建议沉淀位置，不是承诺——最终由 Sediment Proposal 阶段人审决定。
> - 提交前删除本"填写指引"段。
