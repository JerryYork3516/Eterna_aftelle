import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

struct ParticleCoreFrameUniforms {
    var time: Float
    var breathing: Float
    var edgeBreathing: Float
    var coreStability: Float
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
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("[ParticleCore] pipeline ok")
        } catch {
            print("[ParticleCore] pipeline failed \(error)")
            return nil
        }

        guard let particleBuffer = device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * model.particles.count, options: .storageModeShared) else {
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
        let breathing = 0.010 * sin(elapsed * 0.23) + 0.006 * sin(elapsed * 0.13 + 0.9)
        let edgeBreathing = 0.012 * sin(elapsed * 0.19 + 1.4) + 0.005 * sin(elapsed * 0.37 + 0.3)
        let coreStability = 1 - min(0.025, abs(breathing) * 0.16)
        var uniforms = ParticleCoreFrameUniforms(
            time: elapsed,
            breathing: breathing,
            edgeBreathing: edgeBreathing,
            coreStability: coreStability,
            resolution: resolution,
            seed: 0xA7F13,
            particleCount: UInt32(model.particles.count)
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<ParticleCoreFrameUniforms>.stride)

        if !didLogDraw {
            let aspect = max(resolution.x / max(resolution.y, 1), 1)
            let bounds = model.clipBounds(aspect: aspect, breathing: 1 + breathing)
            print("[ParticleCore] draw called drawableSize=\(Int(drawableSize.width))x\(Int(drawableSize.height)) particleCount=\(model.particles.count) ndcMin=(\(bounds.minX),\(bounds.minY)) ndcMax=(\(bounds.maxX),\(bounds.maxY)) clearColor=(0.035,0.04,0.05,1) globalBreathingRef=\(breathing) edgeBreathingRef=\(edgeBreathing) coreStability=\(coreStability) motion=coherent_3d_material_flow_depth_locked_lighting particleColor=(three_stage_back_front_ion_ridge,back=0.30...0.35,front=0.95...0.98,density_front_gated,no_random_brightness) pointSize=front_lifted_seed_scatter")
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
        let payloads = model.vertexPayloads
        let pointer = particleBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: payloads.count)
        for (index, payload) in payloads.enumerated() {
            pointer[index] = payload
        }
    }
}
