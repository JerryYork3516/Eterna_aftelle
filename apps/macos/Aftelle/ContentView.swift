import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: AppController
    @State private var particleTuning = ParticleCoreTuning.loadSaved()
    @State private var particleColorProfile = ParticleCoreColorProfile.loadSaved() ?? .systemDefault
    #if DEBUG
    @State private var debugSubtitleKeyMonitor: Any?
    @State private var isParticleOrientationOverlayVisible = true
    @State private var particleOrientationTimeSample = ParticleOrientationTimeSample.empty
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
                debugMetricsHandler: { metrics in
                    controller.updateParticleRenderMetrics(metrics)
                    #if DEBUG
                    particleOrientationTimeSample = ParticleOrientationTimeSample(
                        renderElapsedTime: metrics.renderElapsedTime,
                        motionElapsedTime: metrics.motionElapsedTime,
                        sampleDate: Date()
                    )
                    #endif
                }
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            ParticleSubtitleOverlay(state: controller.particleSubtitleState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if DEBUG
            if isParticleOrientationOverlayVisible {
                ParticleOrientationDebugOverlay(tuning: particleTuning, timeSample: particleOrientationTimeSample)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            if controller.isParticleDebugPanelPresented {
                ParticleDebugPanel(
                    snapshot: controller.particleDebugSnapshot,
                    shellMode: controller.particleShellMode,
                    renderKind: controller.particleRenderKind,
                    tuning: $particleTuning,
                    colorProfile: $particleColorProfile,
                    orientationOverlayVisible: $isParticleOrientationOverlayVisible,
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
        case .darkShell:
            return Color(red: 0.045, green: 0.05, blue: 0.06)
        case .immersiveShell:
            return Color(red: 0.026, green: 0.030, blue: 0.036)
        case .transparentShell:
            return .clear
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
private struct ParticleOrientationTimeSample: Equatable {
    var renderElapsedTime: TimeInterval
    var motionElapsedTime: TimeInterval
    var sampleDate: Date

    static let empty = ParticleOrientationTimeSample(renderElapsedTime: 0, motionElapsedTime: 0, sampleDate: Date())

    func renderElapsed(at date: Date) -> TimeInterval {
        max(0, renderElapsedTime + date.timeIntervalSince(sampleDate))
    }

    func motionElapsed(at date: Date) -> TimeInterval {
        let currentRenderElapsed = renderElapsed(at: date)
        return motionElapsedTime + motionElapsedFormula(currentRenderElapsed) - motionElapsedFormula(renderElapsedTime)
    }

    private func motionElapsedFormula(_ renderElapsed: TimeInterval) -> TimeInterval {
        let speedPhaseRate: TimeInterval = 0.025
        return 0.42 * renderElapsed + (0.08 / speedPhaseRate) * (1 - cos(renderElapsed * speedPhaseRate))
    }
}

private struct ParticleOrientationDebugOverlay: View {
    let tuning: ParticleCoreTuning
    let timeSample: ParticleOrientationTimeSample

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let motionTime = timeSample.motionElapsed(at: context.date)
                let renderElapsed = timeSample.renderElapsed(at: context.date)
                drawClockLabels(in: &canvas, size: size)
                drawMotionTimeline(in: &canvas, size: size, motionTime: motionTime, renderElapsed: renderElapsed)
                drawAxisSet(in: &canvas, origin: CGPoint(x: size.width * 0.5, y: size.height * 0.5), length: 78, motionTime: motionTime, lineWidth: 2.0)
                drawAxisSet(in: &canvas, origin: CGPoint(x: 82, y: size.height - 92), length: 42, motionTime: motionTime, lineWidth: 1.7)
            }
        }
    }

    private func rotationState(at motionTime: TimeInterval) -> ParticleRotationState {
        let tuneRotationSpeed = scaleAroundOne(tuning.rotationSpeed, range: 1.40)
        let direction = cardinalDirection(for: tuning.rotationDirection)
        let rotationTime = motionTime * 0.76 * tuneRotationSpeed
        let spinDirection = direction.x + direction.y < -0.25 ? -1.0 : 1.0
        let earthSpinAngle = rotationTime * spinDirection * 3.0
        return ParticleRotationState(
            rotationTime: rotationTime,
            earthSpinAngle: earthSpinAngle,
            angularVelocityPerMotionSecond: 0.76 * tuneRotationSpeed * spinDirection * 3.0
        )
    }

    private struct ParticleRotationState {
        let rotationTime: TimeInterval
        let earthSpinAngle: Double
        let angularVelocityPerMotionSecond: Double
    }

    private func cardinalDirection(for value: Double) -> CGPoint {
        let bucket = floor(min(1, max(0, value)) * 3.0 + 0.5)
        if bucket < 0.5 {
            return CGPoint(x: 0, y: 1)
        }
        if bucket < 1.5 {
            return CGPoint(x: 0, y: -1)
        }
        if bucket < 2.5 {
            return CGPoint(x: -1, y: 0)
        }
        return CGPoint(x: 1, y: 0)
    }

    private func drawAxisSet(in canvas: inout GraphicsContext, origin: CGPoint, length: CGFloat, motionTime: TimeInterval, lineWidth: CGFloat) {
        let rotationState = rotationState(at: motionTime)
        let axes: [(String, SIMD3<Double>, Color)] = [
            ("X", SIMD3<Double>(1, 0, 0), .red),
            ("Y", SIMD3<Double>(0, 1, 0), .green),
            ("Z", SIMD3<Double>(0, 0, 1), .blue)
        ]

        for axis in axes {
            let endpoint = projectedAxisPoint(axis.1 * -0.42, rotationState: rotationState, origin: origin, length: length)
            var path = Path()
            path.move(to: origin)
            path.addLine(to: endpoint.point)
            canvas.stroke(path, with: .color(axis.2.opacity(0.20)), lineWidth: max(1, lineWidth * 0.72))
        }

        for axis in axes {
            let endpoint = projectedAxisPoint(axis.1, rotationState: rotationState, origin: origin, length: length)
            var path = Path()
            path.move(to: origin)
            path.addLine(to: endpoint.point)
            canvas.stroke(path, with: .color(axis.2.opacity(endpoint.opacity)), lineWidth: lineWidth * endpoint.scale)
            canvas.fill(
                Path(ellipseIn: CGRect(
                    x: endpoint.point.x - 3 * endpoint.scale,
                    y: endpoint.point.y - 3 * endpoint.scale,
                    width: 6 * endpoint.scale,
                    height: 6 * endpoint.scale
                )),
                with: .color(axis.2.opacity(min(0.96, endpoint.opacity + 0.08)))
            )
            canvas.draw(
                Text(axis.0)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(axis.2.opacity(min(0.98, endpoint.opacity + 0.12))),
                at: CGPoint(x: endpoint.point.x + 10, y: endpoint.point.y)
            )
        }
    }

    private func projectedAxisPoint(_ vector: SIMD3<Double>, rotationState: ParticleRotationState, origin: CGPoint, length: CGFloat) -> (point: CGPoint, scale: CGFloat, opacity: Double) {
        let viewed = rotateY(vector, rotationState.earthSpinAngle)
        let bodyPerspective = max(0.84, min(1.20, 1.0 / (1.0 - viewed.z * 0.30)))
        let depth = 3.2 - viewed.z
        let depthPerspective = 2.8 / max(1.4, depth)
        let scale = CGFloat(max(0.64, min(1.20, depthPerspective * 0.98)))
        let opacity = max(0.34, min(0.90, 0.62 + viewed.z * 0.16))
        return (
            CGPoint(
                x: origin.x + CGFloat(viewed.x * bodyPerspective) * length * scale,
                y: origin.y - CGFloat(viewed.y * bodyPerspective) * length * scale
            ),
            scale,
            opacity
        )
    }

    private func rotateY(_ vector: SIMD3<Double>, _ angle: Double) -> SIMD3<Double> {
        let c = cos(angle)
        let s = sin(angle)
        return SIMD3<Double>(
            vector.x * c + vector.z * s,
            vector.y,
            -vector.x * s + vector.z * c
        )
    }


    private func scaleAroundOne(_ value: Double, range: Double) -> Double {
        max(0, 1 + (min(1, max(0, value)) - 0.5) * 2 * range)
    }

    private func drawMotionTimeline(in canvas: inout GraphicsContext, size: CGSize, motionTime: TimeInterval, renderElapsed: TimeInterval) {
        let rotationState = rotationState(at: motionTime)
        let angularVelocity = rotationState.angularVelocityPerMotionSecond
        let realTimeAngularVelocity = abs(angularVelocity) * max(0.001, 0.42 + 0.08 * sin(renderElapsed * 0.025))
        let duration = (2.0 * Double.pi) / max(realTimeAngularVelocity, 0.001)
        let y = size.height - 52
        let start = CGPoint(x: 120, y: y)
        let end = CGPoint(x: max(180, size.width - 120), y: y)
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        canvas.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 1)

        for marker in rotationMarkers(isReversed: angularVelocity < 0) {
            let fraction = CGFloat(marker.degrees / 360.0)
            let x = start.x + (end.x - start.x) * fraction
            let markerTime = duration * marker.degrees / 360.0
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: y - marker.tickHeight))
            tick.addLine(to: CGPoint(x: x, y: y + marker.tickHeight))
            canvas.stroke(tick, with: .color(.white.opacity(marker.opacity)), lineWidth: marker.lineWidth)
            drawAxisLabel(marker.label, at: CGPoint(x: x, y: y + 19), in: &canvas)
            drawAxisLabel(String(format: "%.2fs", markerTime), at: CGPoint(x: x, y: y + 34), in: &canvas)
        }

        let phase = abs(rotationState.earthSpinAngle).truncatingRemainder(dividingBy: 2.0 * Double.pi)
        let playheadFraction = CGFloat(phase / (2.0 * Double.pi))
        let playheadX = start.x + (end.x - start.x) * playheadFraction
        var playhead = Path()
        playhead.move(to: CGPoint(x: playheadX, y: y - 18))
        playhead.addLine(to: CGPoint(x: playheadX, y: y + 10))
        canvas.stroke(playhead, with: .color(.white.opacity(0.72)), lineWidth: 1.4)
        canvas.fill(Path(ellipseIn: CGRect(x: playheadX - 4, y: y - 22, width: 8, height: 8)), with: .color(.white.opacity(0.72)))

        drawAxisLabel(String(localized: "particleDebug.orientation.timeline"), at: CGPoint(x: (start.x + end.x) * 0.5, y: y - 18), in: &canvas)
        drawAxisLabel(String(localized: "particleDebug.orientation.playhead"), at: CGPoint(x: playheadX, y: y - 34), in: &canvas)
    }

    private struct RotationMarker {
        let degrees: Double
        let label: String
        let tickHeight: CGFloat
        let lineWidth: CGFloat
        let opacity: Double
    }

    private func rotationMarkers(isReversed: Bool) -> [RotationMarker] {
        [
            RotationMarker(degrees: 0, label: "0°\n\(String(localized: "particleDebug.orientation.front"))", tickHeight: 11, lineWidth: 1.5, opacity: 0.64),
            RotationMarker(degrees: 45, label: "45°\n\(String(localized: isReversed ? "particleDebug.orientation.left45" : "particleDebug.orientation.right45"))", tickHeight: 7, lineWidth: 1.0, opacity: 0.36),
            RotationMarker(degrees: 90, label: "90°\n\(String(localized: isReversed ? "particleDebug.orientation.leftSide" : "particleDebug.orientation.rightSide"))", tickHeight: 9, lineWidth: 1.2, opacity: 0.50),
            RotationMarker(degrees: 135, label: "135°", tickHeight: 6, lineWidth: 1.0, opacity: 0.28),
            RotationMarker(degrees: 180, label: "180°\n\(String(localized: "particleDebug.orientation.back"))", tickHeight: 10, lineWidth: 1.3, opacity: 0.56),
            RotationMarker(degrees: 225, label: "225°", tickHeight: 6, lineWidth: 1.0, opacity: 0.28),
            RotationMarker(degrees: 270, label: "270°\n\(String(localized: isReversed ? "particleDebug.orientation.rightSide" : "particleDebug.orientation.leftSide"))", tickHeight: 9, lineWidth: 1.2, opacity: 0.50),
            RotationMarker(degrees: 315, label: "315°\n\(String(localized: isReversed ? "particleDebug.orientation.right45" : "particleDebug.orientation.left45"))", tickHeight: 7, lineWidth: 1.0, opacity: 0.36),
            RotationMarker(degrees: 360, label: "360°\n\(String(localized: "particleDebug.orientation.front"))", tickHeight: 11, lineWidth: 1.5, opacity: 0.64)
        ]
    }

    private func drawClockLabels(in canvas: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let radiusX = max(120, size.width * 0.5 - 34)
        let radiusY = max(120, size.height * 0.5 - 48)

        for hour in 1...12 {
            let angle = Double(hour % 12) / 12.0 * 2.0 * Double.pi - Double.pi / 2.0
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radiusX,
                y: center.y + CGFloat(sin(angle)) * radiusY
            )
            drawAxisLabel("\(hour)", at: point, in: &canvas)
        }
    }

    private func drawAxisLabel(_ value: String, at point: CGPoint, in canvas: inout GraphicsContext) {
        canvas.draw(
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.52)),
            at: point
        )
    }
}

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
    @Binding var orientationOverlayVisible: Bool
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

            Toggle(String(localized: "particleDebug.orientation.overlay"), isOn: $orientationOverlayVisible)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)

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
