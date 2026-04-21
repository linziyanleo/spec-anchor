# Contributing to SpecAnchor

Thanks for contributing. This repository is English-first for open-source contributors.

## Documentation Policy

- `README.md`, `CONTRIBUTING.md`, installation docs, and other contributor-facing open-source docs are authoritative in English.
- `README_ZH.md` is a convenience translation. Update it when public behavior changes, but if drift remains, the English docs win.
- When assets change, update [assets/README.md](assets/README.md) with provenance or licensing notes.

## Environment

- Bash 3.2+
- Git
- Python 3
- `rsync` recommended for install-path verification
- ShellCheck optional but useful

## Public Surface

Be deliberate when changing contributor-facing interfaces:

- `anchor.yaml`
- `.specanchor/` layout in `full` mode
- `SKILL.md`
- `references/`
- `scripts/*.sh`
- `tests/run.sh`
- `.skillexclude`

## Validation Before a PR

Run these commands from the repository root:

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
git diff --check
```

If you changed installation behavior, also verify the consumer install path described in [docs/INSTALL.md](docs/INSTALL.md).

## PR Scope

- Keep diffs surgical. Do not mix unrelated cleanup into behavior changes.
- Preserve current public behavior unless the PR intentionally changes it.
- If you change script flags, boot behavior, install boundaries, or contributor-facing docs, update the matching tests or docs in the same PR.
- If a change is directional or high-risk, capture the decision in the active `.specanchor` task note before merging.
