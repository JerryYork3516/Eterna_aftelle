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
    var stateElapsedTime: Float
    var globalScale: Float
    var pointSizeScale: Float
    var brightness: Float
    var alphaScale: Float
    var ridgeBrightness: Float
    var breathingAmount: Float
    var flowStrength: Float
    var flowSpeed: Float
    var rotationSpeed: Float
    var rotationDirection: Float
    var edgeScatterAmount: Float
    var edgeDustAmount: Float
    var edgeFrayAmount: Float
    var surfaceLightStrength: Float
    var baseColor: SIMD4<Float>
    var ridgeColor: SIMD4<Float>
    var dimColor: SIMD4<Float>
    var highlightColor: SIMD4<Float>
    var colorAlphaScale: Float
    var bodyTransform: SIMD4<Float>
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
    private var model: ParticleCoreModel
    private var frameSeed: UInt32
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let particleBuffer: MTLBuffer
    private let uniformsBuffer: MTLBuffer
    private let startTime = CACurrentMediaTime()
    private var stateStartTime = CACurrentMediaTime()
    private var metricsStartTime = CACurrentMediaTime()
    private var metricsFrameCount = 0
    private var targetMousePosition = SIMD2<Float>(repeating: 0)
    private var targetMouseVelocity = SIMD2<Float>(repeating: 0)
    private var targetMouseInfluence: Float = 0
    private var smoothMousePosition = SIMD2<Float>(repeating: 0)
    private var smoothMouseVelocity = SIMD2<Float>(repeating: 0)
    private var smoothMouseInfluence: Float = 0
    private var lastMouseEventTime = CACurrentMediaTime()
    private var visualState: ParticleCoreVisualState
    private var previousVisualState: ParticleCoreVisualState
    private var lastTransitionReason = "startup"
    private var smoothThinkingStrength: Float
    private var smoothSpeakingStrength: Float
    private var smoothLoadingStrength: Float
    private var smoothErrorStrength: Float
    private var smoothExitStrength: Float
    private var tuning = ParticleCoreTuning.systemDefault
    private var colorProfile = ParticleCoreColorProfile.systemDefault
    var debugMetricsHandler: ((ParticleRenderMetrics) -> Void)?

    init?(device: MTLDevice, visualState: ParticleCoreVisualState = .idle) {
        let launchSeed = UInt64.random(in: 1...UInt64.max)
        self.device = device
        self.model = ParticleCoreModel(seed: launchSeed)
        self.frameSeed = UInt32(truncatingIfNeeded: launchSeed ^ (launchSeed >> 32))
        self.visualState = visualState
        self.previousVisualState = visualState
        self.smoothThinkingStrength = visualState.targetStrength(for: .thinking)
        self.smoothSpeakingStrength = visualState.targetStrength(for: .speaking)
        self.smoothLoadingStrength = visualState.targetStrength(for: .loading)
        self.smoothErrorStrength = visualState.targetStrength(for: .error)
        self.smoothExitStrength = visualState.targetStrength(for: .exit)

        guard let commandQueue = device.makeCommandQueue() else {
            print("[ParticleCore] commandQueue failed")
            return nil
        }

        guard let library = device.makeDefaultLibrary() else {
            print("[ParticleCore] defaultLibrary failed")
            return nil
        }

        guard let vertexFunction = library.makeFunction(name: "particleVertex"),
              let fragmentFunction = library.makeFunction(name: "particleFragment") else {
            print("[ParticleCore] shader functions missing particleVertex=\(library.makeFunction(name: "particleVertex") != nil) particleFragment=\(library.makeFunction(name: "particleFragment") != nil)")
            return nil
        }

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

        self.commandQueue = commandQueue
        self.particleBuffer = particleBuffer
        self.uniformsBuffer = uniformsBuffer

        super.init()
        uploadParticles()
    }

    func draw(in view: MTKView) {
        let drawableSize = view.drawableSize
        metricsFrameCount += 1

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        let elapsed = Float(CACurrentMediaTime() - startTime)
        let stateAge = Float(CACurrentMediaTime() - stateStartTime)
        let stateElapsedTime: Float
        if visualState == .exit {
            stateElapsedTime = stateAge
        } else {
            stateElapsedTime = 0
        }
        updateSmoothedMouse(elapsedTime: CACurrentMediaTime())
        updateSmoothedVisualState()
        let speedPhaseRate: Float = 0.025
        let motionElapsed = 0.42 * elapsed + (0.08 / speedPhaseRate) * (1 - cos(elapsed * speedPhaseRate))
        let resolution = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        let tunedBreathTime = motionElapsed * sliderScale(tuning.breathingSpeed, minimum: 0.16, maximum: 3.0)
        let breathingAmount = sliderScale(tuning.breathingAmount, minimum: 0, maximum: 3.0)
        let breathing = (0.018 * sin(tunedBreathTime * 0.25) + 0.010 * sin(tunedBreathTime * 0.13 + 0.9)) * breathingAmount
        let edgeBreathing = (0.034 * sin(tunedBreathTime * 0.21 + 1.4) + 0.018 * sin(tunedBreathTime * 0.39 + 0.3)) * breathingAmount
        let coreStability = 1 - min(0.050, abs(breathing) * 0.18)
        let bodyTransform = Self.bodyTransform(for: motionElapsed, state: visualState)
        var uniforms = ParticleCoreFrameUniforms(
            time: motionElapsed,
            breathing: breathing,
            edgeBreathing: edgeBreathing,
            coreStability: coreStability,
            resolution: resolution,
            seed: frameSeed,
            particleCount: UInt32(model.particles.count),
            mousePosition: smoothMousePosition,
            mouseVelocity: smoothMouseVelocity,
            mouseInfluence: smoothMouseInfluence,
            visualState: visualState.rawValue,
            thinkingStrength: smoothThinkingStrength,
            speakingStrength: smoothSpeakingStrength,
            loadingStrength: smoothLoadingStrength,
            errorStrength: smoothErrorStrength,
            exitStrength: smoothExitStrength,
            stateElapsedTime: stateElapsedTime,
            globalScale: Float(tuning.globalScale),
            pointSizeScale: Float(tuning.pointSizeScale),
            brightness: Float(tuning.brightness),
            alphaScale: Float(tuning.alphaScale),
            ridgeBrightness: Float(tuning.ridgeBrightness),
            breathingAmount: Float(tuning.breathingAmount),
            flowStrength: Float(tuning.flowStrength),
            flowSpeed: Float(tuning.flowSpeed),
            rotationSpeed: Float(tuning.rotationSpeed),
            rotationDirection: Float(tuning.rotationDirection),
            edgeScatterAmount: Float(tuning.edgeScatterAmount),
            edgeDustAmount: Float(tuning.edgeDustAmount),
            edgeFrayAmount: Float(tuning.edgeFrayAmount),
            surfaceLightStrength: Float(tuning.surfaceLightStrength),
            baseColor: colorProfile.baseVector,
            ridgeColor: colorProfile.ridgeVector,
            dimColor: colorProfile.dimVector,
            highlightColor: colorProfile.highlightVector,
            colorAlphaScale: Float(colorProfile.alphaScale),
            bodyTransform: bodyTransform
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<ParticleCoreFrameUniforms>.stride)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: model.particles.count)
        publishDebugMetricsIfNeeded(view: view, stateElapsedTime: stateAge)
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

    func setVisualState(_ visualState: ParticleCoreVisualState, reason: String = "appMapping") {
        let now = CACurrentMediaTime()
        if self.visualState == visualState {
            if visualState == .exit {
                stateStartTime = now
            }
            lastTransitionReason = reason
            return
        }
        previousVisualState = self.visualState
        self.visualState = visualState
        stateStartTime = now
        lastTransitionReason = reason
        if visualState == .idle {
            smoothExitStrength = 0
        }
        print("[ParticleCore] visualState changed \(visualState) previous=\(previousVisualState) reason=\(reason)")
    }

    func setTuning(_ tuning: ParticleCoreTuning) {
        let nextTuning = tuning.clamped()
        let nextSeed = Self.modelSeed(for: nextTuning.shapeSeed)
        let nextRoundness = Self.modelShapeValue(for: nextTuning.roundness)
        let nextSurfaceReliefSize = Self.modelShapeValue(for: nextTuning.surfaceReliefSize)
        self.tuning = nextTuning
        guard model.seed != nextSeed
            || model.roundness != nextRoundness
            || model.surfaceReliefSize != nextSurfaceReliefSize else { return }
        model = ParticleCoreModel(
            seed: nextSeed,
            roundness: nextRoundness,
            surfaceReliefSize: nextSurfaceReliefSize
        )
        frameSeed = Self.frameSeed(for: nextSeed)
        uploadParticles()
    }

    func setColorProfile(_ colorProfile: ParticleCoreColorProfile) {
        self.colorProfile = colorProfile.clamped()
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
        let exitAlpha: Float = visualState == .exit ? 0.080 : 0.050
        smoothExitStrength += (visualState.targetStrength(for: .exit) - smoothExitStrength) * exitAlpha
    }

    private func publishDebugMetricsIfNeeded(view: MTKView, stateElapsedTime: Float) {
        let now = CACurrentMediaTime()
        let interval = now - metricsStartTime
        guard interval >= 1 else { return }

        let fps = Double(metricsFrameCount) / max(interval, 0.001)
        metricsFrameCount = 0
        metricsStartTime = now
        let drawableSize = "\(Int(view.drawableSize.width))x\(Int(view.drawableSize.height))"
        let mouseActive = smoothMouseInfluence > 0.01 || targetMouseInfluence > 0.01
        let metrics = ParticleRenderMetrics(
            fps: fps,
            particleCount: model.particles.count,
            drawableSize: drawableSize,
            preferredFramesPerSecond: view.preferredFramesPerSecond,
            currentVisualState: String(describing: visualState),
            previousVisualState: String(describing: previousVisualState),
            stateElapsedTime: Double(stateElapsedTime),
            lastTransitionReason: lastTransitionReason,
            mouseInfluenceEnabled: true,
            mouseInsideParticleArea: mouseActive,
            interactionStrength: Double(smoothMouseInfluence)
        )
        debugMetricsHandler?(metrics)
        print("[ParticleCore] snapshot fps=\(String(format: "%.1f", fps)) particleCount=\(model.particles.count) drawableSize=\(drawableSize) preferredFPS=\(view.preferredFramesPerSecond) visualState=\(visualState) previousVisualState=\(previousVisualState) stateElapsedTime=\(String(format: "%.2f", stateElapsedTime)) reason=\(lastTransitionReason) mouseInside=\(mouseActive) interactionStrength=\(String(format: "%.2f", smoothMouseInfluence))")
    }

    private func sliderScale(_ value: Double, minimum: Float, maximum: Float) -> Float {
        minimum + (maximum - minimum) * min(1, max(0, Float(value)))
    }

    private static func bodyTransform(for time: Float, state: ParticleCoreVisualState) -> SIMD4<Float> {
        let stateLift: Float
        switch state {
        case .thinking:
            stateLift = 0.006
        case .speaking:
            stateLift = 0.010
        case .loading:
            stateLift = -0.006
        case .error:
            stateLift = 0
        case .exit:
            stateLift = 0.008
        case .idle:
            stateLift = 0
        }

        let x = sin(time * 0.055 + 0.8) * 0.012
            + sin(time * 0.029 + 2.4) * 0.006
        let y = cos(time * 0.050 + 1.1) * 0.010
            + sin(time * 0.035 + 4.2) * 0.005
            + stateLift
        let scale: Float = 1
        return SIMD4<Float>(x, y, scale, 0)
    }

    private static func modelSeed(for value: Double) -> UInt64 {
        let bucket = UInt64((min(1, max(0, value)) * 4095).rounded())
        return 0xA7F7E11E9E3779B9 &+ bucket &* 0x9E3779B97F4A7C15
    }

    private static func modelShapeValue(for value: Double) -> Float {
        Float((min(1, max(0, value)) * 64).rounded() / 64)
    }

    private static func frameSeed(for seed: UInt64) -> UInt32 {
        UInt32(truncatingIfNeeded: seed ^ (seed >> 32))
    }
}
