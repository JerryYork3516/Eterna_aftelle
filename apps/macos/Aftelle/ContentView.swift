import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: AppController
    @State private var particleTuning = ParticleCoreTuning.loadSaved()
    @State private var particleColorProfile = ParticleCoreColorProfile.loadSaved() ?? .systemDefault
    #if DEBUG
    @State private var debugSubtitleKeyMonitor: Any?
    #endif

    var body: some View {
        ZStack {
            shellBackground
                .ignoresSafeArea()

            ParticleCoreMetalView(
                visualState: controller.particleVisualState,
                tuning: particleTuning,
                colorProfile: particleColorProfile,
                debugMetricsHandler: controller.updateParticleRenderMetrics
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            ParticleSubtitleOverlay(state: controller.particleSubtitleState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if DEBUG
            if controller.isParticleDebugPanelPresented {
                ParticleDebugPanel(
                    snapshot: controller.particleDebugSnapshot,
                    shellMode: controller.particleShellMode,
                    renderKind: controller.particleRenderKind,
                    tuning: $particleTuning,
                    colorProfile: $particleColorProfile,
                    defaultColorProfile: controller.particleColorProfile,
                    setShellMode: controller.setParticleShellMode,
                    setRenderKind: controller.setParticleRenderKind,
                    refreshColorProfileSnapshot: {
                        controller.updateEffectiveParticleColorProfile(
                            particleColorProfile,
                            savedOverride: ParticleCoreColorProfile.hasSavedProfile()
                        )
                    },
                    importDR: openDebugDRImportPanel
                )
                .padding(.top, 18)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.opacity)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowShellConfigurator(shellMode: controller.particleShellMode))
        .task {
            controller.start()
        }
        .onChange(of: controller.particleColorProfile) { _, newValue in
            guard !ParticleCoreColorProfile.hasSavedProfile() else { return }
            particleColorProfile = newValue
            controller.updateEffectiveParticleColorProfile(newValue, savedOverride: false)
        }
        .onChange(of: particleColorProfile) { _, newValue in
            controller.updateEffectiveParticleColorProfile(
                newValue,
                savedOverride: ParticleCoreColorProfile.hasSavedProfile()
            )
        }
        #if DEBUG
        .onAppear {
            controller.updateEffectiveParticleColorProfile(
                particleColorProfile,
                savedOverride: ParticleCoreColorProfile.hasSavedProfile()
            )
            installDebugSubtitleKeyMonitor()
        }
        .onDisappear {
            removeDebugSubtitleKeyMonitor()
        }
        #endif
    }

    private var shellBackground: Color {
        switch controller.particleShellMode {
        case .darkShell, .transparentShellReserved:
            return Color(red: 0.045, green: 0.05, blue: 0.06)
        case .immersiveShell:
            return Color(red: 0.026, green: 0.030, blue: 0.036)
        }
    }

    #if DEBUG
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

    private func installDebugSubtitleKeyMonitor() {
        guard debugSubtitleKeyMonitor == nil else { return }
        debugSubtitleKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  (event.window?.firstResponder as? NSTextView) == nil,
                  let key = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            switch key {
            case "c":
                controller.showDebugSubtitle()
                return nil
            case "v":
                controller.showNextDebugSubtitle()
                return nil
            case "b":
                controller.hideDebugSubtitle()
                return nil
            default:
                return event
            }
        }
    }

    private func removeDebugSubtitleKeyMonitor() {
        if let debugSubtitleKeyMonitor {
            NSEvent.removeMonitor(debugSubtitleKeyMonitor)
            self.debugSubtitleKeyMonitor = nil
        }
    }
    #endif
}

private struct WindowShellConfigurator: NSViewRepresentable {
    let shellMode: ParticleShellMode

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            let immersive = shellMode == .immersiveShell
            if immersive {
                window.styleMask.insert(.fullSizeContentView)
            } else {
                window.styleMask.remove(.fullSizeContentView)
            }
            window.titleVisibility = immersive ? .hidden : .visible
            window.titlebarAppearsTransparent = immersive
            window.standardWindowButton(.closeButton)?.isHidden = immersive
            window.standardWindowButton(.miniaturizeButton)?.isHidden = immersive
            window.standardWindowButton(.zoomButton)?.isHidden = immersive
        }
    }
}

private struct ParticleSubtitleOverlay: View {
    let state: ParticleSubtitleState

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer()

                if !state.text.isEmpty {
                    Text(state.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .truncationMode(.tail)
                        .frame(maxWidth: max(240, proxy.size.width * 0.62))
                        .shadow(color: .black.opacity(0.36), radius: 8, x: 0, y: 2)
                        .opacity(state.phase == .fading ? 0 : 1)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
            .padding(.bottom, bottomPadding(for: proxy.size.height))
        }
        .animation(.easeInOut(duration: 0.28), value: state)
        .allowsHitTesting(false)
        .accessibilityHidden(state.text.isEmpty)
    }

    private func bottomPadding(for height: CGFloat) -> CGFloat {
        min(max(height * 0.10, 44), 96)
    }
}

#if DEBUG
private enum ParticleDebugSection {
    case diagnostics
    case shell
    case renderAdapter
    case particle
    case color
}

private struct ParticleDebugPanel: View {
    let snapshot: ParticleDebugSnapshot
    let shellMode: ParticleShellMode
    let renderKind: ParticleRenderKind
    @Binding var tuning: ParticleCoreTuning
    @Binding var colorProfile: ParticleCoreColorProfile
    let defaultColorProfile: ParticleCoreColorProfile
    let setShellMode: (ParticleShellMode) -> Void
    let setRenderKind: (ParticleRenderKind) -> Void
    let refreshColorProfileSnapshot: () -> Void
    let importDR: () -> Void
    @State private var section: ParticleDebugSection = .diagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                Text(String(localized: "particleDebug.diagnostics"))
                    .tag(ParticleDebugSection.diagnostics)
                Text(String(localized: "particleDebug.shellMode"))
                    .tag(ParticleDebugSection.shell)
                Text(String(localized: "particleDebug.renderAdapter"))
                    .tag(ParticleDebugSection.renderAdapter)
                Text(String(localized: "particleDebug.particleAdjustment"))
                    .tag(ParticleDebugSection.particle)
                Text(String(localized: "particleDebug.colorAdjustment"))
                    .tag(ParticleDebugSection.color)
            }
            .pickerStyle(.segmented)

            if section == .color {
                Button {
                    importDR()
                } label: {
                    Label(String(localized: "particleDebug.importDR"), systemImage: "doc.badge.plus")
                }
                .controlSize(.small)
            }

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    switch section {
                    case .diagnostics:
                        ParticleDiagnosticsView(snapshot: snapshot)
                    case .shell:
                        ParticleShellModeView(
                            snapshot: snapshot,
                            shellMode: shellMode,
                            setShellMode: setShellMode
                        )
                    case .renderAdapter:
                        ParticleRenderAdapterView(
                            snapshot: snapshot,
                            renderKind: renderKind,
                            setRenderKind: setRenderKind
                        )
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
            .frame(maxHeight: section == .diagnostics ? 460 : 360)

            if section == .particle || section == .color {
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
        }
        .padding(14)
        .frame(width: 430)
    }

    private var sectionSubtitle: String {
        switch section {
        case .diagnostics:
            return String(localized: "particleDebug.diagnostics")
        case .shell:
            return String(localized: "particleDebug.shellMode")
        case .renderAdapter:
            return String(localized: "particleDebug.renderAdapter")
        case .particle:
            return String(localized: "particleDebug.particleAdjustment")
        case .color:
            return String(localized: "particleDebug.colorAdjustment")
        }
    }

    private var sectionCaption: String {
        switch section {
        case .diagnostics:
            return String(localized: "particleDebug.diagnosticsCaption")
        case .shell:
            return String(localized: "particleDebug.shellModeCaption")
        case .renderAdapter:
            return String(localized: "particleDebug.renderAdapterCaption")
        case .particle:
            return String(localized: "particleDebug.parameters")
        case .color:
            return String(localized: "particleDebug.colorParameters")
        }
    }

    private func restoreDefault() {
        switch section {
        case .diagnostics:
            break
        case .shell:
            break
        case .renderAdapter:
            break
        case .particle:
            tuning = .systemDefault
            ParticleCoreTuning.clearSaved()
        case .color:
            colorProfile = defaultColorProfile
            ParticleCoreColorProfile.clearSaved()
            refreshColorProfileSnapshot()
        }
    }

    private func saveCurrentSection() {
        switch section {
        case .diagnostics:
            break
        case .shell:
            break
        case .renderAdapter:
            break
        case .particle:
            tuning.save()
        case .color:
            colorProfile.save()
            refreshColorProfileSnapshot()
        }
    }
}

private struct ParticleDiagnosticsView: View {
    let snapshot: ParticleDebugSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.render") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.fps", value: String(format: "%.1f", snapshot.fps))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.particleCount", value: "\(snapshot.particleCount)")
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.drawableSize", value: snapshot.drawableSize)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.preferredFPS", value: "\(snapshot.preferredFramesPerSecond)")
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.visualState") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.currentVisualState", value: snapshot.currentVisualState)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.previousVisualState", value: snapshot.previousVisualState)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.stateElapsedTime", value: String(format: "%.2fs", snapshot.stateElapsedTime))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.lastTransitionReason", value: snapshot.lastTransitionReason)
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.avatarMapping") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.sourceAvatarState", value: snapshot.sourceAvatarState)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.mappedParticleState", value: snapshot.mappedParticleState)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.isDebugOverrideActive", value: boolText(snapshot.isDebugOverrideActive))
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.avatarMode") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.currentAvatarMode", value: snapshot.avatarMode)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.particleCoreMode", value: snapshot.particleCoreModeStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.abstractBustMode", value: snapshot.abstractBustModeStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.renderFallback", value: snapshot.renderFallback)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.renderFallbackReason", value: snapshot.renderFallbackReason)
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.renderAdapter") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.requestedRenderKind", value: snapshot.requestedRenderKind)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.activeRenderer", value: snapshot.activeRenderer)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.fallbackRenderer", value: snapshot.fallbackRenderer)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.fallbackReason", value: snapshot.fallbackReason)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.supportedRenderers", value: snapshot.supportedRenderers)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.reservedRenderers", value: snapshot.reservedRenderers)
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.shellMode") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.requestedShellMode", value: snapshot.requestedShellMode)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.activeShellMode", value: snapshot.activeShellMode)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.shellFallbackReason", value: snapshot.shellFallbackReason)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.darkShell", value: snapshot.darkShellStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.immersiveShell", value: snapshot.immersiveShellStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.transparentShell", value: snapshot.transparentShellStatus)
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.colorProfile") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.colorProfileSource", value: snapshot.colorProfileSource)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.baseColor", value: snapshot.baseColor)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.ridgeColor", value: snapshot.ridgeColor)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.highlightColor", value: snapshot.highlightColor)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.fallbackUsed", value: boolText(snapshot.fallbackUsed))
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.subtitleState") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.subtitlePhase", value: snapshot.subtitlePhase)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.hasSubtitleText", value: boolText(snapshot.hasSubtitleText))
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.interaction") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.mouseInfluenceEnabled", value: boolText(snapshot.mouseInfluenceEnabled))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.mouseInsideParticleArea", value: boolText(snapshot.mouseInsideParticleArea))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.interactionStrength", value: String(format: "%.2f", snapshot.interactionStrength))
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.boundaryStatus") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.runtimeCoreModified", value: boolText(snapshot.runtimeCoreModified))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.runtimeAPIModified", value: boolText(snapshot.runtimeAPIModified))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.drSchemaModified", value: boolText(snapshot.drSchemaModified))
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.providerTTSConnected", value: boolText(snapshot.providerTTSConnected))
            }
        }
    }

    private func boolText(_ value: Bool) -> String {
        value ? String(localized: "particleDebug.value.true") : String(localized: "particleDebug.value.false")
    }
}

private struct ParticleShellModeView: View {
    let snapshot: ParticleDebugSnapshot
    let shellMode: ParticleShellMode
    let setShellMode: (ParticleShellMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(String(localized: "particleDebug.diagnostics.requestedShellMode"), selection: shellBinding) {
                Text(String(localized: "particleDebug.shellMode.darkShell"))
                    .tag(ParticleShellMode.darkShell)
                Text(String(localized: "particleDebug.shellMode.immersiveShell"))
                    .tag(ParticleShellMode.immersiveShell)
            }
            .pickerStyle(.menu)

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.shellMode") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.requestedShellMode", value: snapshot.requestedShellMode)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.activeShellMode", value: snapshot.activeShellMode)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.shellFallbackReason", value: snapshot.shellFallbackReason)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.darkShell", value: snapshot.darkShellStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.immersiveShell", value: snapshot.immersiveShellStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.transparentShell", value: snapshot.transparentShellStatus)
            }
        }
    }

    private var shellBinding: Binding<ParticleShellMode> {
        Binding {
            shellMode
        } set: { newValue in
            setShellMode(newValue)
        }
    }
}

private struct ParticleRenderAdapterView: View {
    let snapshot: ParticleDebugSnapshot
    let renderKind: ParticleRenderKind
    let setRenderKind: (ParticleRenderKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(String(localized: "particleDebug.diagnostics.requestedRenderKind"), selection: kindBinding) {
                ForEach(ParticleRenderKind.allCases) { kind in
                    Text(String(localized: String.LocalizationValue(kind.localizedKey)))
                        .tag(kind)
                }
            }
            .pickerStyle(.menu)

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.renderAdapter") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.requestedRenderKind", value: snapshot.requestedRenderKind)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.activeRenderer", value: snapshot.activeRenderer)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.fallbackRenderer", value: snapshot.fallbackRenderer)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.fallbackReason", value: snapshot.fallbackReason)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.supportedRenderers", value: snapshot.supportedRenderers)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.reservedRenderers", value: snapshot.reservedRenderers)
            }

            ParticleDiagnosticsSection(titleKey: "particleDebug.diagnostics.avatarMode") {
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.currentAvatarMode", value: snapshot.avatarMode)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.particleCoreMode", value: snapshot.particleCoreModeStatus)
                ParticleDiagnosticsRow(labelKey: "particleDebug.diagnostics.abstractBustMode", value: snapshot.abstractBustModeStatus)
            }
        }
    }

    private var kindBinding: Binding<ParticleRenderKind> {
        Binding {
            renderKind
        } set: { newValue in
            setRenderKind(newValue)
        }
    }
}

private struct ParticleDiagnosticsSection<Content: View>: View {
    let titleKey: String
    let content: () -> Content

    init(titleKey: String, @ViewBuilder content: @escaping () -> Content) {
        self.titleKey = titleKey
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct ParticleDiagnosticsRow: View {
    let labelKey: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(String(localized: String.LocalizationValue(labelKey)))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 156, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.86))
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer(minLength: 0)
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
