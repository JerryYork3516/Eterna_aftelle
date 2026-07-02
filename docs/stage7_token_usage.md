# Stage 7 Token Usage

> Purpose: keep Stage 7 spending visible enough to decide when to narrow scope.

## 7.0 Calibration

Date: 2026-07-02

Scope:
- Read: `AGENTS.md`, DR/Runtime contracts, code standards, minimal Xcode test files, guard scripts, and the head of `docs/Freezev03.digital_resident`.
- Changed: one calibration test, token usage note, DEVLOG entry.
- Deferred: DR loader, RuntimeCore implementation, Trace UI, 7.1 particle work.

Result:
- Real local fixture: `docs/Freezev03.digital_resident`.
- Synthetic fallback fixture removed.
- Calibration found a real DR/document gap: `lattice_config.attention` is `"self"` in Freezev03, not a 0-1 number.

Token note:
- Exact billed tokens are not exposed in this local Codex session.
- Transcript-visible estimate for 7.0 calibration: about 110k-140k tokens.
- Main cost driver was repeated full `xcodebuild test` output. Future Stage 7 work should prefer targeted tests first, then one final full build/test.
