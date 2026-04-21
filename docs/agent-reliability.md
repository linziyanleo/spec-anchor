# Agent Reliability

This milestone proves a narrower claim than the alpha usage-proof release:

- SpecAnchor can tell an agent which specs to read.
- SpecAnchor can keep that read plan within an explicit budget.
- SpecAnchor can explain missing coverage instead of hiding it.

It does not claim to make code quality automatic.

## Core Loop

1. Run `specanchor-boot.sh`.
2. Choose `⚡ lightweight` or `standard Task Spec workflow`.
3. Run `specanchor-assemble.sh` with target files and task intent.
4. Read the listed specs before editing code.
5. Run verification and report anchors used.

## Key References

- [Agent Contract](../references/agents/agent-contract.md)
- [Minimal Agent Loop](examples/minimal-agent-loop.md)
- [Missing Module Coverage](examples/missing-module-coverage.md)
- [Parasitic Source Resolution](examples/parasitic-source-resolution.md)
