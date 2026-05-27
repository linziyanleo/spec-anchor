# Why SpecAnchor

[中文](WHY_ZH.md)

> Spec is the anchor, code is the ship. With the anchor set, the ship won't drift.

---

## The Deeper Vision

Spec norms themselves will gradually fade as model capabilities grow — context windows keep expanding, and models reading code logic directly becomes more precise than reading documents. But people don't change.

People will always need something visual to understand what models produce — code is written by AI, but decisions are made by humans. As AI produces more code, faster, the human need to understand "why this code is written this way, what modules it relates to, and what breaks if I change it" only grows stronger.

**SpecAnchor anchors not just context knowledge and coding standards, but more fundamentally, it anchors people's cognitive understanding of code internals.**

So SpecAnchor will evolve alongside model capabilities:

- Current phase: Anchoring AI context (Global + Module Spec constrain generation quality)
- Next phase: Anchoring human cognition (Spec becomes the interface for people to understand AI output)
- Long-term: Spec may evolve from "constraints written for AI to read" into "cognitive maps written for humans to read"

---

## Compiled Knowledge vs Retrieved Knowledge

SpecAnchor's approach can be understood through a simple contrast:

| Mode | Approach | Cost |
|------|----------|------|
| **Retrieved** (RAG paradigm) | Retrieve relevant code fragments on every query, let AI deduce from scratch | Starts from zero every time, cross-module insights depend on luck, knowledge doesn't accumulate |
| **Compiled** (SpecAnchor paradigm) | Pre-compile code insights into persistent Spec files, AI loads compiled context before coding | Requires maintaining Specs, but write once, reuse repeatedly — knowledge compounds over time |

This contrast is not SpecAnchor's invention. Karpathy articulated the same pattern for personal knowledge management in [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): don't let the LLM re-derive from raw documents on every query — let it **compile** knowledge into a persistent wiki, then work on already-compiled knowledge.

SpecAnchor is this pattern instantiated for **AI-assisted development**:
- LLM Wiki's Raw Sources = project source code
- LLM Wiki's Wiki = the three-level Spec system under `.specanchor/`
- LLM Wiki's Schema = `SKILL.md` + declarative writing protocols

The difference: LLM Wiki pursues breadth of knowledge (richer over time), SpecAnchor pursues precision of standards (more accurate over time). But the underlying insight is the same — **the real cost of maintenance is not reading and thinking, it's bookkeeping** (cross-references, consistency checks, staleness detection). SpecAnchor delegates this bookkeeping to AI and automation scripts.

---

## Four Categories of Context (v0.5.0 → v0.6)

LLM context is precious — long context rots in the middle, recency bias dominates, automatic compaction loses precision. SpecAnchor does not try to extend the window; it organizes what *deserves* to be in it. Starting from v0.5.0-beta.1 the framing was explicit (Spec / Decision / Evidence); v0.6 adds **Finding** as the fourth first-class context category — agent discoveries during execution that previously vanished into chat history.

| Category | What it is | Lifecycle | Anti-decay tool |
|---|---|---|---|
| **Spec Context (cold)** | Static contracts: team rules, module interfaces, task intent | Versioned in git; rarely changes per turn | Assembly Trace + (opt-in) Schema Gate |
| **Decision Context (hot)** | What humans said at each checkpoint (~47% "add-spec", ~25% "clarify" — the bulk of per-turn signal) | Sediments into Task Spec §5.2 per checkpoint; hot/cold lazy view auto-prunes | `decision_log` config + lazy filter |
| **Evidence Context (hot)** | Verification proofs: command outputs, acceptance criteria, unverified risks | Appended to Task Spec §6.2 as work progresses; auto-pinned for acceptance criteria | `evidence_log` config + auto-pin |
| **Finding Context (hot, v0.6+)** | Agent discoveries during execute / review: facts, contradictions, stale claims, reuse opportunities | Standalone `.specanchor/findings/F-*.md` files; required `summary` field (≤120 chars) drives lazy-load tier (immediate→full / sediment_queue→summary / handoff→title); `visibility` controls review cost; sediment via human-curated **Sediment Proposal** (never auto-applied to Spec) | `specanchor-finding.sh new --summary=...` + bundle v1 lazy-load + `specanchor-doctor.sh` long-pending / backfill check |

Why this matters: most prior tools (Spec-Kit, OpenSpec, plain Cursor rules) only model **Spec Context**. The 47% of human signal that lands as a checkpoint correction or addition was thrown away every turn. SpecAnchor v0.5.0 made Decision and Evidence first-class; **v0.6 closes the loop by making agent-side discoveries (Finding) first-class too** — so cross-session, cross-task engineering memory finally has a home outside chat history.

**Repositioning in v0.6**: SpecAnchor stops calling itself a "Harness Context Control plane" and instead clarifies its scope as a **Context Construction System** — it compiles bounded, auditable, sedimentable context bundles for coding agents, but does not own the agent execution loop. Workflow schemas like `sdd-riper-one` move from default identity to opt-in integration. See the appendix F in private design notes for the full diagnosis.

---

## Two Species of Handoff (v0.5.0+)

"Handoff" looks like one concept but is actually two distinct artifacts. Conflating them produces the "placeholder hack" anti-pattern (forcing a portfolio doc into a task schema). SpecAnchor names them explicitly:

| Species | Physical location | Generated by | Use case | Trigger |
|---|---|---|---|---|
| **Task-internal handoff packet** | `sdd-riper-one §7.2` section inside one Task Spec | tool (`assemble.sh --mode=handoff`) | Same task, new chat — preserve hot decisions / next step / read-next | `specanchor_handoff` command |
| **Portfolio handoff spec** | Standalone spec file using `handoff` schema | author (hand-written) | Cross-task / cross-release roadmap; deferred-items matrix; next-session entry point | `specanchor_task` with `writing_protocol: handoff` |

The packet is a tool-rendered hot view *of* a single task; the portfolio spec is a hand-curated entry point *across* tasks. They do not replace each other. Task-internal handoff shipped in v0.5.0-beta.1; the portfolio handoff schema and two-species framing were introduced on main afterwards. Schema-aware enforce (lint) only requires the 6 sdd-riper-one v2 sections (`§1.2 / §1.3 / §4.7 / §5.2 / §6.2 / §7.2`) on schemas that explicitly declare them — so a portfolio handoff spec is not pressured into pretending it has Hard Boundaries and Evidence Ledger.

---

## Problems It Solves

| Problem | SpecAnchor's Answer |
|---------|-------------------|
| AI-generated code doesn't follow team standards | Global Spec provides "constitutional" constraints that AI must follow |
| Different developers have inconsistent styles on the same module | Module Spec defines interface contracts and design conventions |
| The "why" behind code changes gets lost | Task Spec records the intent and decisions behind every change |
| Spec and code go out of sync (decay) | Alignment detection checks Spec-code consistency |
| Checkpoint decisions get eaten by chat decay | **Decision Context** with `status` (active / superseded / withdrawn) and lazy hot/cold lifecycle (§5.2 Decision Log) |
| Completion reports say "passed" but no evidence chain | **Evidence Ledger** with auto-pinned acceptance criteria, command logs, and unverified-risk registry (§6.2) |

## Design Principles

1. **Spec is cause, code is effect** — write Spec before code (forward flow); when code changes, check if Spec is stale (reverse flow)
2. **Don't aim for 100% coverage** — let the most critical modules have Specs first, progressively expand
3. **Don't lock in a writing tool** — SpecAnchor only handles "organization" (where, format, status), not "writing" (defaults to SDD-RIPER-ONE, replaceable with OpenSpec or any format)
4. **Global Spec ≤ 200 lines** — this is a physical constraint of AI context windows, enforcing conciseness
5. **Centralized Module Spec management** — stored in `.specanchor/modules/`, indexed to real module paths via `spec-index.md`
6. **Full rewrite + git versioning** — Module Spec updates are full rewrites, with changes managed through `git diff` and Code Review
7. **Platform agnostic** — plain-text Skill, works with Cursor, Claude Code, Cline, and any AI tool that can read files
8. **Single responsibility** — non-Spec governance capabilities should live in separate skills, not inside the core Skill token budget

## Usage Recommendations by Role

### Team Engineers

Engineers are **full participants** in the SpecAnchor system.

**Daily workflow**:

```
1. Receive requirements
   ↓
2. "Create task: <task name>"                 Create Task Spec
   ↓
3. (AI auto-loads Global + Module Spec)
   ↓
4. Develop following Task Spec (defaults to SDD-RIPER-ONE's RIPER flow)
   ↓
5. Development done, check if Module Spec needs updating
   ↓
6. "Check Spec alignment"                     Confirm Spec-code alignment
   ↓
7. Receive review feedback → fix → repeat 5-6
```

**Recommended frequency**:

| Action | Frequency |
|--------|-----------|
| Create Task Spec | Every task |
| Create/update Module Spec | When touching a new module / end of Sprint sync |
| Update Global Spec | Quarterly |
| Global coverage report | End of each Sprint |

### External Collaborators

Collaborators are the **biggest beneficiaries** of the SpecAnchor system — Global Spec + Module Spec already define "how to write code", so AI-generated code naturally follows team standards under these constraints.

**Permission boundaries**:

| Action | Allowed? |
|--------|----------|
| Read Global Spec | ✅ |
| Modify Global Spec | ❌ |
| Create/modify Module Spec | Requires engineer Review |
| Create/execute Task Spec | ✅ |
| Run alignment detection | ✅ |

## Cold Start Guide for Existing Projects

### Phase 0: Initialize + Global Spec (Day 1-2)

```
1. Install Skill
2. "Help me initialize SpecAnchor" (auto-scans project and generates Global Spec)
3. Manual Review → adjust → commit
```

### Phase 1: Progressive Module Spec (ongoing)

**"Document on touch" principle** — don't proactively generate Specs for all modules; trigger naturally at these moments:

| Trigger | Action |
|---------|--------|
| New module created | Create Module Spec as the module's first file |
| First modification of existing module | "Infer module spec from code" to generate draft → manual review |
| Major refactoring | Require updating/creating Module Spec first |
| New team member takes over module | Create Module Spec for knowledge transfer |

### Cold Start Milestones

| Timeline | Expected Coverage | Focus |
|----------|------------------|-------|
| Week 1 | Global Spec 100%, Module Spec 0% | Establish baseline |
| Month 1 | Module Spec 10-20% | Cover frequently modified core modules |
| Month 3 | Module Spec 40-60% | High-change modules naturally covered |
| Month 6 | Module Spec 70%+ | Approaching "healthy" level |

## Evolution Roadmap

SpecAnchor will evolve alongside changes in AI capabilities and development paradigms:

### Current (v0.x) — Anchoring AI Context

- Three-level Spec + Decision/Evidence Context system (v0.5.0+ explicit)
- Coverage detection + staleness detection + `doctor --lint=context-control`
- Declarative Schema system (SDD-RIPER-ONE / OpenSpec / custom compatible)
- External Sources directory alias mapping
- `specanchor_handoff` command for cross-session continuity
- Plain-text Skill, platform agnostic
- (deferred) Steering Trigger emit on verification failure × 2
- (deferred) task-local codemap as a first-class command

### Near-term — Anchoring Human Cognition

- [ ] Spec visualization dashboard (coverage heatmap, module dependency graph, change timeline)
- [ ] Spec Diff visualization (Module Spec before/after comparison, linked to code diff)
- [ ] Interactive Module Map (click a module to view Spec, related code, change history)
- [ ] CLI tool (`specanchor check` / `specanchor status` as command-line commands)

### Long-term — Spec as Cognitive Map

- [ ] Spec evolves from "constraint document" to "cognitive interface" — people understand the system through Spec, not by reading code
- [ ] Real-time Spec sync (code changes automatically trigger Spec update suggestions)
- [ ] Multi-user collaboration awareness (who's editing which module's Spec, conflict warnings)
- [ ] Deep IDE integration (Spec coverage gutter annotations, inline Spec references)

## Flowchart

Full Skill invocation flow diagram: [FLOWCHART.md](FLOWCHART.md).
