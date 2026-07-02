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
    @Published private(set) var avatarState = AppAvatarState()
    @Published private(set) var runtimeState: AppRuntimeState = .idle

    private let runtimeCore: RuntimeCore
    private var loadedResidentID = ""

    init() {
        self.runtimeCore = RuntimeCore()
    }

    init(runtimeCore: RuntimeCore) {
        self.runtimeCore = runtimeCore
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

        let result = runtimeCore.loadDR(request: RuntimeLoadRequest(drData: fixtureData))
        loadedResidentID = result.isLoaded ? result.residentID : ""
        runtimeStatus = "Runtime status: \(result.statusMessage)"
        fixtureStatus = result.isLoaded ? "DR fixture: loaded" : "DR fixture: not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
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
        startupState = result.isLoaded ? .loaded : .failed
    }

    func step(inputText: String) -> RuntimeStepResponse {
        let response = runtimeCore.step(request: RuntimeStepRequest(residentID: loadedResidentID, inputText: inputText))
        runtimeState = response.cancellationState.isCancelled ? (response.cancellationState.reason == .interrupted ? .interrupted : .cancelled) : .running
        return response
    }

    func cancelCurrentStep() {
        runtimeCore.cancelCurrentStep()
        runtimeState = .cancelled
    }

    func interrupt() {
        runtimeCore.interrupt(request: RuntimeCancellationRequest(reason: .interrupted))
        runtimeState = .interrupted
    }

    private func applyFailure(runtimeMessage: String, diagnosticsMessage: String) {
        runtimeStatus = runtimeMessage
        fixtureStatus = "DR fixture: not loaded"
        loadedResidentID = ""
        residentID = "resident_id: -"
        displayName = "display_name: -"
        avatarState = AppAvatarState()
        runtimeState = .idle
        diagnostics = diagnosticsMessage
        startupState = .failed
    }
}
