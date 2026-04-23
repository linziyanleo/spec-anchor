<div align="center">
  <img src="assets/SpecAnchor_logo.png" alt="SpecAnchor Logo" width="140" />
</div>

<h1 align="center">SpecAnchor</h1>

<p align="center">
  <em>Spec is the anchor, code is the ship.</em>
</p>

<p align="center">
  <img src="assets/SpecAnchorHero_EN.png" alt="SpecAnchor Hero — Your Single Source of Truth for Specs" width="860" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" />
  <a href="https://github.com/linziyanleo/spec-anchor/actions/workflows/ci.yml">
    <img src="https://github.com/linziyanleo/spec-anchor/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
  <img src="https://img.shields.io/badge/version-0.4.0--beta.1-brightgreen.svg" alt="Version 0.4.0-beta.1" />
  <img src="https://img.shields.io/badge/Claude%20Code-%E2%9C%93-orange" alt="Claude Code" />
  <img src="https://img.shields.io/badge/Cursor-%E2%9C%93-1e90ff" alt="Cursor" />
  <img src="https://img.shields.io/badge/Codex-%E2%9C%93-lightgrey" alt="Codex" />
  <img src="https://img.shields.io/badge/Gemini-%E2%9C%93-blueviolet" alt="Gemini" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README_ZH.md">中文</a> ·
  <a href="WHY.md">Why</a> ·
  <a href="docs/INSTALL.md">Install</a> ·
  <a href="CONTRIBUTING.md">Contributing</a> ·
  <a href="SKILL.md">Skill</a>
</p>

---

## What SpecAnchor Is

**SpecAnchor is a three-tier spec system that loads itself.** It keeps your team's coding rules, module contracts, and task intents in `.specanchor/`, then automatically loads the relevant ones into your AI's context before any code is generated — and checks later whether the code still matches.

It ships a complete **spec-driven development** (SDD) authoring toolkit out of the box — the default `sdd-riper-one` schema gives you Research → Plan → Execute → Review gates — so **you don't need Spec-Kit or OpenSpec to use SpecAnchor**. If you already have an OpenSpec or custom spec directory, `parasitic` mode wraps it without migration. Keep your existing authoring, add SpecAnchor as the loader and anti-decay layer.

> **→ Curious about the design philosophy? Read [WHY.md](WHY.md).**

> **Warning**
> SpecAnchor writes `.specanchor/`, may create or update `anchor.yaml`, and may inject Markdown frontmatter. Try it on a clean branch first.

---

## See It In Action

A typical day-two interaction in Claude Code — refactoring the order module to support split-shipping (touches `orders`, `shipping`, `inventory`):

```text
You: Create task: refactor order module to support multi-address split shipping
     (touches orders, shipping, inventory)

Claude: [routes to specanchor_task → specanchor-check.sh coverage]
  ✅ covered:   src/orders/    (modules/orders.spec.md)
  ✅ covered:   src/shipping/  (modules/shipping.spec.md)
  ⚠️  uncovered: src/inventory/ → auto-inferring Module Spec draft
  [runs specanchor_infer]
  ✓ modules/inventory.spec.md  (status=draft, needs human review)

  ✓ .specanchor/tasks/_cross-module/2026-04-23_split-shipping.spec.md

  Assembly Trace:
    - Global: full → coding-standards, architecture
    - Module: full → orders, shipping, inventory (draft)
    - Task:   tasks/_cross-module/2026-04-23_split-shipping.spec.md
    - Schema: sdd-riper-one | Workflow: standard Task Spec

  Current phase: Research. Execute blocked until Plan is approved.

... (Research → Plan → Execute) ...

You: Check spec-code alignment

Claude: [runs specanchor-check.sh alignment]
  ✅ orders.spec.md    — aligned
  ⚠️  shipping.spec.md  — drift detected:
      ShipmentPolicy.split() signature ≠ code (code adds `region` param)
      → update spec or revert code
  ✅ inventory.spec.md (draft) — drift tolerated at draft stage
```

Three things happened that vanilla AI coding, Spec-Kit, and OpenSpec cannot do together:

1. **Relevant specs loaded before coding** — Global + three Module Specs resolved from file paths, reported as an Assembly Trace
2. **Coverage gap auto-filled** — the uncovered `inventory/` module triggered `specanchor_infer` to draft a Module Spec, keeping the system honest
3. **Spec ↔ code drift caught post-hoc** — `shipping.spec.md` flagged the signature mismatch, not against another spec file, but against actual source code

---

## The Three Tiers

| Tier | What's in it | Who writes it | When loaded |
|---|---|---|---|
| **Global Spec** | Architecture, coding standards, project setup — team-wide rules | Senior engineers, updated quarterly | Always, at boot |
| **Module Spec** | Interface contracts, design conventions, dependency boundaries for one module | Module owner, on-touch | When a task targets files under `module_path` |
| **Task Spec** | Intent, file changes, gates for one concrete change | Author of the task | Created per task, archived after done |

Each tier is a persistent, reviewable, git-versioned `.spec.md` file — not a runtime string.

---

## How SpecAnchor Compares

| Capability | Vanilla AI | Spec-Kit | OpenSpec | **SpecAnchor** |
|---|---|---|---|---|
| Ships an authoring workflow | — | ✅ 6 slash commands | ✅ artifact DAG (fluid-by-design) | ✅ `sdd-riper-one` built in, swappable |
| **Auto-loads relevant specs before AI writes code** | ❌ | ❌ (needs community "Memory Loader") | ❌ (only on `/opsx:*` trigger) | ✅ Assembly Trace every turn |
| **Global tier as first-class spec files** | — | ✅ `constitution.md` (single file) | ⚠️ only a `context:` string in `config.yaml` | ✅ multiple `global/*.spec.md`, each independently reviewed |
| **Persistent module tier** | — | ❌ features are branch-scoped and archived | ✅ `specs/<domain>/spec.md` | ✅ `modules/*.spec.md` + indexed via `module-index.md` |
| Task / change tier | ❌ | ✅ per-feature directory | ✅ `changes/<id>/` | ✅ `tasks/<module>/YYYY-MM-DD_*.spec.md` |
| Spec ↔ source-code drift detection | ❌ | ⚠️ `/speckit.analyze` compares spec↔plan↔tasks, not code | ⚠️ `/opsx:verify` is one-shot, optional | ✅ `specanchor-check` runs continuously against real files |
| Module coverage tracking | ❌ | ❌ | ❌ | ✅ `specanchor-check coverage` |
| Wrap an existing spec directory | — | ❌ expects to own `.specify/` | ❌ expects to own `openspec/` | ✅ `parasitic` mode |

Every tool here has *some* three-part structure — project context, persistent module contracts, per-change proposals. The real question is **how first-class each tier is**. Spec-Kit has a solid project and change tier but no persistent module layer. OpenSpec has solid module and change tiers but its project tier is a YAML string, not a reviewable spec file. SpecAnchor makes **all three tiers first-class, authored, indexed spec files** — which is what makes automatic resolution from file path + intent actually work.

---

## 60-Second Quick Start

The point of SpecAnchor is that you talk to your agent in natural language. Installation follows the same principle — hand the folder to any capable AI coding agent (Claude Code, Codex, Cursor, Gemini, …) and let it set itself up.

**1. Clone the skill anywhere on your machine.**

```bash
git clone https://github.com/linziyanleo/spec-anchor.git
```

**2. Open your target project in your agent and say:**

> Use the SpecAnchor skill at `<path-to-cloned-spec-anchor>`. Install it into this project in `full` mode and run boot.

The agent reads `SKILL.md`, copies the skill into the conventional skill directory for its platform (`.claude/skills/specanchor/`, `.cursor/skills/specanchor/`, …), runs `specanchor-init.sh --mode=full`, then boots. Success looks like an **Assembly Trace** printed back in chat:

```text
Assembly Trace:
  - Global: summary → architecture, coding-standards, project-setup
  - Module: none (nothing touched yet)
```

**3. From now on, talk to it in natural language** — "Create task: …", "Check spec-code alignment", "Generate coding standards from this codebase". No shell commands.

For manual install via `rsync`, symlink-based dev setups, or tool-specific skill paths, see [`docs/INSTALL.md`](docs/INSTALL.md).

---

## What Gets Created

After `specanchor-init.sh --mode=full`, your project gains:

```
anchor.yaml
.specanchor/
├── global/
│   ├── architecture.spec.md        # team-wide design conventions
│   ├── coding-standards.spec.md    # style, patterns, anti-patterns
│   └── project-setup.spec.md       # stack, env, tooling
├── modules/                         # filled in on-touch (never all at once)
├── tasks/                           # per-task, per-module spec files
├── archive/                         # completed tasks move here
├── module-index.md                  # path → module spec lookup
└── project-codemap.md               # high-level code map
```

The starter Global Specs are intentionally generic; your first real use-case is refining them against your actual codebase. See [`examples/minimal-full-project/`](examples/minimal-full-project/) for the full expected layout.

---

## Day 2 — Talking To It

SpecAnchor's user interface is natural language. Most prompts map to one internal command:

| What you say | What runs | What you get |
|---|---|---|
| *"Generate coding standards from the current codebase"* | `specanchor_global` | `.specanchor/global/coding-standards.spec.md` refined against real code |
| *"Create task: add pagination to order list"* | `specanchor_task` | coverage check → optional auto-infer → Task Spec + Assembly Trace |
| *"Check spec-code alignment"* | `specanchor_check` | drift report per Module Spec, with suggested action |
| *"Infer a module spec for `src/auth`"* | `specanchor_infer` | draft Module Spec generated from code, needs human review |
| *"What's the spec coverage?"* | `specanchor_status` | coverage % + module list with staleness timestamps |

The full intent-to-command mapping is in [`references/commands-quickref.md`](references/commands-quickref.md).

---

## Two Modes

- **`full` mode** — SpecAnchor owns `.specanchor/`, ships the authoring flow, and is the single source of truth. Use this if you're starting fresh or have no existing spec system. Example: [`examples/minimal-full-project/`](examples/minimal-full-project/)
- **`parasitic` mode** — SpecAnchor sits on top of an existing spec directory (e.g. OpenSpec's `openspec/specs/`) and provides only the loader + anti-decay layer. Your existing authoring tool still owns writing. Example: [`examples/parasitic-openspec-project/`](examples/parasitic-openspec-project/)

---

## Further Reading

- **[WHY.md](WHY.md)** — design philosophy, roadmap, compiled-vs-retrieved framing
- [`docs/INSTALL.md`](docs/INSTALL.md) — all install paths (Cursor, Claude Code, symlinks, other tools)
- [`SKILL.md`](SKILL.md) — runtime activation contract (what the AI reads at boot)
- [`docs/USAGE_PROOF.md`](docs/USAGE_PROOF.md) — end-to-end install verification
- [`docs/agent-reliability.md`](docs/agent-reliability.md) — how SpecAnchor behaves across Claude Code / Cursor / Codex / Gemini
- [`examples/agent-walkthrough/`](examples/agent-walkthrough/) — per-agent prompt templates
- [`FLOWCHART.md`](FLOWCHART.md) — full Skill invocation flow diagram

---

## Validation

From the repository root, the minimum maintainer checks are:

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
git diff --check
```

---

## Release Status

Current published prerelease: `v0.4.0-beta.1`.

- Release notes: [`docs/release/v0.4.0-beta.1.md`](docs/release/v0.4.0-beta.1.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for environment requirements, validation commands, and PR scope.

## License

Code is licensed under [MIT](LICENSE). Repository images are documented separately in [`assets/README.md`](assets/README.md).
