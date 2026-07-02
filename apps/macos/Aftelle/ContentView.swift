import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: AppController

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
            controller.start()
        }
    }

    private var shellStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(controller.runtimeStatus)
            Text(controller.fixtureStatus)
            Text(controller.residentID)
            Text(controller.displayName)
            Text("\(String(localized: "avatar_mode:")) \(controller.avatarState.mode)")
            Text("\(String(localized: "avatar_presence:")) \(controller.avatarState.presence)")
            Text("\(String(localized: "avatar_mood_hint:")) \(controller.avatarState.moodHint)")
            Text("\(String(localized: "avatar_activity_hint:")) \(controller.avatarState.activityHint)")
            Text("\(String(localized: "avatar_particle_hint:")) \(controller.avatarState.particleHint)")
            Text("\(String(localized: "runtime_state:")) \(String(describing: controller.runtimeState))")

            if !controller.diagnostics.isEmpty {
                Text(controller.diagnostics)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView(controller: AppController())
}
