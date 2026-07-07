import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: AppController
    @State private var particleTuning = ParticleCoreTuning.loadSaved()
    @State private var particleColorProfile = ParticleCoreColorProfile.loadSaved() ?? .systemDefault
    #if DEBUG
    @State private var debugSubtitleKeyMonitor: Any?
    @State private var particleDebugWindow = ParticleDebugWindowController()
    #endif

    var body: some View {
        ZStack {
            shellBackground
                .ignoresSafeArea()

            ParticleCoreMetalView(
                visualState: controller.particleVisualState,
                tuning: particleTuning,
                colorProfile: particleColorProfile,
                isTransparentBackground: controller.particleShellMode == .transparentShell,
                debugMetricsHandler: controller.updateParticleRenderMetrics
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            ParticleSubtitleOverlay(state: controller.particleSubtitleState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            syncParticleDebugWindow()
        }
        .onDisappear {
            particleDebugWindow.close()
            removeDebugSubtitleKeyMonitor()
        }
        .onChange(of: controller.isParticleDebugPanelPresented) { _, _ in
            syncParticleDebugWindow()
        }
        .onChange(of: controller.particleDebugSnapshot) { _, _ in
            syncParticleDebugWindow()
        }
        .onChange(of: controller.particleShellMode) { _, _ in
            syncParticleDebugWindow()
        }
        .onChange(of: controller.particleRenderKind) { _, _ in
            syncParticleDebugWindow()
        }
        .onChange(of: particleTuning) { _, _ in
            syncParticleDebugWindow()
        }
        .onChange(of: particleColorProfile) { _, _ in
            syncParticleDebugWindow()
        }
        #endif
    }

    private var shellBackground: Color {
        switch controller.particleShellMode {
        case .darkShell:
            return Color(red: 0.045, green: 0.05, blue: 0.06)
        case .immersiveShell:
            return Color(red: 0.026, green: 0.030, blue: 0.036)
        case .transparentShell:
            return .clear
        }
    }

    #if DEBUG
    private func syncParticleDebugWindow() {
        particleDebugWindow.update(
            isPresented: controller.isParticleDebugPanelPresented,
            rootView: particleDebugPanelView,
            onClose: {
                controller.setParticleDebugPanelPresented(false)
            }
        )
    }

    private var particleDebugPanelView: ParticleDebugPanel {
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
            let transparent = shellMode == .transparentShell
            let visualShell = immersive || transparent
            if visualShell {
                window.styleMask.insert(.fullSizeContentView)
            } else {
                window.styleMask.remove(.fullSizeContentView)
            }
            if transparent {
                window.styleMask.remove(.titled)
            } else {
                window.styleMask.insert(.titled)
            }
            window.titleVisibility = visualShell ? .hidden : .visible
            window.titlebarAppearsTransparent = visualShell
            window.isOpaque = !transparent
            window.backgroundColor = transparent ? .clear : NSColor(calibratedRed: 0.045, green: 0.05, blue: 0.06, alpha: 1)
            window.hasShadow = !transparent
            window.standardWindowButton(.closeButton)?.isHidden = visualShell
            window.standardWindowButton(.miniaturizeButton)?.isHidden = visualShell
            window.standardWindowButton(.zoomButton)?.isHidden = visualShell
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
private final class ParticleDebugWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<ParticleDebugPanel>?
    private var onClose: (() -> Void)?

    func update(isPresented: Bool, rootView: ParticleDebugPanel, onClose: @escaping () -> Void) {
        self.onClose = onClose
        guard isPresented else {
            close()
            return
        }

        if let panel, let hostingView {
            hostingView.rootView = rootView
            if !panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
            }
            return
        }

        let hostingView = NSHostingView(rootView: rootView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = String(localized: "particleDebug.windowTitle")
        panel.contentMinSize = NSSize(width: 680, height: 560)
        panel.contentView = hostingView
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.hostingView = hostingView
        self.panel = panel
    }

    func close() {
        guard let panel else { return }
        panel.delegate = nil
        panel.close()
        hostingView = nil
        self.panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        hostingView = nil
        panel = nil
        onClose?()
    }
}

private enum ParticleDebugSection {
    case diagnostics
    case shell
    case renderAdapter
    case particle
    case color
}

private enum ParticleTuningGroup: CaseIterable, Identifiable {
    case basic
    case shape
    case surface
    case motion
    case edge
    case spine

    var id: String { localizedKey }

    var localizedKey: String {
        switch self {
        case .basic:
            return "particleDebug.tuningGroup.basic"
        case .shape:
            return "particleDebug.tuningGroup.shape"
        case .surface:
            return "particleDebug.tuningGroup.surface"
        case .motion:
            return "particleDebug.tuningGroup.motion"
        case .edge:
            return "particleDebug.tuningGroup.edge"
        case .spine:
            return "particleDebug.tuningGroup.spine"
        }
    }

    var parameters: [ParticleCoreTuningParameter] {
        switch self {
        case .basic:
            return [.globalScale, .pointSizeScale, .brightness, .alphaScale]
        case .shape:
            return [.shapeRoundness, .surfaceReliefStrength, .shapeSeed, .membraneAspect, .membraneScale, .membraneFullness]
        case .surface:
            return [.membraneMist, .membraneGrain, .sheetLightStrength, .flowLightStrength, .surfaceLightStrength, .surfaceDispersionStrength]
        case .motion:
            return [.breathingAmount, .breathingSpeed, .flowStrength, .flowSpeed, .rotationSpeed, .rotationDirection]
        case .edge:
            return [.edgeDustAmount, .edgeFrayAmount]
        case .spine:
            return [.ridgeBrightness, .membraneLineStrength, .membraneLineWidth, .membraneStability, .spineLineStrength, .spineLineWidth, .spineLineDensity, .spineLineHighlight, .spineLineContrast, .spineLineSharpness]
        }
    }
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
    @State private var tuningGroup: ParticleTuningGroup = .shape
    @State private var userPresets = ParticleCoreTuningUserPresetStore.load()
    @State private var selectedUserPresetID: UUID?

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
                        VStack(spacing: 8) {
                            ParticleTuningPresetView(
                                tuning: $tuning,
                                userPresets: $userPresets,
                                selectedUserPresetID: $selectedUserPresetID
                            )

                            Picker("", selection: $tuningGroup) {
                                ForEach(ParticleTuningGroup.allCases) { group in
                                    Text(String(localized: String.LocalizationValue(group.localizedKey)))
                                        .tag(group)
                                }
                            }
                            .pickerStyle(.segmented)

                            VStack(spacing: 10) {
                                ForEach(tuningGroup.parameters) { parameter in
                                    if parameter == .rotationDirection {
                                        ParticleDirectionRow(tuning: $tuning)
                                    } else {
                                        ParticleParameterRow(parameter: parameter, tuning: $tuning)
                                    }
                                }
                            }
                        }
                    case .color:
                        ForEach(ParticleCoreColorParameter.allCases) { parameter in
                            ParticleColorParameterRow(parameter: parameter, colorProfile: $colorProfile)
                        }
                    }
                }
            }
            .frame(maxHeight: section == .diagnostics ? 500 : (section == .particle ? 560 : 380))

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
        .frame(minWidth: 680, idealWidth: 720, minHeight: 540)
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
                Text(String(localized: "particleDebug.shellMode.transparentShell"))
                    .tag(ParticleShellMode.transparentShell)
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

private struct ParticleTuningPresetView: View {
    @Binding var tuning: ParticleCoreTuning
    @Binding var userPresets: [ParticleCoreTuningUserPreset]
    @Binding var selectedUserPresetID: UUID?
    @State private var builtInPreset: ParticleCoreTuningBuiltInPreset = .systemDefault
    @State private var presetName = ""
    @State private var warning = ""
    @State private var presetPendingDelete: ParticleCoreTuningUserPreset?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        ParticleDiagnosticsSection(titleKey: "particleDebug.presets") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "particleDebug.preset.builtInPresets"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $builtInPreset) {
                            ForEach(ParticleCoreTuningBuiltInPreset.allCases) { preset in
                                Text(String(localized: String.LocalizationValue(preset.localizedKey)))
                                    .tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button(String(localized: "particleDebug.preset.apply")) {
                            tuning = builtInPreset.tuning
                        }
                        .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "particleDebug.preset.userPresets"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker(String(localized: "particleDebug.preset.userPresets"), selection: $selectedUserPresetID) {
                            Text(String(localized: "particleDebug.preset.none"))
                                .tag(Optional<UUID>.none)
                            ForEach(userPresets) { preset in
                                Text(preset.name)
                                    .tag(Optional(preset.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .onChange(of: selectedUserPresetID) { _, _ in
                            presetName = selectedPreset?.name ?? ""
                            warning = ""
                        }

                        TextField(String(localized: "particleDebug.preset.name"), text: $presetName)
                            .textFieldStyle(.roundedBorder)

                        if !warning.isEmpty {
                            Text(warning)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button(String(localized: "particleDebug.preset.saveCurrentAs")) {
                        saveCurrentAsPreset()
                    }
                    .controlSize(.small)

                    Button(String(localized: "particleDebug.preset.apply")) {
                        applySelectedPreset()
                    }
                    .controlSize(.small)
                    .disabled(selectedPreset == nil)

                    Button(String(localized: "particleDebug.preset.updateSelected")) {
                        updateSelectedPreset()
                    }
                    .controlSize(.small)
                    .disabled(selectedPreset == nil)

                    Button(String(localized: "particleDebug.preset.rename")) {
                        renameSelectedPreset()
                    }
                    .controlSize(.small)
                    .disabled(selectedPreset == nil)

                    Button(String(localized: "particleDebug.preset.duplicate")) {
                        duplicateSelectedPreset()
                    }
                    .controlSize(.small)
                    .disabled(selectedPreset == nil)

                    Button(String(localized: "particleDebug.preset.delete")) {
                        if let selectedPreset {
                            presetPendingDelete = selectedPreset
                            isDeleteConfirmationPresented = true
                        }
                    }
                    .controlSize(.small)
                    .disabled(selectedPreset == nil)
                }
            }
            .confirmationDialog(
                String(localized: "particleDebug.preset.deleteConfirmation"),
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(String(localized: "particleDebug.preset.delete"), role: .destructive) {
                    deletePendingPreset()
                }
                Button(String(localized: "particleDebug.preset.cancel"), role: .cancel) {}
            }
        }
    }

    private var selectedPreset: ParticleCoreTuningUserPreset? {
        guard let selectedUserPresetID else { return nil }
        return userPresets.first { $0.id == selectedUserPresetID }
    }

    private func saveCurrentAsPreset() {
        guard let name = validPresetName() else { return }
        let now = Date()
        let preset = ParticleCoreTuningUserPreset(
            id: UUID(),
            name: ParticleCoreTuningUserPresetStore.uniqueName(name, in: userPresets),
            tuning: tuning.clamped(),
            createdAt: now,
            updatedAt: now
        )
        userPresets.insert(preset, at: 0)
        selectedUserPresetID = preset.id
        presetName = preset.name
        savePresets()
    }

    private func applySelectedPreset() {
        guard let selectedPreset else { return }
        tuning = selectedPreset.tuning.clamped()
    }

    private func updateSelectedPreset() {
        guard let selectedPreset,
              let index = userPresets.firstIndex(where: { $0.id == selectedPreset.id }) else { return }
        userPresets[index].tuning = tuning.clamped()
        userPresets[index].updatedAt = Date()
        savePresets()
    }

    private func renameSelectedPreset() {
        guard let selectedPreset,
              let name = validPresetName(),
              let index = userPresets.firstIndex(where: { $0.id == selectedPreset.id }) else { return }
        let uniqueName = ParticleCoreTuningUserPresetStore.uniqueName(name, in: userPresets, excluding: selectedPreset.id)
        userPresets[index].name = uniqueName
        userPresets[index].updatedAt = Date()
        presetName = uniqueName
        savePresets()
    }

    private func duplicateSelectedPreset() {
        guard let selectedPreset else { return }
        let now = Date()
        let baseName = presetName.isEmpty ? selectedPreset.name : presetName
        let duplicate = ParticleCoreTuningUserPreset(
            id: UUID(),
            name: ParticleCoreTuningUserPresetStore.uniqueName(baseName, in: userPresets),
            tuning: selectedPreset.tuning.clamped(),
            createdAt: now,
            updatedAt: now
        )
        userPresets.insert(duplicate, at: 0)
        selectedUserPresetID = duplicate.id
        presetName = duplicate.name
        savePresets()
    }

    private func deletePendingPreset() {
        guard let presetPendingDelete else { return }
        userPresets.removeAll { $0.id == presetPendingDelete.id }
        if selectedUserPresetID == presetPendingDelete.id {
            selectedUserPresetID = nil
            presetName = ""
        }
        self.presetPendingDelete = nil
        savePresets()
    }

    private func validPresetName() -> String? {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            warning = String(localized: "particleDebug.preset.emptyNameWarning")
            return nil
        }
        warning = ""
        return name
    }

    private func savePresets() {
        userPresets.sort { $0.updatedAt > $1.updatedAt }
        ParticleCoreTuningUserPresetStore.save(userPresets)
    }
}

private struct ParticleParameterRow: View {
    let parameter: ParticleCoreTuningParameter
    @Binding var tuning: ParticleCoreTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(localized: String.LocalizationValue(parameter.localizedKey)))
                    .font(.system(size: 12, weight: .semibold))

                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isDefault ? Color.secondary : Color.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isDefault ? Color.secondary.opacity(0.12) : Color.blue.opacity(0.14))
                    )

                Text(valueSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(String(localized: "particleDebug.parameter.resetOne")) {
                    tuning[keyPath: parameter.keyPath] = parameter.defaultValue
                }
                .controlSize(.mini)
                .disabled(isDefault)
            }

            Text(String(localized: String.LocalizationValue(parameter.captionKey)))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(String(localized: String.LocalizationValue(parameter.lowHintKey)))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)
                    .lineLimit(2)

                Slider(value: value, in: 0...1, step: parameter.step)

                Text(String(localized: String.LocalizationValue(parameter.highHintKey)))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .trailing)
                    .lineLimit(2)

                TextField("", value: value, format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 58)
            }
        }
        .padding(.vertical, 4)
    }

    private var value: Binding<Double> {
        Binding {
            tuning[keyPath: parameter.keyPath]
        } set: { newValue in
            tuning[keyPath: parameter.keyPath] = min(1, max(0, newValue))
        }
    }

    private var currentValue: Double {
        tuning[keyPath: parameter.keyPath]
    }

    private var isDefault: Bool {
        abs(currentValue - parameter.defaultValue) < 0.0005
    }

    private var statusText: String {
        String(localized: isDefault ? "particleDebug.parameter.defaultBadge" : "particleDebug.parameter.modifiedBadge")
    }

    private var valueSummary: String {
        String(
            format: String(localized: "particleDebug.parameter.valueSummary"),
            currentValue,
            parameter.defaultValue
        )
    }
}

private struct ParticleDirectionRow: View {
    @Binding var tuning: ParticleCoreTuning

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(localized: "particleDebug.parameter.rotationDirection"))
                    .font(.system(size: 12, weight: .semibold))

                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isDefault ? Color.secondary : Color.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isDefault ? Color.secondary.opacity(0.12) : Color.blue.opacity(0.14))
                    )

                Text(valueSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(String(localized: "particleDebug.parameter.resetOne")) {
                    tuning.rotationDirection = ParticleCoreTuningParameter.rotationDirection.defaultValue
                }
                .controlSize(.mini)
                .disabled(isDefault)
            }

            Text(String(localized: "particleDebug.parameter.rotationDirection.caption"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text(String(localized: "particleDebug.parameter.rotationDirection.lowHint"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)

                Picker("", selection: direction) {
                    ForEach(ParticleCoreRotationDirection.allCases) { direction in
                        Text(String(localized: String.LocalizationValue(direction.localizedKey)))
                            .tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                Text(String(localized: "particleDebug.parameter.rotationDirection.highHint"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private var direction: Binding<ParticleCoreRotationDirection> {
        Binding {
            ParticleCoreRotationDirection.nearest(to: tuning.rotationDirection)
        } set: { newValue in
            tuning.rotationDirection = newValue.tuningValue
        }
    }

    private var isDefault: Bool {
        abs(tuning.rotationDirection - ParticleCoreTuningParameter.rotationDirection.defaultValue) < 0.0005
    }

    private var statusText: String {
        String(localized: isDefault ? "particleDebug.parameter.defaultBadge" : "particleDebug.parameter.modifiedBadge")
    }

    private var valueSummary: String {
        String(
            format: String(localized: "particleDebug.parameter.directionSummary"),
            String(localized: String.LocalizationValue(direction.wrappedValue.localizedKey))
        )
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
