import SwiftUI

struct ContentView: View {
    private let runtimeCore = RuntimeCore()
    @State private var statusMessage = "Runtime status: not loaded"
    @State private var fixtureStatusMessage = "DR fixture: not loaded"
    @State private var residentID = "resident_id: -"
    @State private var displayName = "display_name: -"
    @State private var diagnostics = ""
    @State private var inputText = ""
    @State private var responseText = ""
    @State private var visualStateText = "visual_state: idle"
    @State private var traceLines: [String] = []
    @State private var particleState: ParticleState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Aftelle Stage 7.0 Calibration"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(statusMessage)
            Text(fixtureStatusMessage)
            Text(residentID)
            Text(displayName)

            particleStrip

            TextField("Enter a message", text: $inputText)
                .textFieldStyle(.roundedBorder)

            Button(String(localized: "Send")) {
                sendMessage()
            }

            if !responseText.isEmpty {
                Text(responseText)
            }

            Text(visualStateText)

            if !traceLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(traceLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.caption)
            }

            if !diagnostics.isEmpty {
                Text(diagnostics)
                    .foregroundStyle(.secondary)
            }

            Button(String(localized: "Load DR")) {
                loadFixture()
            }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 280)
    }

    private func loadFixture() {
        guard let fixtureURL = Bundle.main.url(forResource: "Freezev03", withExtension: "calibration_fixture", subdirectory: "Fixtures") else {
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

    private func sendMessage() {
        let result = runtimeCore.step(inputText: inputText)
        responseText = result.outputText
        visualStateText = "visual_state: idle → thinking → speaking → idle"
        particleState = .thinking
        traceLines = result.traceEvents.map { "\($0.type.rawValue): \($0.message)" }
        diagnostics = "diagnostics: \(result.diagnostics.providerMode), steps: \(result.diagnostics.runtimeStepCount)"
        particleState = .speaking
    }

    private var particleStrip: some View {
        HStack(spacing: 8) {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor.opacity(particleOpacity(for: index)))
                    .frame(width: particleSize(for: index), height: particleSize(for: index))
            }
        }
    }

    private func particleOpacity(for index: Int) -> Double {
        switch particleState {
        case .idle:
            return 0.45
        case .thinking:
            return index.isMultiple(of: 2) ? 0.7 : 0.5
        case .speaking:
            return index.isMultiple(of: 3) ? 1.0 : 0.85
        }
    }

    private func particleSize(for index: Int) -> CGFloat {
        switch particleState {
        case .idle:
            return 8
        case .thinking:
            return index.isMultiple(of: 2) ? 10 : 9
        case .speaking:
            return index.isMultiple(of: 3) ? 12 : 9
        }
    }
}

private enum ParticleState {
    case idle
    case thinking
    case speaking
}

#Preview {
    ContentView()
}
