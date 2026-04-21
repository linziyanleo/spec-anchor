# Changelog

## v0.4.0-alpha.1 — Public Prerelease

### Highlights

- Repo is self-bootable in full mode.
- Public shell tests, fresh-clone smoke, and consumer-install smoke are in place.
- Command entry semantics are now natural-language-first, with `SA:` documented as optional shorthand.
- `anchor.local.yaml` overlay support landed for maintainer-local sources and scalar overrides.
- README / WHY entrypoints and public docs links are aligned for the current file layout.

### Install Verification

```bash
SPECANCHOR_SKILL_DIR="$PWD" bash scripts/specanchor-boot.sh --format=summary
bash scripts/specanchor-doctor.sh --strict
bash tests/run.sh
git diff --check
```

### Known Limitations

- This is still an alpha release; public interfaces may change before `v0.4.0`.
- `anchor.local.yaml` is intentionally narrow: public scripts merge `sources` by append and read scalar fields with local precedence; it is not a generic YAML deep-merge layer.
- GitHub Release publication and repository About metadata still depend on syncing this repo state to the public GitHub mirror.
