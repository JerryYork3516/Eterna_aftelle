import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Aftelle Stage 7.0 Calibration"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(localized: "Runtime status: not loaded"))
            Text(String(localized: "DR fixture: not loaded"))
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 180)
    }
}
