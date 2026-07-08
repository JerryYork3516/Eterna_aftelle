import AppKit
import MetalKit
import SwiftUI

struct ParticleCoreMetalView: NSViewRepresentable {
    var visualState: ParticleCoreVisualState = .idle
    var tuning: ParticleCoreTuning = .systemDefault
    var colorProfile: ParticleCoreColorProfile = .systemDefault
    var isTransparentBackground = false
    var debugMetricsHandler: ((ParticleRenderMetrics) -> Void)?
    #if DEBUG
    var validationSeed: UInt64?
    var validationFixedTime: Float?
    var debugAnimationPaused = false
    var debugManualRotationEnabled = false
    var debugLightDragEnabled = false
    #endif

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[ParticleCore] metal device missing")
            return MTKView(frame: .zero, device: nil)
        }

        let view = ParticleCoreInputView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        #if DEBUG
        view.manualRotationEnabled = debugManualRotationEnabled
        view.lightDragEnabled = debugLightDragEnabled
        #endif
        configureBackground(for: view, transparent: isTransparentBackground)

        #if DEBUG
        guard let renderer = ParticleCoreRenderer(device: device, visualState: visualState, validationSeed: validationSeed) else {
            print("[ParticleCore] renderer init failed")
            return view
        }
        renderer.validationFixedTime = validationFixedTime
        renderer.debugAnimationPaused = debugAnimationPaused
        renderer.manualRotationEnabled = debugManualRotationEnabled
        renderer.lightDragEnabled = debugLightDragEnabled
        #else
        guard let renderer = ParticleCoreRenderer(device: device, visualState: visualState) else {
            print("[ParticleCore] renderer init failed")
            return view
        }
        #endif
        view.inputRenderer = renderer
        view.delegate = renderer
        context.coordinator.renderer = renderer
        context.coordinator.swiftUIVisualState = visualState
        context.coordinator.tuning = tuning
        context.coordinator.colorProfile = colorProfile
        context.coordinator.debugMetricsHandler = debugMetricsHandler
        renderer.debugMetricsHandler = { metrics in
            DispatchQueue.main.async {
                context.coordinator.debugMetricsHandler?(metrics)
            }
        }
        renderer.setTuning(tuning)
        renderer.setColorProfile(colorProfile)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        configureBackground(for: nsView, transparent: isTransparentBackground)
        if context.coordinator.swiftUIVisualState != visualState {
            context.coordinator.renderer?.setVisualState(visualState, reason: "appMapping")
            context.coordinator.swiftUIVisualState = visualState
        }
        context.coordinator.debugMetricsHandler = debugMetricsHandler
        if context.coordinator.tuning != tuning {
            context.coordinator.renderer?.setTuning(tuning)
            context.coordinator.tuning = tuning
        }
        if context.coordinator.colorProfile != colorProfile {
            context.coordinator.renderer?.setColorProfile(colorProfile)
            context.coordinator.colorProfile = colorProfile
        }
        #if DEBUG
        if let inputView = nsView as? ParticleCoreInputView {
            inputView.manualRotationEnabled = debugManualRotationEnabled
            inputView.lightDragEnabled = debugLightDragEnabled
        }
        context.coordinator.renderer?.validationFixedTime = validationFixedTime
        context.coordinator.renderer?.debugAnimationPaused = debugAnimationPaused
        context.coordinator.renderer?.manualRotationEnabled = debugManualRotationEnabled
        context.coordinator.renderer?.lightDragEnabled = debugLightDragEnabled
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configureBackground(for view: MTKView, transparent: Bool) {
        if transparent {
            view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            view.layer?.backgroundColor = NSColor.clear.cgColor
            view.layer?.isOpaque = false
        } else {
            view.clearColor = MTLClearColor(red: 0.035, green: 0.04, blue: 0.05, alpha: 1)
            view.layer?.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.05, alpha: 1).cgColor
            view.layer?.isOpaque = true
        }
    }

    final class Coordinator {
        var renderer: ParticleCoreRenderer?
        var swiftUIVisualState: ParticleCoreVisualState = .idle
        var tuning: ParticleCoreTuning = .systemDefault
        var colorProfile: ParticleCoreColorProfile = .systemDefault
        var debugMetricsHandler: ((ParticleRenderMetrics) -> Void)?
    }
}

private final class ParticleCoreInputView: MTKView {
    weak var inputRenderer: ParticleCoreRenderer?
    var manualRotationEnabled = false
    var lightDragEnabled = false
    private var trackingAreaRef: NSTrackingArea?
    private var lastMousePosition: SIMD2<Float>?
    private var lastMouseTime: TimeInterval?
    private var lastLightDragLocation: CGPoint?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func updateTrackingAreas() {
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        updateMouse(with: event, active: true)
    }

    override func mouseDragged(with event: NSEvent) {
        if lightDragEnabled, event.modifierFlags.contains(.option) {
            let location = convert(event.locationInWindow, from: nil)
            if let lastLightDragLocation {
                inputRenderer?.rotateLight(
                    deltaX: Float(location.x - lastLightDragLocation.x),
                    deltaY: Float(location.y - lastLightDragLocation.y)
                )
            }
            lastLightDragLocation = location
            inputRenderer?.updateMouse(position: .zero, velocity: .zero, active: false)
            return
        }
        lastLightDragLocation = nil
        if manualRotationEnabled {
            inputRenderer?.rotateManualView(deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
            inputRenderer?.updateMouse(position: .zero, velocity: .zero, active: false)
            return
        }
        updateMouse(with: event, active: true)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastLightDragLocation = nil
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        lastLightDragLocation = nil
        super.mouseUp(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        lastLightDragLocation = nil
        lastMousePosition = nil
        lastMouseTime = nil
        inputRenderer?.updateMouse(position: .zero, velocity: .zero, active: false)
    }

    override func scrollWheel(with event: NSEvent) {
        if manualRotationEnabled {
            inputRenderer?.rotateManualView(deltaX: Float(event.scrollingDeltaX), deltaY: Float(event.scrollingDeltaY))
            return
        }
        super.scrollWheel(with: event)
    }

    override func keyDown(with event: NSEvent) {
        #if DEBUG
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }

        switch key {
        case "i":
            inputRenderer?.setVisualState(.idle, reason: "debugKey.I")
        case "t":
            inputRenderer?.setVisualState(.thinking, reason: "debugKey.T")
        case "s":
            inputRenderer?.setVisualState(.speaking, reason: "debugKey.S")
        case "l":
            inputRenderer?.setVisualState(.loading, reason: "debugKey.L")
        case "e":
            inputRenderer?.setVisualState(.error, reason: "debugKey.E")
        case "x":
            inputRenderer?.setVisualState(.exit, reason: "debugKey.X")
        default:
            super.keyDown(with: event)
        }
        #else
        super.keyDown(with: event)
        #endif
    }

    private func updateMouse(with event: NSEvent, active: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.width > 1, bounds.height > 1 else { return }

        let aspect = Float(bounds.width / max(bounds.height, 1))
        let position = SIMD2<Float>(
            (Float(point.x / bounds.width) * 2 - 1) * aspect,
            Float(point.y / bounds.height) * 2 - 1
        )

        let timestamp = event.timestamp
        let velocity: SIMD2<Float>
        if let lastMousePosition, let lastMouseTime {
            let dt = max(Float(timestamp - lastMouseTime), 0.008)
            let rawVelocity = (position - lastMousePosition) / dt
            velocity = SIMD2<Float>(
                max(-5, min(5, rawVelocity.x)),
                max(-5, min(5, rawVelocity.y))
            )
        } else {
            velocity = .zero
        }

        lastMousePosition = position
        lastMouseTime = timestamp
        inputRenderer?.updateMouse(position: position, velocity: velocity, active: active)
    }
}
