import AppKit
import MetalKit
import SwiftUI

struct ParticleCoreMetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return MTKView(frame: .zero, device: nil)
        }

        let view = MTKView(frame: .zero, device: device)
        view.clearColor = MTLClearColor(red: 0.035, green: 0.04, blue: 0.05, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.05, alpha: 1).cgColor

        guard let renderer = ParticleCoreRenderer(device: device) else { return view }
        view.delegate = renderer
        context.coordinator.renderer = renderer
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var renderer: ParticleCoreRenderer?
    }
}
