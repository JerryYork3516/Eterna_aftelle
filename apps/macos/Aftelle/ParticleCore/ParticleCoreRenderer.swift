import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

struct ParticleCoreFrameUniforms {
    var time: Float
    var breathing: Float
    var resolution: SIMD2<Float>
    var seed: UInt32
    var particleCount: UInt32
}

final class ParticleCoreRenderer: NSObject, MTKViewDelegate {
    private let model: ParticleCoreModel
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let particleBuffer: MTLBuffer
    private let uniformsBuffer: MTLBuffer
    private let startTime = CACurrentMediaTime()
    private var didLogDrawableSize = false
    private var didLogDraw = false

    init?(device: MTLDevice) {
        self.device = device
        self.model = ParticleCoreModel()

        guard let commandQueue = device.makeCommandQueue() else {
            print("[ParticleCore] commandQueue failed")
            return nil
        }
        print("[ParticleCore] commandQueue ok")

        guard let library = device.makeDefaultLibrary() else {
            print("[ParticleCore] defaultLibrary failed")
            return nil
        }
        print("[ParticleCore] defaultLibrary ok")

        guard let vertexFunction = library.makeFunction(name: "particleVertex"),
              let fragmentFunction = library.makeFunction(name: "particleFragment") else {
            print("[ParticleCore] shader functions missing particleVertex=\(library.makeFunction(name: "particleVertex") != nil) particleFragment=\(library.makeFunction(name: "particleFragment") != nil)")
            return nil
        }
        print("[ParticleCore] shader functions ok")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("[ParticleCore] pipeline ok")
        } catch {
            print("[ParticleCore] pipeline failed \(error)")
            return nil
        }

        guard let particleBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * model.particles.count, options: .storageModeShared) else {
            print("[ParticleCore] vertexBuffer failed")
            return nil
        }
        guard let uniformsBuffer = device.makeBuffer(length: MemoryLayout<ParticleCoreFrameUniforms>.stride, options: .storageModeShared) else {
            print("[ParticleCore] uniformsBuffer failed")
            return nil
        }
        print("[ParticleCore] vertexBuffer ok particleCount=\(model.particles.count)")

        self.commandQueue = commandQueue
        self.particleBuffer = particleBuffer
        self.uniformsBuffer = uniformsBuffer

        super.init()
        uploadParticles()
        print("[ParticleCore] renderer init ok")
    }

    func draw(in view: MTKView) {
        let drawableSize = view.drawableSize
        if !didLogDrawableSize, drawableSize.width > 0, drawableSize.height > 0 {
            print("[ParticleCore] drawable size \(Int(drawableSize.width))x\(Int(drawableSize.height))")
            didLogDrawableSize = true
        }

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        let elapsed = Float(CACurrentMediaTime() - startTime)
        let resolution = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        let breathing = 0.018 * sin(elapsed * 1.35) + 0.01 * sin(elapsed * 0.53)
        var uniforms = ParticleCoreFrameUniforms(time: elapsed, breathing: breathing, resolution: resolution, seed: 0xA7F13, particleCount: UInt32(model.particles.count))
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<ParticleCoreFrameUniforms>.stride)

        if !didLogDraw {
            let aspect = max(resolution.x / max(resolution.y, 1), 1)
            let bounds = model.clipBounds(aspect: aspect, breathing: 1 + breathing)
            print("[ParticleCore] draw called drawableSize=\(Int(drawableSize.width))x\(Int(drawableSize.height)) particleCount=\(model.particles.count) ndcMin=(\(bounds.minX),\(bounds.minY)) ndcMax=(\(bounds.maxX),\(bounds.maxY)) clearColor=(0.035,0.04,0.05,1) particleColor=(0.78...0.98,alpha=1)")
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: model.particles.count)
        if !didLogDraw {
            print("[ParticleCore] drawPrimitives executed vertexCount=\(model.particles.count)")
            didLogDraw = true
        }
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func uploadParticles() {
        let pointer = particleBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: model.particles.count)
        for (index, particle) in model.particles.enumerated() {
            pointer[index] = particle.position
        }
    }
}
