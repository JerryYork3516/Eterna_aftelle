import AppKit
import MetalKit
import SwiftUI

struct ParticleCoreMetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        print("[ParticleCore] makeNSView called")
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[ParticleCore] metal device missing")
            return MTKView(frame: .zero, device: nil)
        }
        print("[ParticleCore] metal device ok name=\(device.name)")

        let view = ParticleCoreInputView(frame: .zero, device: device)
        view.clearColor = MTLClearColor(red: 0.035, green: 0.04, blue: 0.05, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.05, alpha: 1).cgColor

        print("[ParticleCore] MTKView created deviceOk=\(view.device != nil)")
        guard let renderer = ParticleCoreRenderer(device: device) else {
            print("[ParticleCore] renderer init failed")
            return view
        }
        view.inputRenderer = renderer
        view.delegate = renderer
        context.coordinator.renderer = renderer
        print("[ParticleCore] MTKView delegate set \(view.delegate === renderer)")
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        if !context.coordinator.didLogUpdate {
            print("[ParticleCore] updateNSView called drawableSize=\(Int(nsView.drawableSize.width))x\(Int(nsView.drawableSize.height))")
            context.coordinator.didLogUpdate = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var renderer: ParticleCoreRenderer?
        var didLogUpdate = false
    }
}

private final class ParticleCoreInputView: MTKView {
    weak var inputRenderer: ParticleCoreRenderer?
    private var trackingAreaRef: NSTrackingArea?
    private var lastMousePosition: SIMD2<Float>?
    private var lastMouseTime: TimeInterval?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
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

    override func mouseExited(with event: NSEvent) {
        lastMousePosition = nil
        lastMouseTime = nil
        inputRenderer?.updateMouse(position: .zero, velocity: .zero, active: false)
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
