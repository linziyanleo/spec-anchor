# Capability Drift

> Status: concept note. First extracted from the 2026-05-19 dogfood session; implementation is intentionally deferred.

## Definition

**Capability Drift** happens when a spec's description of tool capability, system state, audit findings, or known constraints is overtaken by later implementation.

Typical stale claims look like:

- "X does not support Y"
- "Step A/B/C is still required"
- "Current state: validation cannot detect ..."
- "Known gap: ..."

The danger is not that code fails a current plan. The danger is that future planning starts from an obsolete description of what the system can or cannot do.

## Relation To Existing Drift Types

| Drift type | Direction | Detection today | Primary risk |
|---|---|---|---|
| Spec-Code Drift | Plan / spec vs implementation | `specanchor-check.sh` task mode | Current work diverges from the agreed plan |
| Module Drift | Module spec vs changed code | SHA-based module freshness | Readers misunderstand current module behavior |
| Spec-Spec Drift | Spec file vs another spec file | Draft protocol in `references/spec-drift-protocol.md` | Specs contradict each other |
| Capability Drift | Spec claim vs later tool/system capability | Manual `§6.3` check today | Future plans repeat already-solved work |

## Dogfood Case

The triggering case was an audit finding that said `specanchor-validate.sh` was not schema-aware and that frontmatter fields were still hard-coded. Later dogfood verification showed schema-aware validation had already landed, including warnings for missing required fields, unknown fields, and field type mismatches.

The original spec was not wrong when written. It became stale after implementation caught up.

## Review-Time Check

Until there is an automated detector, sdd-riper-one tasks should perform a lightweight review-time check:

- Is this spec still accurate about current tool capability, system state, audit findings, and known constraints?
- Has any "X does not support Y" or "we still need Step A/B/C" claim been superseded by later code or specs?
- If a claim is stale, mark the original claim with `[stale: superseded by <commit-sha / spec-path>]` and record the pattern in Spec Sediment.

## Evidence Writing Rule

Evidence Ledger entries must distinguish durable contract evidence from time-bound snapshot evidence.

- **Contract evidence** proves an invariant that should remain true, such as a JSON key being emitted or a command returning valid JSON. These claims should be backed by tests or repeatable assertions.
- **Snapshot evidence** records state at a moment, such as the number of active tasks or the exact current branch. These claims must include the command and timestamp, and must not be promoted into enduring spec facts.

Prefer: "`2026-05-20 11:05 CST`, `specanchor-boot.sh --format=json` returned `task_active=9`."

Avoid: "The project has 9 active tasks."

