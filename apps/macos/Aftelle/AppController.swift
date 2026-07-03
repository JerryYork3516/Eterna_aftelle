import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var startupState: AppStartupState = .idle
    @Published private(set) var runtimeStatus = "Runtime status: not loaded"
    @Published private(set) var fixtureStatus = "DR fixture: not loaded"
    @Published private(set) var residentID = "resident_id: -"
    @Published private(set) var displayName = "display_name: -"
    @Published private(set) var diagnostics = ""
    @Published private(set) var sessionState = AppSessionState()
    @Published private(set) var avatarState = AppAvatarState()
    @Published private(set) var residentState = AppResidentState()
    @Published private(set) var traceState = RuntimeTraceViewState()
    @Published private(set) var clockState = RuntimeClockViewState()
    @Published private(set) var debugPanelState = DebugPanelViewState()
    @Published private(set) var runtimeState: AppRuntimeState = .idle

    private let orchestrationKernel: OrchestrationKernel
    private var loadedResidentID = ""
    private var loadedSessionID = ""
    private var dialogueEntries: [AppDialogueEntryState] = []

    init() {
        self.orchestrationKernel = OrchestrationKernel()
    }

    init(orchestrationKernel: OrchestrationKernel) {
        self.orchestrationKernel = orchestrationKernel
    }

    func start() {
        startupState = .loading

        let restoreResult = orchestrationKernel.restoreMostRecentSession()
        if restoreResult.didRestore {
            loadedResidentID = restoreResult.residentID
            loadedSessionID = restoreResult.sessionID
            dialogueEntries = restoreResult.dialogueEntries.map {
                AppDialogueEntryState(
                    id: "\($0.role)-\(Int($0.timestamp.timeIntervalSince1970))",
                    role: $0.role,
                    text: $0.text,
                    timestamp: ISO8601DateFormatter().string(from: $0.timestamp)
                )
            }
            runtimeStatus = "Runtime status: session restored"
            fixtureStatus = "DR fixture: loaded"
            residentID = "resident_id: \(restoreResult.residentID.isEmpty ? "-" : restoreResult.residentID)"
            displayName = "display_name: restored session"
            sessionState = AppSessionState(
                residentID: restoreResult.residentID,
                sessionID: restoreResult.sessionID,
                lastUserInput: restoreResult.lastUserInput,
                lastResidentOutput: restoreResult.lastResidentOutput,
                lastActivity: restoreResult.lastActivity,
                shutdownState: restoreResult.shutdownState.rawValue,
                recoveryRequired: restoreResult.recoveryRequired,
                recoveredAt: restoreResult.recoveredAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                dialogueEntries: dialogueEntries
            )
            residentState = AppResidentState(
                residentID: restoreResult.residentID,
                sessionID: restoreResult.sessionID,
                lifecycleStatus: restoreResult.recoveryRequired ? "recovered" : "restored",
                presence: "available",
                lastActivitySummary: restoreResult.lastActivity,
                lastUpdatedAt: ISO8601DateFormatter().string(from: Date()),
                avatarMode: "idle"
            )
            avatarState = AppAvatarState(residentID: restoreResult.residentID, displayName: "restored session")
            diagnostics = restoreResult.recoveryRequired ? "Session restored after unclean shutdown" : "Session restored"
            traceState = RuntimeTraceViewState(summary: diagnostics, entries: [])
            refreshDebugPanelState(shutdownState: restoreResult.shutdownState.rawValue, recoveryRequired: restoreResult.recoveryRequired, recoveredAt: restoreResult.recoveredAt.map { ISO8601DateFormatter().string(from: $0) } ?? "")
            startupState = .loaded
            return
        }

        guard let fixtureURL = Bundle.main.url(forResource: "Freezev03.calibration_fixture", withExtension: "json") else {
            applyFailure(runtimeMessage: "Runtime status: DR load failed", diagnosticsMessage: "Fixture not found")
            return
        }

        guard let fixtureData = try? Data(contentsOf: fixtureURL) else {
            applyFailure(runtimeMessage: "Runtime status: DR load failed", diagnosticsMessage: "Fixture unreadable")
            return
        }

        let result = orchestrationKernel.loadResident(fixtureData: fixtureData)
        loadedResidentID = result.isLoaded ? result.residentID : ""
        loadedSessionID = result.sessionID?.rawValue ?? ""
        runtimeStatus = "Runtime status: \(result.statusMessage)"
        fixtureStatus = result.isLoaded ? "DR fixture: loaded" : "DR fixture: not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
        sessionState = AppSessionState(
            residentID: result.residentID,
            sessionID: loadedSessionID,
            lastActivity: result.residentState?.lastActivitySummary ?? ""
        )
        dialogueEntries = []
        avatarState = result.avatarState.map {
            AppAvatarState(
                residentID: $0.residentID,
                displayName: $0.displayName,
                mode: $0.mode,
                presence: $0.presence,
                moodHint: $0.moodHint,
                activityHint: $0.activityHint,
                particleHint: $0.particleHint
            )
        } ?? AppAvatarState(residentID: result.residentID, displayName: result.displayName)
        residentState = result.residentState.map {
            AppResidentState(
                residentID: $0.residentID,
                sessionID: $0.sessionID,
                lifecycleStatus: $0.lifecycleStatus,
                presence: $0.presence,
                lastActivitySummary: $0.lastActivitySummary,
                lastUpdatedAt: ISO8601DateFormatter().string(from: $0.lastUpdatedAt),
                avatarMode: $0.avatarMode ?? ""
            )
        } ?? AppResidentState(residentID: result.residentID, sessionID: result.sessionID?.rawValue ?? "")
        diagnostics = result.diagnostics
        traceState = RuntimeTraceViewState(summary: result.diagnostics, entries: [])
        refreshDebugPanelState()
        startupState = result.isLoaded ? .loaded : .failed
    }

    func step(inputText: String) -> RuntimeStepResponse {
        let response = orchestrationKernel.step(residentID: loadedResidentID, inputText: inputText)
        runtimeState = response.cancellationState.isCancelled ? (response.cancellationState.reason == .interrupted ? .interrupted : .cancelled) : .running
        dialogueEntries.append(
            AppDialogueEntryState(
                id: "user-\(dialogueEntries.count)",
                role: "user",
                text: inputText,
                timestamp: ISO8601DateFormatter().string(from: response.residentState.lastUpdatedAt)
            )
        )
        dialogueEntries.append(
            AppDialogueEntryState(
                id: "resident-\(dialogueEntries.count)",
                role: "resident",
                text: response.outputText,
                timestamp: ISO8601DateFormatter().string(from: response.residentState.lastUpdatedAt)
            )
        )
        if dialogueEntries.count > 20 {
            dialogueEntries = Array(dialogueEntries.suffix(20))
        }
        residentState = AppResidentState(
            residentID: response.residentState.residentID,
            sessionID: response.residentState.sessionID,
            lifecycleStatus: response.residentState.lifecycleStatus,
            presence: response.residentState.presence,
            lastActivitySummary: response.residentState.lastActivitySummary,
            lastUpdatedAt: ISO8601DateFormatter().string(from: response.residentState.lastUpdatedAt),
            avatarMode: response.residentState.avatarMode ?? ""
        )
        sessionState = AppSessionState(
            residentID: response.residentState.residentID,
            sessionID: response.residentState.sessionID,
            lastUserInput: inputText,
            lastResidentOutput: response.outputText,
            lastActivity: response.residentState.lastActivitySummary,
            dialogueEntries: dialogueEntries
        )
        loadedSessionID = response.residentState.sessionID
        traceState = RuntimeTraceViewState(
            summary: response.diagnostics.cancellationState,
            entries: response.traceEvents.enumerated().map {
                RuntimeTraceEntryViewState(id: "\($0.offset)", type: $0.element.type.rawValue, message: $0.element.message)
            }
        )
        refreshDebugPanelState()
        return response
    }

    func cancelCurrentStep() {
        orchestrationKernel.cancelCurrentStep()
        runtimeState = .cancelled
    }

    func interrupt() {
        orchestrationKernel.interrupt()
        runtimeState = .interrupted
    }

    func runtimeTick() {
        let response = orchestrationKernel.runtimeTick()
        clockState = RuntimeClockViewState(
            tickCount: response.clockState.tickCount,
            lastTickSummary: response.traceEvent.message
        )
        traceState = RuntimeTraceViewState(
            summary: response.diagnostics.cancellationState,
            entries: [
                RuntimeTraceEntryViewState(id: "tick-\(response.clockState.tickCount)", type: response.traceEvent.type.rawValue, message: response.traceEvent.message)
            ]
        )
        refreshDebugPanelState()
    }

    func persistCurrentSessionIfPossible() {
        guard !loadedResidentID.isEmpty, !loadedSessionID.isEmpty else { return }
        orchestrationKernel.saveCurrentSession(
            lastUserInput: sessionState.lastUserInput,
            lastResidentOutput: sessionState.lastResidentOutput,
            lastActivity: sessionState.lastActivity,
            dialogueEntries: dialogueEntries.compactMap {
                guard let timestamp = ISO8601DateFormatter().date(from: $0.timestamp) else { return nil }
                return RuntimeDialogueEntryState(role: $0.role, text: $0.text, timestamp: timestamp)
            }
        )
    }

    func markSessionUncleanIfPossible() {
        guard !loadedResidentID.isEmpty, !loadedSessionID.isEmpty else { return }
        orchestrationKernel.markSessionUnclean(
            lastUserInput: sessionState.lastUserInput,
            lastResidentOutput: sessionState.lastResidentOutput,
            lastActivity: sessionState.lastActivity,
            dialogueEntries: dialogueEntries.map {
                RuntimeDialogueEntryState(
                    role: $0.role,
                    text: $0.text,
                    timestamp: ISO8601DateFormatter().date(from: $0.timestamp) ?? Date()
                )
            }
        )
    }

    private func refreshDebugPanelState(shutdownState: String = "unknown", recoveryRequired: Bool = false, recoveredAt: String = "") {
        debugPanelState = DebugPanelViewState(
            residentID: residentState.residentID,
            sessionID: sessionState.sessionID.isEmpty ? loadedSessionID : sessionState.sessionID,
            lifecycleStatus: residentState.lifecycleStatus,
            presence: residentState.presence,
            avatarMode: avatarState.mode,
            lastActivitySummary: residentState.lastActivitySummary,
            traceSummary: traceState.summary,
            tickCount: clockState.tickCount,
            clockStatus: clockState.lastTickSummary.isEmpty ? "noop" : clockState.lastTickSummary,
            cancellationStatus: runtimeState == .idle ? "none" : String(describing: runtimeState),
            shutdownState: shutdownState,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt
        )
    }

    private func applyFailure(runtimeMessage: String, diagnosticsMessage: String) {
        runtimeStatus = runtimeMessage
        fixtureStatus = "DR fixture: not loaded"
        loadedResidentID = ""
        loadedSessionID = ""
        residentID = "resident_id: -"
        displayName = "display_name: -"
        sessionState = AppSessionState()
        dialogueEntries = []
        avatarState = AppAvatarState()
        traceState = RuntimeTraceViewState(summary: diagnosticsMessage, entries: [])
        runtimeState = .idle
        diagnostics = diagnosticsMessage
        refreshDebugPanelState()
        startupState = .failed
    }
}
