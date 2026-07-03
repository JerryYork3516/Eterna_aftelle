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
            Text("\(String(localized: "resident_lifecycle_status:")) \(controller.residentState.lifecycleStatus)")
            Text("\(String(localized: "resident_presence:")) \(controller.residentState.presence)")
            Text("\(String(localized: "resident_last_activity:")) \(controller.residentState.lastActivitySummary)")
            Text("\(String(localized: "resident_last_updated_at:")) \(controller.residentState.lastUpdatedAt)")
            Text("\(String(localized: "runtime_state:")) \(String(describing: controller.runtimeState))")

            tracePanel
            tickPanel

            if !controller.diagnostics.isEmpty {
                Text(controller.diagnostics)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private var tracePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Runtime Trace"))
                .fontWeight(.semibold)
            Text("\(String(localized: "trace_summary:")) \(controller.traceState.summary)")
                .foregroundStyle(.secondary)

            ForEach(controller.traceState.entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.type): \(entry.message)")
                    Text(entry.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    private var tickPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Runtime Clock"))
                .fontWeight(.semibold)
            Text("\(String(localized: "tick_count:")) \(controller.clockState.tickCount)")
                .foregroundStyle(.secondary)
            Text("\(String(localized: "tick_summary:")) \(controller.clockState.lastTickSummary)")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

#Preview {
    ContentView(controller: AppController())
}
