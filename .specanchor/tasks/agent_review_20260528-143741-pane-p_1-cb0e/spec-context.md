SpecAnchor Boot [full]
  Config: anchor.yaml (v0.5.0-beta.1, project: spec-anchor)
  Assembly Trace:
    - Global: summary -> .specanchor/global/architecture.spec.md, .specanchor/global/coding-standards.spec.md, .specanchor/global/project-setup.spec.md
    - Module: deferred -> none (on-demand after module/path match)
    - Landscape Readiness: 🟢 READY (3 globals, 2/2 modules fresh)
  Global Specs: 3 files, 167 lines total
    - architecture.spec.md (55 lines)
    - coding-standards.spec.md (65 lines)
    - project-setup.spec.md (47 lines)
  Module Specs: 2 module(s) (按需加载)
  Spec Index: v3 (structured) — 🟢2 🟡0 🟠0 🔴0
  Task Specs: 17 active, 11 archived
  Active Tasks:
    - Boot/Status Active Tasks 段 + Capability Drift 概念草稿 [done · PLAN (sdd-riper-one)] _cross-module/2026-05-19_boot-active-tasks-and-capability-drift.spec.md
    - Codemap Command Draft (time-gated implementation) [done (simple)] _cross-module/2026-05-19_codemap-command-draft.spec.md
    - Handoff Schema 引入 + Schema-Aware Enforce [review · REVIEW (sdd-riper-one)] _cross-module/2026-05-19_handoff-schema-and-aware-enforce.spec.md
    - Handoff Schema Rollout Follow-ups [done (simple)] _cross-module/2026-05-19_handoff-schema-followups.spec.md
    - Legacy Task Migration Tool: doctor --include-archive + migrate.sh [done · REVIEW (sdd-riper-one)] _cross-module/2026-05-19_legacy-task-migration-tool.spec.md
    - Module Drift Detection: SHA-based [review · REVIEW (sdd-riper-one)] _cross-module/2026-05-19_module-drift-detection-sha-based.spec.md
    - Spec↔Spec Drift Protocol Draft [done (simple)] _cross-module/2026-05-19_spec-drift-protocol-draft.spec.md
    - Steering Trigger: corpus collector + design draft [review · REVIEW (sdd-riper-one)] _cross-module/2026-05-19_steering-trigger-corpus-and-design.spec.md
    - 顶层文档能力准确性清理 [done · EXECUTE (sdd-riper-one)] _cross-module/2026-05-20_doc-capability-accuracy-cleanup.spec.md
    - Dogfood Followups Batch (F3-F10) [review · REVIEW (sdd-riper-one)] _cross-module/2026-05-20_dogfood-followups-batch.spec.md
    - Init 交互式三问改造 [review · REVIEW (sdd-riper-one)] _cross-module/2026-05-20_init-interactive-prompts.spec.md
    - specanchor-init --scan-sources Bash 3.2 bug [done (bug-fix)] _cross-module/2026-05-20_init-scan-sources-bash3-bug.spec.md
    - Context System Construction Plan [draft (simple)] _cross-module/2026-05-24_context-system-construction.spec.md
    - Cross-Repo Context Management Plan [draft (simple)] _cross-module/2026-05-24_cross-repo-context-management.spec.md
    - Boot-install: 把 SpecAnchor 触发块幂等注入 CLAUDE.md/AGENTS.md/GEMINI.md/cursor 规则 [done (simple)] _cross-module/2026-05-25_boot-install-claude-md-injection.spec.md
    - Findings Lazy-Load: summary frontmatter + 分级载荷 [draft · PLAN (sdd-riper-one)] _cross-module/2026-05-25_findings-lazy-load-summary-field.spec.md
    - (unnamed) [done (simple)] _cross-module/2026-05-27_trigger-rate-optimization.spec.md
  Available Commands:
    init     -> commands/init.md      | 初始化配置与目录
    global   -> commands/global.md    | Global Spec CRUD
    module   -> commands/module.md    | Module Spec CRUD
    infer    -> commands/infer.md     | 从代码逆推 Module Spec
    task     -> commands/task.md      | 创建 Task Spec
    load     -> commands/load.md      | 手动加载 Spec
    status   -> commands/status.md    | 状态/覆盖率
    check    -> commands/check.md     | 对齐检测
    index    -> commands/index.md     | 更新 spec-index
    import   -> commands/import.md    | 导入外部 SDD
    handoff  -> commands/handoff.md   | 跨 session 导出 handoff packet
  Available Modules:
    references/   -> references.spec.md     | 协议声明层：命令定义、Spec 模板、Schema 系统、核心协议 [🟢 FRESH]
    scripts/      -> scripts.spec.md        | Shell 自动化工具层：初始化、状态/诊断、索引、对齐检测、Frontmatter、解析与校验 [🟢 FRESH]
  Sources: (无外部来源)
  Available Schemas:
    bug-fix [strict]: Bug 修复流程——复现 → 诊断（添加日志，收集证据）→ 根因分析 → 修复 → 验证。
    handoff [fluid]: Portfolio / cross-session handoff spec —— 给下一会话的 entry po...
    openspec-compat [fluid]: OpenSpec 兼容工作流——Fluid 风格，依赖是使能器不是门禁。支持 Delta Specs 增量变更表达。
    refactor [strict]: 代码重构流程——度量 → 识别 → 计划 → 重构 → 验证行为不变。核心约束：外部行为必须保持不变。
    research [strict]: 技术调研流程——提问 → 探索 → 发现 → 追问（激活用户思路）→ 结论。不产出代码，产出结论和建议。
    sdd-riper-one (default) [strict]: SDD-RIPER-ONE 流程——带严格门禁的规范驱动开发。Research → (Innovate) → Pl...
    simple [fluid]: 轻量级 Task Spec——快速记录任务目标和改动计划，无门禁、无 RIPER 流程。适合简单但仍希望有 Spe...
  Next: 完成 Handoff Schema 引入 + Schema-Aware Enforce Review
