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
    @State private var particleValidation = ParticleValidationConfig.make(from: CommandLine.arguments)
    @State private var particleValidationStep = ParticleValidationDisplayStep.idle
    @State private var particleValidationRunID = UUID()
    @State private var particleValidationDidStart = false
    #endif

    var body: some View {
        ZStack {
            shellBackground
                .ignoresSafeArea()

            #if DEBUG
            validationAwareParticleView
            #else
            ParticleCoreMetalView(
                visualState: controller.particleVisualState,
                tuning: particleTuning,
                colorProfile: particleColorProfile,
                isTransparentBackground: controller.particleShellMode == .transparentShell,
                debugMetricsHandler: controller.updateParticleRenderMetrics
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            #endif

            ParticleSubtitleOverlay(state: controller.particleSubtitleState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if DEBUG
            if let particleValidation {
                ParticleValidationOverlay(
                    config: particleValidation,
                    step: particleValidationStep
                )
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowShellConfigurator(shellMode: controller.particleShellMode))
        #if DEBUG
        .background(ParticleValidationWindowConfigurator(config: particleValidation))
        #endif
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
            startParticleValidationIfNeeded()
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
    private var validationAwareParticleView: some View {
        ParticleCoreMetalView(
            visualState: controller.particleVisualState,
            tuning: particleTuning,
            colorProfile: particleColorProfile,
            isTransparentBackground: controller.particleShellMode == .transparentShell,
            debugMetricsHandler: controller.updateParticleRenderMetrics,
            validationSeed: particleValidation?.seed,
            validationFixedTime: particleValidationStep.fixedTime
        )
        .id(particleValidationRunID)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

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

    private func startParticleValidationIfNeeded() {
        guard let particleValidation, !particleValidationDidStart else { return }
        particleValidationDidStart = true
        controller.setParticleShellMode(.darkShell)
        controller.setParticleDebugPanelPresented(false)
        particleColorProfile = .systemDefault
        controller.updateEffectiveParticleColorProfile(.systemDefault, savedOverride: false)
        if particleValidation.holdForExternalCapture {
            let item = particleValidation.singleCase ?? ParticleValidationCase.screenshotCases[0]
            particleTuning = item.tuning(from: particleValidation.preset.tuning)
            particleValidationStep = .capturing(
                item,
                mediaKind: particleValidation.mediaKind,
                fixedTime: particleValidation.mediaKind == .screenshot ? particleValidation.screenshotTime : nil
            )
            particleValidationRunID = UUID()
            return
        }
        Task { @MainActor in
            await runParticleValidation(particleValidation)
        }
    }

    private func runParticleValidation(_ config: ParticleValidationConfig) async {
        ParticleCoreTuning.clearSaved()
        do {
            try config.prepareOutputDirectories()
            var captures: [ParticleValidationCapture] = []
            for item in ParticleValidationCase.screenshotCases {
                captures.append(await captureValidationScreenshot(item, config: config))
            }
            for item in ParticleValidationCase.videoCases {
                captures.append(await captureValidationVideo(item, config: config))
            }
            try config.writeCaptureManifest(captures)
            particleValidationStep = ParticleValidationDisplayStep.finished(
                capturedCount: captures.filter(\.success).count,
                failedCount: captures.filter { !$0.success }.count
            )
        } catch {
            particleValidationStep = .failed("validation setup failed: \(error)")
        }

        try? await Task.sleep(nanoseconds: 800_000_000)
        NSApplication.shared.terminate(nil)
    }

    private func captureValidationScreenshot(_ item: ParticleValidationCase, config: ParticleValidationConfig) async -> ParticleValidationCapture {
        particleTuning = item.tuning(from: config.preset.tuning)
        particleValidationRunID = UUID()
        particleValidationStep = .capturing(item, mediaKind: .screenshot, fixedTime: config.screenshotTime)
        try? await Task.sleep(nanoseconds: 900_000_000)

        let url = config.screenshotURL(for: item)
        do {
            try await ParticleValidationCaptureTool.writeWindowScreenshot(to: url)
            return ParticleValidationCapture(caseName: item.fileStem, mediaKind: .screenshot, path: config.relativePath(for: url), success: true, message: "captured")
        } catch {
            return ParticleValidationCapture(caseName: item.fileStem, mediaKind: .screenshot, path: config.relativePath(for: url), success: false, message: "\(error)")
        }
    }

    private func captureValidationVideo(_ item: ParticleValidationCase, config: ParticleValidationConfig) async -> ParticleValidationCapture {
        particleTuning = item.tuning(from: config.preset.tuning)
        particleValidationRunID = UUID()
        particleValidationStep = .capturing(item, mediaKind: .video, fixedTime: nil)
        try? await Task.sleep(nanoseconds: 900_000_000)

        let url = config.videoURL(for: item)
        do {
            try await ParticleValidationCaptureTool.writeWindowRecording(to: url, duration: config.videoDuration)
            return ParticleValidationCapture(caseName: item.fileStem, mediaKind: .video, path: config.relativePath(for: url), success: true, message: "captured")
        } catch {
            return ParticleValidationCapture(caseName: item.fileStem, mediaKind: .video, path: config.relativePath(for: url), success: false, message: "\(error)")
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
            return [.shapeRoundness, .surfaceReliefStrength, .surfaceReliefDensity, .shapeSeed, .membraneAspect, .membraneScale, .membraneFullness]
        case .surface:
            return [.membraneMist, .membraneGrain, .sheetLightStrength, .flowLightStrength, .surfaceLightStrength, .surfaceFlowDirection, .surfaceFlowSeed, .surfaceFlowLightSeed]
        case .motion:
            return [.breathingAmount, .breathingSpeed, .flowStrength, .flowSpeed, .rotationSpeed, .rotationDirection]
        case .edge:
            return [.edgeScatterDistance, .edgeDustAmount, .edgeFrayAmount]
        case .spine:
            return [.ridgeBrightness, .membraneLineStrength, .membraneStability, .spineRadius, .spineSeed, .spineFlowBinding, .spineLineStrength, .spineLineWidth, .spineLineDensity]
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

private enum ParticleValidationMediaKind: String, Codable {
    case screenshot
    case video
}

private enum ParticleValidationPreset: String {
    case systemDefault
    case idlePolish

    var tuning: ParticleCoreTuning {
        switch self {
        case .systemDefault:
            return .systemDefault
        case .idlePolish:
            return .idlePolish
        }
    }

    var displayName: String {
        switch self {
        case .systemDefault:
            return "System Default"
        case .idlePolish:
            return "Idle Polish"
        }
    }
}

private struct ParticleValidationConfig {
    let outputURL: URL
    let preset: ParticleValidationPreset
    let seed: UInt64
    let windowSize: CGSize
    let holdForExternalCapture: Bool
    let singleCase: ParticleValidationCase?
    let mediaKind: ParticleValidationMediaKind
    let screenshotTime: Float = 4.0
    let videoDuration: Int = 6

    var screenshotDirectory: URL {
        outputURL.appendingPathComponent("screenshots", isDirectory: true)
    }

    var videoDirectory: URL {
        outputURL.appendingPathComponent("videos", isDirectory: true)
    }

    static func make(from arguments: [String]) -> ParticleValidationConfig? {
        guard value(after: "--particle-validation", in: arguments) == "light-layers" else { return nil }
        let outputPath = value(after: "--particle-validation-output", in: arguments) ?? "artifacts/particle_light_validation"
        let presetName = value(after: "--particle-validation-preset", in: arguments) ?? "idlePolish"
        let seed = UInt64(value(after: "--particle-validation-seed", in: arguments) ?? "") ?? 9233
        let windowSize = parseWindowSize(value(after: "--particle-validation-window", in: arguments)) ?? CGSize(width: 960, height: 720)
        let holdForExternalCapture = arguments.contains("--particle-validation-hold")
        let mediaKind = ParticleValidationMediaKind(rawValue: value(after: "--particle-validation-media", in: arguments) ?? "screenshot") ?? .screenshot
        let singleCase = makeCase(
            parameterName: value(after: "--particle-validation-parameter", in: arguments),
            valueName: value(after: "--particle-validation-value", in: arguments)
        )
        guard let preset = ParticleValidationPreset(rawValue: presetName) else { return nil }
        return ParticleValidationConfig(
            outputURL: URL(fileURLWithPath: outputPath).standardizedFileURL,
            preset: preset,
            seed: seed,
            windowSize: windowSize,
            holdForExternalCapture: holdForExternalCapture,
            singleCase: singleCase,
            mediaKind: mediaKind
        )
    }

    func prepareOutputDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        for directory in [screenshotDirectory, videoDirectory] {
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func screenshotURL(for item: ParticleValidationCase) -> URL {
        screenshotDirectory.appendingPathComponent("\(item.fileStem).png")
    }

    func videoURL(for item: ParticleValidationCase) -> URL {
        videoDirectory.appendingPathComponent("\(item.fileStem).mov")
    }

    func relativePath(for url: URL) -> String {
        let root = outputURL.path
        let path = url.path
        guard path.hasPrefix(root) else { return path }
        return String(path.dropFirst(root.count + 1))
    }

    func writeCaptureManifest(_ captures: [ParticleValidationCapture]) throws {
        let manifest = ParticleValidationCaptureManifest(
            preset: preset.displayName,
            seed: seed,
            window: "\(Int(windowSize.width))x\(Int(windowSize.height))",
            screenshotTime: screenshotTime,
            videoDuration: videoDuration,
            captures: captures
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: outputURL.appendingPathComponent("capture_manifest.json"))
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func parseWindowSize(_ value: String?) -> CGSize? {
        guard let value else { return nil }
        let parts = value.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width >= 320,
              height >= 240 else { return nil }
        return CGSize(width: width, height: height)
    }

    private static func makeCase(parameterName: String?, valueName: String?) -> ParticleValidationCase? {
        guard let parameterName,
              let parameter = ParticleCoreTuningParameter(rawValue: parameterName) else { return nil }
        guard let valueName, valueName != "default" else {
            return ParticleValidationCase(parameter: parameter, testedValue: .baseline)
        }
        guard let value = Double(valueName) else { return nil }
        return ParticleValidationCase(parameter: parameter, testedValue: .value(value))
    }
}

private struct ParticleValidationCase: Identifiable {
    enum TestedValue {
        case baseline
        case value(Double)
    }

    let parameter: ParticleCoreTuningParameter
    let testedValue: TestedValue

    var id: String { fileStem }

    var fileStem: String {
        "\(parameter.rawValue)_\(fileValueLabel)"
    }

    var displayValueLabel: String {
        switch testedValue {
        case .baseline:
            return "default"
        case let .value(value):
            return String(format: "%.2f", value)
        }
    }

    var resolvedValueDescription: String {
        switch testedValue {
        case .baseline:
            return "default (\(String(format: "%.2f", currentValue(from: .idlePolish))) )"
        case let .value(value):
            return String(format: "%.2f", value)
        }
    }

    static let screenshotCases: [ParticleValidationCase] = [
        .init(parameter: .sheetLightStrength, testedValue: .value(0.00)),
        .init(parameter: .sheetLightStrength, testedValue: .baseline),
        .init(parameter: .sheetLightStrength, testedValue: .value(1.00)),
        .init(parameter: .surfaceLightStrength, testedValue: .value(0.00)),
        .init(parameter: .surfaceLightStrength, testedValue: .baseline),
        .init(parameter: .surfaceLightStrength, testedValue: .value(1.00)),
        .init(parameter: .flowLightStrength, testedValue: .value(0.00)),
        .init(parameter: .flowLightStrength, testedValue: .baseline),
        .init(parameter: .flowLightStrength, testedValue: .value(1.00)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.00)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.25)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.50)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.75)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(1.00))
    ]

    static let videoCases: [ParticleValidationCase] = [
        .init(parameter: .flowLightStrength, testedValue: .value(0.00)),
        .init(parameter: .flowLightStrength, testedValue: .baseline),
        .init(parameter: .flowLightStrength, testedValue: .value(1.00)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.00)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.25)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.50)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(0.75)),
        .init(parameter: .surfaceFlowLightSeed, testedValue: .value(1.00))
    ]

    func tuning(from base: ParticleCoreTuning) -> ParticleCoreTuning {
        var tuning = base
        tuning[keyPath: parameter.keyPath] = currentValue(from: base)
        return tuning.clamped()
    }

    func currentValue(from base: ParticleCoreTuning) -> Double {
        switch testedValue {
        case .baseline:
            return base[keyPath: parameter.keyPath]
        case let .value(value):
            return value
        }
    }

    private var fileValueLabel: String {
        switch testedValue {
        case .baseline:
            return "default"
        case let .value(value):
            return String(format: "%.2f", value)
        }
    }
}

private enum ParticleValidationDisplayStep {
    case idle
    case capturing(ParticleValidationCase, mediaKind: ParticleValidationMediaKind, fixedTime: Float?)
    case finished(capturedCount: Int, failedCount: Int)
    case failed(String)

    var fixedTime: Float? {
        switch self {
        case let .capturing(_, _, fixedTime):
            return fixedTime
        case .idle, .finished, .failed:
            return nil
        }
    }
}

private struct ParticleValidationCapture: Codable {
    let caseName: String
    let mediaKind: ParticleValidationMediaKind
    let path: String
    let success: Bool
    let message: String
}

private struct ParticleValidationCaptureManifest: Codable {
    let preset: String
    let seed: UInt64
    let window: String
    let screenshotTime: Float
    let videoDuration: Int
    let captures: [ParticleValidationCapture]
}

private struct ParticleValidationOverlay: View {
    let config: ParticleValidationConfig
    let step: ParticleValidationDisplayStep

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Particle Light Validation")
                        .font(.system(size: 14, weight: .semibold))
                    Text("preset: \(config.preset.displayName)")
                    Text("seed: \(config.seed)")
                    Text("window: \(Int(config.windowSize.width))x\(Int(config.windowSize.height))")
                    Text("visual state: idle")
                    stepView
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .padding(14)
                .frame(width: 340, alignment: .leading)
                .background(.black.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(18)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .idle:
            Text("status: preparing")
        case let .capturing(item, mediaKind, fixedTime):
            Divider().background(.white.opacity(0.2))
            Text("media: \(mediaKind.rawValue)")
            Text("time: \(fixedTime.map { String(format: "%.1fs paused", $0) } ?? "1x playback")")
            Text("control: \(String(localized: String.LocalizationValue(item.parameter.localizedKey)))")
            Text("parameter: \(item.parameter.rawValue)")
            Text("value: \(String(format: "%.2f", item.currentValue(from: config.preset.tuning)))")
            Text("caption: \(String(localized: String.LocalizationValue(item.parameter.captionKey)))")
                .fixedSize(horizontal: false, vertical: true)
            Text("low: \(String(localized: String.LocalizationValue(item.parameter.lowHintKey)))")
            Text("high: \(String(localized: String.LocalizationValue(item.parameter.highHintKey)))")
        case let .finished(capturedCount, failedCount):
            Text("status: finished captured=\(capturedCount) failed=\(failedCount)")
        case let .failed(message):
            Text("status: failed \(message)")
        }
    }
}

private struct ParticleValidationWindowConfigurator: NSViewRepresentable {
    let config: ParticleValidationConfig?

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let config else { return }
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            let current = window.contentView?.bounds.size ?? .zero
            guard abs(current.width - config.windowSize.width) > 1 || abs(current.height - config.windowSize.height) > 1 else { return }
            window.setContentSize(config.windowSize)
            window.center()
            window.title = "Aftelle Particle Light Validation"
        }
    }
}

private enum ParticleValidationCaptureTool {
    static func writeWindowScreenshot(to url: URL) async throws {
        let window = try validationWindow()
        try await runScreencapture(arguments: ["-x", "-l\(window.windowNumber)", url.path])
    }

    static func writeWindowRecording(to url: URL, duration: Int) async throws {
        let window = try validationWindow()
        try await runScreencapture(arguments: ["-v", "-V\(duration)", "-x", "-l\(window.windowNumber)", url.path])
    }

    private static func runScreencapture(arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finishedProcess in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if finishedProcess.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ParticleValidationError.captureFailed(output.isEmpty ? "screencapture exited \(finishedProcess.terminationStatus)" : output))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func validationWindow() throws -> NSWindow {
        guard let window = NSApplication.shared.windows.first(where: { window in
            window.isVisible && !(window is NSPanel) && window.title.contains("Aftelle")
        }) else {
            throw ParticleValidationError.captureFailed("validation window not found")
        }
        return window
    }
}

private enum ParticleValidationError: Error, CustomStringConvertible {
    case captureFailed(String)

    var description: String {
        switch self {
        case let .captureFailed(message):
            return message
        }
    }
}
#endif

#Preview {
    ContentView(controller: AppController())
}
