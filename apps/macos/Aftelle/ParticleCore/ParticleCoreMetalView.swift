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
        configureBackground(for: view, transparent: isTransparentBackground)

        #if DEBUG
        guard let renderer = ParticleCoreRenderer(device: device, visualState: visualState, validationSeed: validationSeed) else {
            print("[ParticleCore] renderer init failed")
            return view
        }
        renderer.validationFixedTime = validationFixedTime
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
        context.coordinator.renderer?.validationFixedTime = validationFixedTime
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
    private var trackingAreaRef: NSTrackingArea?
    private var lastMousePosition: SIMD2<Float>?
    private var lastMouseTime: TimeInterval?

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
        updateMouse(with: event, active: true)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        lastMousePosition = nil
        lastMouseTime = nil
        inputRenderer?.updateMouse(position: .zero, velocity: .zero, active: false)
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
