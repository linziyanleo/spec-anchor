# Parasitic OpenSpec Project

This example proves that SpecAnchor can govern an existing external spec directory without moving those files into `.specanchor/`.

## Initial Files

- `anchor.yaml`
- `specs/auth.md`
- `specs/billing.md`
- `src/auth/login.md`
- `src/billing/invoice.md`
- `expected/README.md`

The usage-proof smoke test copies this directory into a temp workspace, installs the skill, then runs `boot`, `doctor --strict`, and `resolve --format=json`.

## What Success Looks Like

- Boot reports `parasitic` mode.
- The `specs/` directory is listed as an external source.
- `doctor --strict` exits `0`.
- `resolve --format=json` returns valid JSON and points back to the relevant file under `specs/`.
- No files are moved out of `specs/`.
