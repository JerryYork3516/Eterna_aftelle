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

    init?(device: MTLDevice) {
        self.device = device
        self.model = ParticleCoreModel()

        guard let commandQueue = device.makeCommandQueue() else { return nil }
        guard let library = device.makeDefaultLibrary() else { return nil }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "particleFragment")
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else { return nil }
        guard let particleBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * model.particles.count, options: .storageModeShared) else { return nil }
        guard let uniformsBuffer = device.makeBuffer(length: MemoryLayout<ParticleCoreFrameUniforms>.stride, options: .storageModeShared) else { return nil }

        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.particleBuffer = particleBuffer
        self.uniformsBuffer = uniformsBuffer

        super.init()
        uploadParticles()
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        let elapsed = Float(CACurrentMediaTime() - startTime)
        let resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        let breathing = 0.018 * sin(elapsed * 1.35) + 0.01 * sin(elapsed * 0.53)
        var uniforms = ParticleCoreFrameUniforms(time: elapsed, breathing: breathing, resolution: resolution, seed: 0xA7F13, particleCount: UInt32(model.particles.count))
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<ParticleCoreFrameUniforms>.stride)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: model.particles.count)
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
