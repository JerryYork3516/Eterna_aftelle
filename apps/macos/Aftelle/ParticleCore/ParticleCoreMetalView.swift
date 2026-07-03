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

        let view = MTKView(frame: .zero, device: device)
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
