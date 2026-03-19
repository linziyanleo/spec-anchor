# Why SpecAnchor

[中文](WHY.md)

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

## Problems It Solves

| Problem | SpecAnchor's Answer |
|---------|-------------------|
| AI-generated code doesn't follow team standards | Global Spec provides "constitutional" constraints that AI must follow |
| Different developers have inconsistent styles on the same module | Module Spec defines interface contracts and design conventions |
| The "why" behind code changes gets lost | Task Spec records the intent and decisions behind every change |
| Spec and code go out of sync (decay) | Alignment detection checks Spec-code consistency |

## Design Principles

1. **Spec is cause, code is effect** — write Spec before code (forward flow); when code changes, check if Spec is stale (reverse flow)
2. **Don't aim for 100% coverage** — let the most critical modules have Specs first, progressively expand
3. **Don't lock in a writing tool** — SpecAnchor only handles "organization" (where, format, status), not "writing" (defaults to SDD-RIPER-ONE, replaceable with OpenSpec or any format)
4. **Global Spec ≤ 200 lines** — this is a physical constraint of AI context windows, enforcing conciseness
5. **Centralized Module Spec management** — stored in `.specanchor/modules/`, indexed to real module paths via `module-index.md`
6. **Full rewrite + git versioning** — Module Spec updates are full rewrites, with changes managed through `git diff` and Code Review
7. **Platform agnostic** — plain-text Skill, works with Cursor, Claude Code, Cline, and any AI tool that can read files
8. **Extension-based enhancement** — non-core features loaded on demand via Extensions, keeping core Skill's token budget lean

## Usage Recommendations by Role

### Team Engineers

Engineers are **full participants** in the SpecAnchor system.

**Daily workflow**:

```
1. Receive requirements
   ↓
2. "Start project"                            Start dev server (workflow extension)
   ↓
3. "Create task: <task name>"                 Create Task Spec
   ↓
4. (AI auto-loads Global + Module Spec)
   ↓
5. Develop following Task Spec (defaults to SDD-RIPER-ONE's RIPER flow)
   ↓
6. Development done, check if Module Spec needs updating
   ↓
7. "Commit code"                              Auto commit + push (workflow extension)
   ↓
8. "Submit code review"                       Create CR + quality check (workflow extension)
   ↓
9. "Check Spec alignment"                     Confirm Spec-code alignment
   ↓
10. Receive review feedback → fix → repeat 7-9
   ↓
11. "Stop project"                            Stop dev server (workflow extension)
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
| Use workflow commands | ✅ |
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

- Three-level Spec system (Global → Module → Task)
- Coverage detection + staleness detection
- Declarative Schema system (SDD-RIPER-ONE / OpenSpec / custom compatible)
- External Sources directory alias mapping
- Plain-text Skill, platform agnostic

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
