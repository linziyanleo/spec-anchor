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

Green health is the bootstrap checkpoint, not the end of the authoring flow.

## What To Do Next

After the initial health checks pass:

- refine `project-setup`, `coding-standards`, and `architecture` so the starter Global Specs reflect the real project
- keep `⚡` for a small single-file change, and switch to `📋` plus a Task Spec for non-trivial work
- only start implementation after the relevant anchors and workflow gates are clear

See `expected/README.md` for the generated files the smoke test checks.
