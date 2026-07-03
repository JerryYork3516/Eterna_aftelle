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
    @Published private(set) var traceState = RuntimeTraceViewState()
    @Published private(set) var runtimeState: AppRuntimeState = .idle

    private let orchestrationKernel: OrchestrationKernel
    private var loadedResidentID = ""

    init() {
        self.orchestrationKernel = OrchestrationKernel()
    }

    init(orchestrationKernel: OrchestrationKernel) {
        self.orchestrationKernel = orchestrationKernel
    }

    func start() {
        startupState = .loading

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
        runtimeStatus = "Runtime status: \(result.statusMessage)"
        fixtureStatus = result.isLoaded ? "DR fixture: loaded" : "DR fixture: not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
        sessionState = AppSessionState(
            residentID: result.residentID,
            sessionID: result.sessionID?.rawValue ?? ""
        )
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
        diagnostics = result.diagnostics
        traceState = RuntimeTraceViewState(summary: result.diagnostics, entries: [])
        startupState = result.isLoaded ? .loaded : .failed
    }

    func step(inputText: String) -> RuntimeStepResponse {
        let response = orchestrationKernel.step(residentID: loadedResidentID, inputText: inputText)
        runtimeState = response.cancellationState.isCancelled ? (response.cancellationState.reason == .interrupted ? .interrupted : .cancelled) : .running
        traceState = RuntimeTraceViewState(
            summary: response.diagnostics.cancellationState,
            entries: response.traceEvents.enumerated().map {
                RuntimeTraceEntryViewState(id: "\($0.offset)", type: $0.element.type.rawValue, message: $0.element.message)
            }
        )
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

    private func applyFailure(runtimeMessage: String, diagnosticsMessage: String) {
        runtimeStatus = runtimeMessage
        fixtureStatus = "DR fixture: not loaded"
        loadedResidentID = ""
        residentID = "resident_id: -"
        displayName = "display_name: -"
        sessionState = AppSessionState()
        avatarState = AppAvatarState()
        traceState = RuntimeTraceViewState(summary: diagnosticsMessage, entries: [])
        runtimeState = .idle
        diagnostics = diagnosticsMessage
        startupState = .failed
    }
}
