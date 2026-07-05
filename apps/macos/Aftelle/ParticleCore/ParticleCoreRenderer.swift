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
    var mousePosition: SIMD2<Float>
    var mouseVelocity: SIMD2<Float>
    var mouseInfluence: Float
    var visualState: UInt32
    var thinkingStrength: Float
    var speakingStrength: Float
    var loadingStrength: Float
    var errorStrength: Float
    var exitStrength: Float
}

enum ParticleCoreVisualState: UInt32 {
    case idle
    case thinking
    case speaking
    case loading
    case error
    case exit

    func targetStrength(for state: ParticleCoreVisualState) -> Float {
        self == state ? 1 : 0
    }
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
    private var targetMousePosition = SIMD2<Float>(repeating: 0)
    private var targetMouseVelocity = SIMD2<Float>(repeating: 0)
    private var targetMouseInfluence: Float = 0
    private var smoothMousePosition = SIMD2<Float>(repeating: 0)
    private var smoothMouseVelocity = SIMD2<Float>(repeating: 0)
    private var smoothMouseInfluence: Float = 0
    private var lastMouseEventTime = CACurrentMediaTime()
    private var visualState: ParticleCoreVisualState
    private var smoothThinkingStrength: Float
    private var smoothSpeakingStrength: Float
    private var smoothLoadingStrength: Float
    private var smoothErrorStrength: Float
    private var smoothExitStrength: Float

    init?(device: MTLDevice, visualState: ParticleCoreVisualState = .idle) {
        self.device = device
        self.model = ParticleCoreModel()
        self.visualState = visualState
        self.smoothThinkingStrength = visualState.targetStrength(for: .thinking)
        self.smoothSpeakingStrength = visualState.targetStrength(for: .speaking)
        self.smoothLoadingStrength = visualState.targetStrength(for: .loading)
        self.smoothErrorStrength = visualState.targetStrength(for: .error)
        self.smoothExitStrength = visualState.targetStrength(for: .exit)

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
        updateSmoothedMouse(elapsedTime: CACurrentMediaTime())
        updateSmoothedVisualState()
        let speedPhaseRate: Float = 0.025
        let speedScale = 0.42 + 0.08 * sin(elapsed * speedPhaseRate)
        let motionElapsed = 0.42 * elapsed + (0.08 / speedPhaseRate) * (1 - cos(elapsed * speedPhaseRate))
        let resolution = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        let breathing = 0.010 * sin(motionElapsed * 0.23) + 0.006 * sin(motionElapsed * 0.13 + 0.9)
        let edgeBreathing = 0.012 * sin(motionElapsed * 0.19 + 1.4) + 0.005 * sin(motionElapsed * 0.37 + 0.3)
        let coreStability = 1 - min(0.025, abs(breathing) * 0.16)
        var uniforms = ParticleCoreFrameUniforms(
            time: motionElapsed,
            breathing: breathing,
            edgeBreathing: edgeBreathing,
            coreStability: coreStability,
            resolution: resolution,
            seed: 0xA7F13,
            particleCount: UInt32(model.particles.count),
            mousePosition: smoothMousePosition,
            mouseVelocity: smoothMouseVelocity,
            mouseInfluence: smoothMouseInfluence,
            visualState: visualState.rawValue,
            thinkingStrength: smoothThinkingStrength,
            speakingStrength: smoothSpeakingStrength,
            loadingStrength: smoothLoadingStrength,
            errorStrength: smoothErrorStrength,
            exitStrength: smoothExitStrength
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<ParticleCoreFrameUniforms>.stride)

        if !didLogDraw {
            let aspect = max(resolution.x / max(resolution.y, 1), 1)
            let bounds = model.clipBounds(aspect: aspect, breathing: 1 + breathing)
            print("[ParticleCore] draw called drawableSize=\(Int(drawableSize.width))x\(Int(drawableSize.height)) particleCount=\(model.particles.count) ndcMin=(\(bounds.minX),\(bounds.minY)) ndcMax=(\(bounds.maxX),\(bounds.maxY)) clearColor=(0.035,0.04,0.05,1) visualState=\(visualState) thinkingStrength=\(smoothThinkingStrength) speakingStrength=\(smoothSpeakingStrength) loadingStrength=\(smoothLoadingStrength) errorStrength=\(smoothErrorStrength) exitStrength=\(smoothExitStrength) previewKeys=(I idle,T thinking,S speaking,L loading,E error,X exit) globalBreathingRef=\(breathing) edgeBreathingRef=\(edgeBreathing) coreStability=\(coreStability) motion=video_guided_rotating_surface_field speedScale=\(speedScale) speedRange=0.34...0.50 particleColor=(three_stage_back_front_ion_ridge,back=0.30...0.35,front=0.95...0.98,density_front_gated,no_random_brightness) pointSize=cohesive_body_bound_structure ionCluster=cloud_driven_rolling_ridge cloudDensity=internal_eddy_migration structure=body_envelope_spine_density_sections")
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

    func updateMouse(position: SIMD2<Float>, velocity: SIMD2<Float>, active: Bool) {
        targetMousePosition = position
        targetMouseVelocity = velocity
        targetMouseInfluence = active ? 1 : 0
        lastMouseEventTime = CACurrentMediaTime()
    }

    func setVisualState(_ visualState: ParticleCoreVisualState) {
        guard self.visualState != visualState else { return }
        self.visualState = visualState
        print("[ParticleCore] visualState changed \(visualState)")
    }

    private func uploadParticles() {
        let payloads = model.vertexPayloads
        let pointer = particleBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: payloads.count)
        for (index, payload) in payloads.enumerated() {
            pointer[index] = payload
        }
    }

    private func updateSmoothedMouse(elapsedTime: CFTimeInterval) {
        if elapsedTime - lastMouseEventTime > 0.35 {
            targetMouseInfluence = 0
            targetMouseVelocity = .zero
        }

        let positionAlpha: Float = 0.16
        let velocityAlpha: Float = 0.12
        let influenceAlpha: Float = targetMouseInfluence > smoothMouseInfluence ? 0.18 : 0.06
        smoothMousePosition += (targetMousePosition - smoothMousePosition) * positionAlpha
        smoothMouseVelocity += (targetMouseVelocity - smoothMouseVelocity) * velocityAlpha
        smoothMouseInfluence += (targetMouseInfluence - smoothMouseInfluence) * influenceAlpha
    }

    private func updateSmoothedVisualState() {
        let alpha: Float = 0.036
        smoothThinkingStrength += (visualState.targetStrength(for: .thinking) - smoothThinkingStrength) * alpha
        smoothSpeakingStrength += (visualState.targetStrength(for: .speaking) - smoothSpeakingStrength) * alpha
        smoothLoadingStrength += (visualState.targetStrength(for: .loading) - smoothLoadingStrength) * alpha
        smoothErrorStrength += (visualState.targetStrength(for: .error) - smoothErrorStrength) * alpha
        smoothExitStrength += (visualState.targetStrength(for: .exit) - smoothExitStrength) * alpha
    }
}
