# SpecAnchor

[中文](README.md) | [Why SpecAnchor](WHY_EN.md)

> Spec is the anchor, code is the ship. With the anchor set, the ship won't drift.

SpecAnchor is an **AI Skill** that provides a three-level Spec management system (Global → Module → Task), automatically loading team standards and module contracts before AI generates code.

It's a "library" for Specs, not a "writing tool" — compatible with SDD-RIPER-ONE, OpenSpec, and any Markdown-based Spec format. It anchors not just AI context, but human understanding of code.

It only handles Spec governance. Commit/review/server lifecycle workflow actions belong to a separate skill.

---

## Core Concept

Unlike RAG-style "re-derive from code every time", SpecAnchor adopts a **compiled knowledge** paradigm — pre-compiling code insights into persistent Spec files that AI loads before coding. Write once, reuse repeatedly, knowledge compounds over time. (See [WHY_EN.md §Compiled Knowledge vs Retrieved Knowledge](WHY_EN.md#compiled-knowledge-vs-retrieved-knowledge))

```
SpecAnchor = Organization layer (where Specs live, their health, who can modify them)
Writing Protocol = Pluggable (SDD-RIPER-ONE / OpenSpec / Custom Schema)
```

**Three-Level Spec System**:

| Level | Name | Content | Change Frequency | Path |
|-------|------|---------|-----------------|------|
| L1 | Global Spec | Coding standards, architecture conventions, project config | Quarterly | `.specanchor/global/` |
| L2 | Module Spec | Interface contracts, business rules, code structure | Per sprint | `.specanchor/modules/` |
| L3 | Task Spec | Goals, plans, execution logs for each change | Per task | `.specanchor/tasks/` |

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
