# Expected Generated Files

After running `specanchor-init.sh --mode=full`, the temp project should contain:

- `anchor.yaml`
- `.specanchor/global/architecture.spec.md`
- `.specanchor/global/coding-standards.spec.md`
- `.specanchor/global/project-setup.spec.md`
- `.specanchor/modules/`
- `.specanchor/tasks/`
- `.specanchor/archive/`
- `.specanchor/scripts/`
- `.specanchor/spec-index.md`
- `.specanchor/project-codemap.md`

The starter Global Specs are intentionally generic. They exist so a clean project can pass `boot`, `doctor --strict`, and `validate` before the first project-specific refinement pass.
