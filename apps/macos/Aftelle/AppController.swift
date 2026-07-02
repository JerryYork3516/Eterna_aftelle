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

    private let runtimeCore: RuntimeCore

    init(runtimeCore: RuntimeCore = RuntimeCore()) {
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

        let result = runtimeCore.loadDR(from: fixtureData)
        runtimeStatus = "Runtime status: \(result.statusMessage)"
        fixtureStatus = result.isLoaded ? "DR fixture: loaded" : "DR fixture: not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
        diagnostics = result.diagnostics
        startupState = result.isLoaded ? .loaded : .failed
    }

    private func applyFailure(runtimeMessage: String, diagnosticsMessage: String) {
        runtimeStatus = runtimeMessage
        fixtureStatus = "DR fixture: not loaded"
        residentID = "resident_id: -"
        displayName = "display_name: -"
        diagnostics = diagnosticsMessage
        startupState = .failed
    }
}
