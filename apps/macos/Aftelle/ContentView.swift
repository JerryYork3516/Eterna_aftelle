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
            debugPanel

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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Debug Panel"))
                .fontWeight(.semibold)
            Text("\(String(localized: "resident_id:")) \(controller.debugPanelState.residentID)")
            Text("\(String(localized: "session_id:")) \(controller.debugPanelState.sessionID)")
            Text("\(String(localized: "lifecycle_status:")) \(controller.debugPanelState.lifecycleStatus)")
            Text("\(String(localized: "presence:")) \(controller.debugPanelState.presence)")
            Text("\(String(localized: "avatar_mode:")) \(controller.debugPanelState.avatarMode)")
            Text("\(String(localized: "last_activity_summary:")) \(controller.debugPanelState.lastActivitySummary)")
            Text("\(String(localized: "trace_summary:")) \(controller.debugPanelState.traceSummary)")
            Text("\(String(localized: "tick_count:")) \(controller.debugPanelState.tickCount)")
            Text("\(String(localized: "clock_status:")) \(controller.debugPanelState.clockStatus)")
            Text("\(String(localized: "cancellation_status:")) \(controller.debugPanelState.cancellationStatus)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView(controller: AppController())
}
