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
- Changed files: `apps/macos/Aftelle/Aftelle/RuntimeCore/*.swift`, `DEVLOG.md`, this usage log.
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
