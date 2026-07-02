import SwiftUI

struct ContentView: View {
    private let runtimeCore = RuntimeCore()
    @State private var runtimeStatus = "Runtime status: not loaded"
    @State private var fixtureStatus = "DR fixture: not loaded"
    @State private var residentID = "resident_id: -"
    @State private var displayName = "display_name: -"
    @State private var diagnostics = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Aftelle Runtime Host"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "Minimal desktop shell for Stage 7."))
                .foregroundStyle(.secondary)

            shellStatusCard

            Text(String(localized: "RuntimeCore remains behind the shell boundary."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 220)
        .task {
            loadFixture()
        }
    }

    private var shellStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(runtimeStatus)
            Text(fixtureStatus)
            Text(residentID)
            Text(displayName)

            if !diagnostics.isEmpty {
                Text(diagnostics)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private func loadFixture() {
        guard let fixtureURL = Bundle.main.url(forResource: "Freezev03.calibration_fixture", withExtension: "json") else {
            runtimeStatus = "Runtime status: DR load failed"
            fixtureStatus = "DR fixture: not loaded"
            diagnostics = "Fixture not found"
            return
        }

        guard let fixtureData = try? Data(contentsOf: fixtureURL) else {
            runtimeStatus = "Runtime status: DR load failed"
            fixtureStatus = "DR fixture: not loaded"
            diagnostics = "Fixture unreadable"
            return
        }

        let result = runtimeCore.loadDR(from: fixtureData)
        runtimeStatus = "Runtime status: \(result.statusMessage)"
        fixtureStatus = result.isLoaded ? "DR fixture: loaded" : "DR fixture: not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
        diagnostics = result.diagnostics
    }
}

#Preview {
    ContentView()
}
