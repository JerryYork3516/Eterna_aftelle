import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: AppController
    @State private var particleTuning = ParticleCoreTuning.loadSaved()
    @State private var particleColorProfile = ParticleCoreColorProfile.loadSaved() ?? .systemDefault
    #if DEBUG
    @State private var showsParticleDebug = false
    #endif

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.05, blue: 0.06)
                .ignoresSafeArea()

            ParticleCoreMetalView(
                visualState: controller.particleVisualState,
                tuning: particleTuning,
                colorProfile: particleColorProfile
            )
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
        .onChange(of: controller.particleColorProfile) { _, newValue in
            guard !ParticleCoreColorProfile.hasSavedProfile() else { return }
            particleColorProfile = newValue
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
            ParticleDebugPanel(
                tuning: $particleTuning,
                colorProfile: $particleColorProfile,
                defaultColorProfile: controller.particleColorProfile,
                importDR: openDebugDRImportPanel
            )
        }
    }

    private func openDebugDRImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        var contentTypes: [UTType] = [.json]
        if let digitalResidentType = UTType(filenameExtension: "digital_resident") {
            contentTypes.append(digitalResidentType)
        }
        if let drType = UTType(filenameExtension: "dr") {
            contentTypes.append(drType)
        }
        panel.allowedContentTypes = contentTypes

        if panel.runModal() == .OK, let url = panel.url {
            controller.debugImportResident(from: url)
            particleColorProfile = controller.particleColorProfile
        }
    }
    #endif
}

#if DEBUG
private enum ParticleDebugSection {
    case particle
    case color
}

private struct ParticleDebugPanel: View {
    @Binding var tuning: ParticleCoreTuning
    @Binding var colorProfile: ParticleCoreColorProfile
    let defaultColorProfile: ParticleCoreColorProfile
    let importDR: () -> Void
    @State private var section: ParticleDebugSection = .particle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "particleDebug.title"))
                    .font(.headline)
                Text(sectionSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(sectionCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $section) {
                Text(String(localized: "particleDebug.particleAdjustment"))
                    .tag(ParticleDebugSection.particle)
                Text(String(localized: "particleDebug.colorAdjustment"))
                    .tag(ParticleDebugSection.color)
            }
            .pickerStyle(.segmented)

            Button {
                importDR()
            } label: {
                Label(String(localized: "particleDebug.importDR"), systemImage: "doc.badge.plus")
            }
            .controlSize(.small)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    switch section {
                    case .particle:
                        ForEach(ParticleCoreTuningParameter.allCases) { parameter in
                            if parameter == .rotationDirection {
                                ParticleDirectionRow(tuning: $tuning)
                            } else {
                                ParticleParameterRow(parameter: parameter, tuning: $tuning)
                            }
                        }
                    case .color:
                        ForEach(ParticleCoreColorParameter.allCases) { parameter in
                            ParticleColorParameterRow(parameter: parameter, colorProfile: $colorProfile)
                        }
                    }
                }
            }
            .frame(maxHeight: 380)

            Divider()

            HStack {
                Button(String(localized: "particleDebug.restoreDefault")) {
                    restoreDefault()
                }

                Spacer()

                Button(String(localized: "particleDebug.save")) {
                    saveCurrentSection()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
        .padding(14)
        .frame(width: 420)
    }

    private var sectionSubtitle: String {
        switch section {
        case .particle:
            return String(localized: "particleDebug.particleAdjustment")
        case .color:
            return String(localized: "particleDebug.colorAdjustment")
        }
    }

    private var sectionCaption: String {
        switch section {
        case .particle:
            return String(localized: "particleDebug.parameters")
        case .color:
            return String(localized: "particleDebug.colorParameters")
        }
    }

    private func restoreDefault() {
        switch section {
        case .particle:
            tuning = .systemDefault
            ParticleCoreTuning.clearSaved()
        case .color:
            colorProfile = defaultColorProfile
            ParticleCoreColorProfile.clearSaved()
        }
    }

    private func saveCurrentSection() {
        switch section {
        case .particle:
            tuning.save()
        case .color:
            colorProfile.save()
        }
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

private struct ParticleColorParameterRow: View {
    let parameter: ParticleCoreColorParameter
    @Binding var colorProfile: ParticleCoreColorProfile

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
            colorProfile[keyPath: parameter.keyPath]
        } set: { newValue in
            colorProfile[keyPath: parameter.keyPath] = min(1, max(0, newValue))
        }
    }
}
#endif

#Preview {
    ContentView(controller: AppController())
}
