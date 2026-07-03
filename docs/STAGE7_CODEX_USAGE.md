# Stage 7 Codex Usage

Use this file to record each Codex task before closing the loop.

## Record Template

- Stage:
- Date:
- Task:
- Read scope:
- Changed files:
- Verification:
- Token note:
- Follow-up:

## 7.1-livestate-doc-gate

- Stage: 7.1
- Date: 2026-07-02
- Task: Add Stage 7 live-state feature gate and align planning/boundary docs.
- Read scope: `AGENTS.md`, `CLAUDE.md`, `docs/03_dev_plan.md`, `docs/aftelle_runtime_boundary.md`, `docs/STAGE7_CODEX_USAGE.md`.
- Changed files: `docs/feature_livestate.md`, `AGENTS.md`, `CLAUDE.md`, `docs/03_dev_plan.md`, `docs/aftelle_runtime_boundary.md`, this usage log.
- Verification: documentation-only change; checked git diff and searched for `feature_livestate` references.
- Token note: do not duplicate the full 12-card table across plan/boundary docs.
- Follow-up: update Runtime API / DR contract only when implementing the specific feature card.

## 7.0-CAL-002

- Stage: 7.0-CAL-002
- Date: 2026-07-02
- Task: Empty Xcode App bootstrap.
- Read scope: `AGENTS.md`, `docs/04_code_standards.md`, `docs/05_dev_guide.md`, `DEVLOG.md`, current `apps/macos` file list.
- Changed files: new `apps/macos/Aftelle/` SwiftUI app project, `DEVLOG.md`, this usage log.
- Verification: `xcodebuild -project apps/macos/Aftelle/Aftelle.xcodeproj -scheme Aftelle -destination 'platform=macOS' -derivedDataPath /tmp/aftelle-cal-002-derived build` passed; built `Aftelle.app` launched and quit successfully; architecture guard and secret guard passed.
- Token note: keep Xcode output scoped; prefer one final build after file creation.
- Follow-up: none yet.

## 7.0-CAL-003

- Stage: 7.0-CAL-003
- Date: 2026-07-02
- Task: RuntimeCore skeleton.
- Read scope: `README.md`, `DEVLOG.md`, `docs/stage7_entry_gate.md`, `docs/runtime_api_contract.md`, `docs/aftelle_runtime_boundary.md`, `docs/dr_contract_v0_3.md`, `docs/provider_profile_contract.md`, `docs/02_architecture.md`, `docs/04_code_standards.md`, `docs/05_dev_guide.md`.
- Changed files: `apps/macos/RuntimeCore/*.swift`, `DEVLOG.md`, this usage log.
- Verification: xcodebuild -list passed; architecture_guard passed; secret_guard passed; xcodebuild build passed with custom -derivedDataPath.
- Token note: keep RuntimeCore stub minimal; do not wire UI or provider paths.
- Follow-up: Ready for CAL-004 load-dr minimal path.

## 7.0-CAL-004

- Stage: 7.0-CAL-004
- Date: 2026-07-02
- Task: load-dr minimal path
- Changed files: apps/macos/RuntimeCore/RuntimeCore.swift, apps/macos/RuntimeCore/DRLoader.swift, apps/macos/Aftelle/ContentView.swift
- Verification: xcodebuild -list passed; architecture_guard passed; secret_guard passed; build passed with custom -derivedDataPath.
- Token note: keep DR load minimal; no provider, no mock step, no trace display.
- Follow-up: 7.0-CAL-005 mock step path.

## 7.0.5

- Stage: 7.0.5
- Date: 2026-07-02
- Task: mock step path
- Changed files: apps/macos/RuntimeCore/RuntimeCore.swift, apps/macos/RuntimeCore/ExecutionEngine.swift, apps/macos/RuntimeCore/ProviderRouter.swift, apps/macos/RuntimeCore/TraceRecorder.swift, apps/macos/RuntimeCore/VisualStateMapper.swift, apps/macos/Aftelle/ContentView.swift
- Verification: xcodebuild -list passed; architecture_guard passed; secret_guard passed; build passed with custom -derivedDataPath.
- Token note: keep mock step local; no real provider, no trace UI.
- Follow-up: Stage 7.0.6 trace display.

## 7.0.6

- Stage: 7.0.6
- Date: 2026-07-02
- Task: trace + visual_state display
- Changed files: apps/macos/RuntimeCore/RuntimeCore.swift, apps/macos/RuntimeCore/ExecutionEngine.swift, apps/macos/RuntimeCore/TraceRecorder.swift, apps/macos/RuntimeCore/VisualStateMapper.swift, apps/macos/Aftelle/ContentView.swift
- Verification: xcodebuild -list passed; architecture_guard passed; secret_guard passed; build passed with custom -derivedDataPath.
- Token note: keep trace display minimal; no real provider, no DR writes.
- Follow-up: Stage 7.0.7 polish.

## 7.0.6-fix

- Stage: 7.0.6-fix
- Date: 2026-07-02
- Task: pre-review fixes
- Changed files: apps/macos/Aftelle/ContentView.swift, apps/macos/RuntimeCore/RuntimeCore.swift, apps/macos/RuntimeCore/DRLoader.swift, apps/macos/RuntimeCore/ExecutionEngine.swift, apps/macos/Aftelle/Aftelle.xcodeproj/project.pbxproj, docs/STAGE7_CODEX_USAGE.md, DEVLOG.md, apps/macos/Aftelle/Fixtures/Freezev03.calibration_fixture.json
- Verification: build passed with custom -derivedDataPath; architecture_guard passed; secret_guard passed.
- Token note: keep calibration fixture minimal and safe; no real .digital_resident.
- Follow-up: none.

## 7.0.6-fix-log-cleanup

- Stage: 7.0.6-fix
- Date: 2026-07-02
- Task: log cleanup
- Changed files: DEVLOG.md, docs/STAGE7_CODEX_USAGE.md
- Verification: not rerun per request.
- Token note: keep logs aligned with current 7.0 calibration state.
- Follow-up: none.

## 7.0-final-review-fix

- Stage: 7.0 final review fix
- Date: 2026-07-02
- Task: align calibration fixture and DRLoader with DR v0.3 key fields.
- Changed files: apps/macos/Aftelle/Fixtures/Freezev03.calibration_fixture.json, apps/macos/RuntimeCore/DRLoader.swift, apps/macos/Eterna_aftelleTests/Eterna_aftelleTests.swift, DEVLOG.md, this usage log.
- Verification: JSON lint passed; Aftelle build passed; architecture_guard passed; secret_guard passed; calibration unit test passed during full Eterna_aftelle test run, while old UI test runner failed to initialize automation mode.
- Token note: keep final review fix narrow; avoid old UI test scheme for routine calibration checks.
- Follow-up: use Aftelle scheme for manual Stage 7.0 verification.

## 7.0-app-cleanup

- Stage: 7.0 app cleanup
- Date: 2026-07-02
- Task: fix bundled fixture lookup and remove old Eterna template project files.
- Changed files: apps/macos/Aftelle/ContentView.swift, deleted old apps/macos/Eterna_aftelle* files, deleted top-level apps/macos/Aftelle.xcodeproj shell, DEVLOG.md, this usage log.
- Verification: JSON lint passed; Aftelle build passed; architecture_guard passed; secret_guard passed; no Eterna references remain under apps/macos.
- Token note: keep cleanup scoped to macOS app tree only.
- Follow-up: none.

## 7.1.1

- Stage: 7.1.1
- Date: 2026-07-02
- Task: Add Platform Adapter boundary.
- Read scope: `AGENTS.md`, `README.md`, `DEVLOG.md`, `docs/03_dev_plan.md`, `docs/04_code_standards.md`, `docs/STAGE7_CODEX_USAGE.md`, `apps/macos/RuntimeCore/*`, `apps/macos/Aftelle/Aftelle.xcodeproj/project.pbxproj`.
- Changed files: `apps/macos/RuntimeCore/PlatformAdapter.swift`, `apps/macos/Aftelle/Aftelle.xcodeproj/project.pbxproj`, `DEVLOG.md`, this usage log.
- Verification: `xcodebuild -project apps/macos/Aftelle/Aftelle.xcodeproj -scheme Aftelle -destination 'platform=macOS' -derivedDataPath /tmp/aftelle-7-1-1-derived build` passed; `tools/architecture_guard/check.sh` ok; `tools/secret_guard/check.sh` ok.
- Token note: keep platform boundary no-op and platform-independent.
- Follow-up: proceed to 7.1.2 desktop shell only.

## 7.1.2

- Stage: 7.1.2
- Date: 2026-07-02
- Task: Organize macOS desktop shell.
- Read scope: `AGENTS.md`, `README.md`, `DEVLOG.md`, `.cursor/rules/*`, `docs/03_dev_plan.md`, `docs/02_architecture.md`, `docs/aftelle_runtime_boundary.md`, `docs/04_code_standards.md`, `apps/macos/Aftelle/*`, `apps/macos/RuntimeCore/*`.
- Changed files: `apps/macos/Aftelle/AftelleApp.swift`, `apps/macos/Aftelle/ContentView.swift`, `DEVLOG.md`, this usage log.
- Verification: `xcodebuild -project apps/macos/Aftelle/Aftelle.xcodeproj -scheme Aftelle -destination 'platform=macOS' -derivedDataPath /tmp/aftelle-7-1-2-derived build` passed; `tools/architecture_guard/check.sh` ok; `tools/secret_guard/check.sh` ok.
- Token note: keep shell thin; do not add startup flow or provider wiring.
- Follow-up: 7.1.3 startup flow only when explicitly started.

## 7.1-DOC-APPLE-HOST-RESERVE

- Stage: 7.1-DOC-APPLE-HOST-RESERVE
- Date: 2026-07-03
- Task: Add document-only Apple ecosystem Host reserve boundary.
- Read scope: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*`, `README.md`, `DEVLOG.md`, `docs/02_architecture.md`, `docs/03_dev_plan.md`, `docs/04_code_standards.md`, `docs/aftelle_runtime_boundary.md`, `docs/stage7_entry_gate.md`, `docs/runtime_strategy.md`, this usage log.
- Changed files: documentation only; no Swift, project, DR schema, Runtime API, provider, token, or fixture files.
- Verification: `git diff --check`; architecture guard; secret guard; documentation grep for sensitive terms.
- Token note: keep this as Stage 7.1 doc reserve, not Stage 8 or multiplatform feature work.
- Follow-up: 7.1.18 checklist should include these Host reserve prohibitions.

## 7.1.18

- Stage: 7.1.18
- Date: 2026-07-03
- Task: Add Stage 7 forbidden checklist.
- Read scope: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*`, `README.md`, `DEVLOG.md`, `docs/03_dev_plan.md`, `docs/stage7_entry_gate.md`, `docs/feature_livestate.md`, `docs/STAGE7_CODEX_USAGE.md`, and referenced boundary/contract docs for verification only.
- Changed files: `docs/stage7_forbidden_checklist.md`, `AGENTS.md`, `CLAUDE.md`, `DEVLOG.md`, `docs/03_dev_plan.md`, `docs/stage7_entry_gate.md`, this usage log.
- Verification: `git diff --check`; architecture guard; secret guard; documentation grep for sensitive terms.
- Token note: keep this as document / PR checklist only; do not turn it into a script, lint, or code system.
- Follow-up: use checklist before Stage 7.1 Final Review and later Stage 7 tasks.
