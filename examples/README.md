# SpecAnchor Examples

| Example | Mode | What it proves |
|---|---|---|
| `minimal-full-project` | `full` | Init creates a working `.specanchor/` baseline with starter Global Specs. |
| `parasitic-openspec-project` | `parasitic` | Existing external specs can be governed without migration. |
| `agent-walkthrough` | n/a | How to ask Codex, Claude Code, Cursor, and Qoder to use SpecAnchor before editing. |

## How to Run

```bash
bash tests/test_usage_proof.sh
```

## When to Use Each Example

- `minimal-full-project`: use this when you are starting from a clean repo and want SpecAnchor to own `.specanchor/` in `full` mode.
- `parasitic-openspec-project`: use this when you already have an external spec directory and only want SpecAnchor to govern it.
- `agent-walkthrough`: use this when you want copy-ready prompts for Codex, Claude Code, Cursor, or Qoder before editing files.
