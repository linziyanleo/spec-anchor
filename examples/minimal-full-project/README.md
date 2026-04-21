# Minimal Full Project

This example proves that SpecAnchor can initialize a clean project in `full` mode, create a starter governance baseline, and pass boot / doctor / validate without any external dependencies.

## Initial Files

- `src/auth/login.md`
- `expected/README.md`

The usage-proof smoke test installs SpecAnchor into a temp copy of this directory, runs `specanchor-init.sh --mode=full`, then verifies the generated config and `.specanchor/` layout.

## What Success Looks Like

- `anchor.yaml` is generated.
- `.specanchor/` is created with starter Global Specs.
- `specanchor-boot.sh --format=summary` exits `0`.
- `specanchor-doctor.sh --strict` exits `0`.
- `specanchor-validate.sh --format=summary` exits `0`.
- No missing-source `✗` lines are printed.

See `expected/README.md` for the generated files the smoke test checks.
