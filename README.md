<div align="center">
  <img src="assets/SpecAnchor_logo.png" alt="SpecAnchor Logo" width="140" />
</div>

<h1 align="center">SpecAnchor</h1>

<p align="center">
  <em>Spec is the anchor, code is the ship. With the anchor set, the ship won't drift.</em>

</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" />
  <img src="https://img.shields.io/badge/version-0.4.0-brightgreen.svg" alt="Version 0.4.0" />
  <img src="https://img.shields.io/badge/Claude%20Code-%E2%9C%93-orange" alt="Claude Code" />
  <img src="https://img.shields.io/badge/Cursor-%E2%9C%93-1e90ff" alt="Cursor" />
  <img src="https://img.shields.io/badge/Codex-%E2%9C%93-lightgrey" alt="Codex" />
  <img src="https://img.shields.io/badge/Gemini-%E2%9C%93-blueviolet" alt="Gemini" />
</p>

<p align="center">
  <a href="README.md">🇬🇧 English</a> ·
  <a href="README_CN.md">🇨🇳 中文</a> ·
  <a href="WHY.md">📖 WHY</a> ·
  <a href="SKILL.md">🧭 SKILL</a>
</p>

---

> Spec is the anchor, code is the ship. With the anchor set, the ship won't drift.

**Your AI agent re-derives your team's conventions from source on every run. SpecAnchor makes that the last time.**

SpecAnchor compiles your coding standards, module contracts, and change history into persistent Spec files — loaded automatically *before* the AI writes a single line of code. Write once, reuse forever: knowledge compounds instead of evaporating at the end of each session.

It's a **library for Specs, not a writing tool** — pluggable with SDD-RIPER-ONE, OpenSpec, or your own schema. Specs anchor not only AI context, but human understanding of the code.

---

## What Makes SpecAnchor Different

Most Spec tools teach you *how to write Specs*. SpecAnchor handles what nobody else does:

- **📚 Compiled knowledge, not retrieval** — Specs are pre-compiled and loaded; AI never re-derives conventions from source.
- **🧭 3-tier governance baked in** — Global (standards) · Module (contracts) · Task (change log), each with its own cadence.
- **🩺 Spec health as a first-class concern** — coverage, staleness, role permissions, module index. OpenSpec / SDD-RIPER-ONE / spec-kit don't ship any of this.
- **🔌 Protocol-agnostic** — write Specs in SDD-RIPER-ONE, OpenSpec, or your own schema. SpecAnchor governs the *organization*, not the *authoring*.
- **🪢 Parasitic mode** — already using OpenSpec or spec-kit? Point SpecAnchor at your existing directory — no migration needed.

---

## Three-Level Spec System

| Level | Name | Content | Change Frequency | Path |
|-------|------|---------|-----------------|------|
| L1 | Global Spec | Coding standards, architecture conventions, project config | Quarterly | `.specanchor/global/` |
| L2 | Module Spec | Interface contracts, business rules, code structure | Per sprint | `.specanchor/modules/` |
| L3 | Task Spec | Goals, plans, execution logs for each change | Per task | `.specanchor/tasks/` |

> Unlike RAG-style "re-derive from code every time", SpecAnchor adopts a **compiled knowledge** paradigm — pre-compiling code insights into persistent Spec files that AI loads before coding. See [WHY_EN.md §Compiled Knowledge vs Retrieved Knowledge](WHY_EN.md#compiled-knowledge-vs-retrieved-knowledge).

---

## Quick Install

### Cursor

```bash
# Project-level install (rsync excludes dev-only files)
rsync -a --exclude-from=/path/to/SpecAnchor/.skillexclude /path/to/SpecAnchor/ your-project/.cursor/skills/specanchor/

# Or symlink (recommended for development)
ln -s /path/to/SpecAnchor your-project/.cursor/skills/specanchor

# Or global install
rsync -a --exclude-from=/path/to/SpecAnchor/.skillexclude /path/to/SpecAnchor/ ~/.cursor/skills/specanchor/
```

### Claude Code

```bash
rsync -a --exclude-from=/path/to/SpecAnchor/.skillexclude /path/to/SpecAnchor/ your-project/.agents/skills/specanchor/
```

Add to `CLAUDE.md` or `AGENTS.md`: `Use SpecAnchor for Spec management: see .agents/skills/specanchor/SKILL.md`

### Other AI Tools

SpecAnchor is a plain-text Skill that works with any AI tool that can read files. Use `rsync -a --exclude-from=.skillexclude` to copy to your project, then reference `SKILL.md` in your AI tool's configuration.

> **Why rsync instead of cp -r?** The skill repo contains dev-only directories (`.specanchor/`, `mydocs/`, `tests/`) that should not be copied into target projects. `.skillexclude` declares which paths to exclude. Without rsync, use `cp -r` then manually remove `.specanchor/`, `mydocs/`, `tests/` from the target.

---

## Recommended Workflow

### First Time Setup

```
"Initialize SpecAnchor"          → Creates anchor.yaml + optional .specanchor/ + auto-generates Global Specs
                                   (auto-detects existing spec systems and writes sources config)
"Create module spec for auth"    → Create Module Spec on demand when touching a module
```

### Daily Development

```
"Create task: add login captcha" → Auto-loads Global + Module Spec, creates Task Spec
 ↓ Develop following Task Spec
"Check Spec alignment"           → Spec-code consistency check
```

### Command Quick Reference

| Intent | Example Phrases |
|--------|----------------|
| Initialize | "Initialize SpecAnchor" / "Set up project info" |
| Global Spec | "Generate coding standards" / "Generate architecture conventions" |
| Module Spec | "Create auth module spec" / "Infer module spec from code" |
| Task | "Create task: feature X" |
| Check | "Check Spec alignment" / "Coverage report" / "Are module specs stale?" |
| Import | "Import OpenSpec config" / "Migrate from OpenSpec" |

---

## Usage Strategy

### Team Standards

| Action | Recommended Frequency | Owner |
|--------|----------------------|-------|
| Global Spec update | Quarterly | Engineers (Peer Review) |
| Module Spec creation | When touching a module | Engineers / Contractors (need Review) |
| Task Spec creation | Every task | Engineers & Contractors |
| Coverage check | End of each Sprint | Engineers |
| Spec-code alignment | On MR submission | Auto / Manual |

### Progressive Coverage

Don't aim for 100% coverage. Let the most critical modules have Specs first. See [Cold Start Guide](WHY_EN.md#cold-start-guide-for-existing-projects).

---

## Relationship with SDD-RIPER-ONE / OpenSpec

SpecAnchor only handles "organization", not "writing" — through a declarative Schema system, it's compatible with any Spec format:

| Writing Protocol | Philosophy | Description | Configuration |
|-----------------|-----------|-------------|---------------|
| **SDD-RIPER-ONE** (default) | strict | Research → Plan (gate) → Execute → Review | Default, no config needed |
| **OpenSpec** | fluid | Proposal → Delta Specs → Design → Tasks | `writing_protocol.schema: "openspec-compat"` |
| **Custom** | user-defined | Create under `.specanchor/schemas/` | `writing_protocol.schema: "<name>"` |

### OpenSpec Compatibility

Existing OpenSpec projects can map the `openspec/` directory into SpecAnchor governance via `sources`, without moving any files:

```yaml
# anchor.yaml (project root)
specanchor:
  sources:
    - path: "openspec/specs"
      type: "openspec"
      maps_to: module_specs
      governance:
        stale_check: true
        frontmatter_inject: false
    - path: "openspec/changes"
      type: "openspec"
      maps_to: task_specs
      exclude: ["archive"]
      governance:
        stale_check: true
```

Use the "Import OpenSpec config" command to auto-generate this configuration.

### Compatible Spec Systems

SpecAnchor supports governing multiple spec systems, auto-detected during initialization:

| System | Detection Path | Description |
| ------ | -------------- | ----------- |
| OpenSpec | `openspec/` | Spec-Driven Development framework |
| spec-kit | `specs/` | Generic spec directory |
| mydocs | `mydocs/specs/` | SDD-RIPER-ONE standalone output |
| qoder | `.qoder/specs/` | Qoder AI framework |
| custom | user-specified | Any Markdown spec directory |

**Two operating modes**:

- **full** — Has `.specanchor/` with own Spec system + optional external source governance
- **parasitic** — No `.specanchor/`, pure governance of existing spec systems (staleness detection + scanning)

### SpecAnchor's Unique Capabilities

Neither OpenSpec nor SDD-RIPER-ONE provides these governance features:

- **Spec coverage detection** — which modules have Specs and which don't
- **Spec staleness detection** — which Specs are outdated (code changed but Spec not synced)
- **Role permission matrix** — engineer vs contractor Spec operation permissions
- **Module index** — `module-index.md` centralized index of all Module Specs

---

## Directory Structure

### Skill (this repo)

```
SpecAnchor/
├── SKILL.md                     ← Skill entry point
├── references/
│   ├── specanchor-protocol.md   ← Core protocol
│   ├── commands/                ← Command definitions (loaded on demand)
│   ├── schemas/                 ← Writing protocol Schema definitions
│   └── *.md                    ← Templates and reference files
└── scripts/
    ├── specanchor-init.sh       ← Initialization script (dirs + config)
    ├── specanchor-boot.sh       ← Boot check script
    ├── specanchor-status.sh     ← Status report script
    ├── specanchor-index.sh      ← Index generation script
    ├── specanchor-check.sh      ← Alignment detection script
    ├── frontmatter-inject.sh    ← Frontmatter injection
    └── frontmatter-inject-and-check.sh ← Injection + detection combo
```

### After Installation (full mode)

```
your-project/
├── anchor.yaml                  ← Configuration (project root, single entry point)
├── .specanchor/                 ← Data directory only
│   ├── global/                  ← L1: Global Spec (≤200 lines)
│   ├── modules/                 ← L2: Module Spec (centralized)
│   ├── module-index.md          ← Module index
│   ├── tasks/                   ← L3: Task Spec (grouped by module)
│   ├── archive/                 ← Completed task archive
│   ├── schemas/                 ← User custom Schemas (optional)
│   └── scripts/                 ← Auto-generated scan scripts
└── src/
```

### After Installation (parasitic mode)

```
your-project/
├── anchor.yaml                  ← Configuration (only this file)
├── .specanchor/
│   └── scripts/                 ← Auto-generated scan scripts
├── specs/                       ← Existing spec system (untouched)
└── src/
```

---

## Configuration

`anchor.yaml` in the project root controls SpecAnchor's behavior. Full config reference in `references/specanchor-protocol.md` Appendix A.

Key settings:

```yaml
specanchor:
  version: "0.4.0"
  mode: "full"                      # full | parasitic
  sources:                          # External spec systems (optional)
    - path: "specs/"
      type: "spec-kit"
      governance:
        stale_check: true
  writing_protocol:
    schema: "sdd-riper-one"         # Writing protocol: sdd-riper-one | openspec-compat | custom
  coverage:
    scan_paths: ["src/modules/**"]  # Coverage scan scope
  check:
    stale_days: 14                  # Spec staleness threshold (days)
    outdated_days: 30               # Spec severe staleness threshold (days)
```

---

## License

MIT
