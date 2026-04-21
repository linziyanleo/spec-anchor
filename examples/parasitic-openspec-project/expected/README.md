# Expected Behavior

This example keeps its source-of-truth specs in `specs/`.

Successful usage-proof runs should show:

- `SpecAnchor Boot [parasitic]`
- `Sources:` including `specs/ [openspec-fixture]`
- `SpecAnchor Doctor [ok]`
- `specanchor-resolve.sh --format=json` returning anchors that reference `specs/auth.md` or `specs/billing.md`

SpecAnchor should not create or move files under `.specanchor/` for this example.
