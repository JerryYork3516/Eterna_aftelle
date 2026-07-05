import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: AppController
    @State private var particleTuning = ParticleCoreTuning.loadSaved()
    #if DEBUG
    @State private var showsParticleDebug = false
    #endif

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.05, blue: 0.06)
                .ignoresSafeArea()

            ParticleCoreMetalView(tuning: particleTuning)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            #if DEBUG
            debugButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 18)
                .padding(.trailing, 18)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            controller.start()
        }
    }

    #if DEBUG
    private var debugButton: some View {
        Button {
            showsParticleDebug.toggle()
        } label: {
            Label(String(localized: "particleDebug.button"), systemImage: "slider.horizontal.3")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(String(localized: "particleDebug.button"))
        .popover(isPresented: $showsParticleDebug, arrowEdge: .top) {
            ParticleDebugPanel(tuning: $particleTuning)
        }
    }
    #endif
}

#if DEBUG
private struct ParticleDebugPanel: View {
    @Binding var tuning: ParticleCoreTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "particleDebug.title"))
                    .font(.headline)
                Text(String(localized: "particleDebug.particleAdjustment"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(localized: "particleDebug.parameters"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 8) {
                ForEach(ParticleCoreTuningParameter.allCases) { parameter in
                    if parameter == .rotationDirection {
                        ParticleDirectionRow(tuning: $tuning)
                    } else {
                        ParticleParameterRow(parameter: parameter, tuning: $tuning)
                    }
                }
            }

            Divider()

            HStack {
                Button(String(localized: "particleDebug.restoreDefault")) {
                    tuning = .systemDefault
                    ParticleCoreTuning.clearSaved()
                }

                Spacer()

                Button(String(localized: "particleDebug.save")) {
                    tuning.save()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
        .padding(14)
        .frame(width: 420)
    }
}

private struct ParticleParameterRow: View {
    let parameter: ParticleCoreTuningParameter
    @Binding var tuning: ParticleCoreTuning

    var body: some View {
        HStack(spacing: 10) {
            Text(String(localized: String.LocalizationValue(parameter.localizedKey)))
                .font(.system(size: 12))
                .frame(width: 116, alignment: .leading)

            Slider(value: value, in: 0...1)

            TextField("", value: value, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)
        }
    }

    private var value: Binding<Double> {
        Binding {
            tuning[keyPath: parameter.keyPath]
        } set: { newValue in
            tuning[keyPath: parameter.keyPath] = min(1, max(0, newValue))
        }
    }
}

private struct ParticleDirectionRow: View {
    @Binding var tuning: ParticleCoreTuning

    var body: some View {
        HStack(spacing: 10) {
            Text(String(localized: "particleDebug.parameter.rotationDirection"))
                .font(.system(size: 12))
                .frame(width: 116, alignment: .leading)

            Picker("", selection: direction) {
                ForEach(ParticleCoreRotationDirection.allCases) { direction in
                    Text(String(localized: String.LocalizationValue(direction.localizedKey)))
                        .tag(direction)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var direction: Binding<ParticleCoreRotationDirection> {
        Binding {
            ParticleCoreRotationDirection.nearest(to: tuning.rotationDirection)
        } set: { newValue in
            tuning.rotationDirection = newValue.tuningValue
        }
    }
}
#endif

#Preview {
    ContentView(controller: AppController())
}
