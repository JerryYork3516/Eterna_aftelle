import SwiftUI

struct ContentView: View {
    private let runtimeCore = RuntimeCore()
    @State private var statusMessage = "Runtime status: not loaded"
    @State private var fixtureStatusMessage = "DR fixture: not loaded"
    @State private var residentID = "resident_id: -"
    @State private var displayName = "display_name: -"
    @State private var diagnostics = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Aftelle Stage 7.0 Calibration"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(statusMessage)
            Text(fixtureStatusMessage)
            Text(residentID)
            Text(displayName)

            if !diagnostics.isEmpty {
                Text(diagnostics)
                    .foregroundStyle(.secondary)
            }

            Button(String(localized: "Load DR")) {
                loadFixture()
            }
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 220)
    }

    private func loadFixture() {
        guard let fixtureURL = Bundle.main.url(forResource: "Freezev03", withExtension: "digital_resident") else {
            statusMessage = "Runtime status: DR load failed"
            fixtureStatusMessage = "DR fixture: not loaded"
            diagnostics = "Fixture not found"
            return
        }

        guard let fixtureData = try? Data(contentsOf: fixtureURL) else {
            statusMessage = "Runtime status: DR load failed"
            fixtureStatusMessage = "DR fixture: not loaded"
            diagnostics = "Fixture unreadable"
            return
        }

        let result = runtimeCore.loadDR(from: fixtureData)
        statusMessage = "Runtime status: \(result.statusMessage)"
        fixtureStatusMessage = result.isLoaded ? "DR fixture: loaded" : "DR fixture: not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
        diagnostics = result.diagnostics
    }
}

#Preview {
    ContentView()
}
