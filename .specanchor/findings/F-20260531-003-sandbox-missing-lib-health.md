---
id: F-20260531-003
summary: setup_helper create_sandbox 只拷 lib/common.sh，漏 index.sh 依赖的 lib/health.sh，致 check-global bats 退非0；改为 cp lib/*.sh
type: risk
status: candidate
confidence: high
impact: medium
visibility: handoff
affects: []
evidence_ref: []
suggested_target: none
created: 2026-05-31
updated: 2026-05-31
source_task: null
---

# Finding: sandbox-missing-lib-health

## Observation

（具体观察到什么——客观事实陈述，避免推测）

## Why It Matters

（影响范围、风险、机会）

## Evidence

（命令输出 / test 结果 / git diff / 文件快照引用）

## Implications

（如果接受这个 finding，对哪些代码 / spec / 决策有影响）

## Proposed Action

（建议处置：是否应该 sediment、是否需要更多验证、是否需要立即处理）
