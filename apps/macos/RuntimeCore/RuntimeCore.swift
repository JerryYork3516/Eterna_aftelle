import Foundation

public struct RuntimeStepRequest {
    public var residentID: String
    public var inputText: String

    public init(residentID: String, inputText: String) {
        self.residentID = residentID
        self.inputText = inputText
    }
}

public struct RuntimeLoadRequest {
    public var drData: Data

    public init(drData: Data) {
        self.drData = drData
    }
}

public enum RuntimeInterruptReason: String {
    case cancelled
    case interrupted
}

public struct RuntimeCancellationRequest {
    public var reason: RuntimeInterruptReason

    public init(reason: RuntimeInterruptReason) {
        self.reason = reason
    }
}

public struct RuntimeCancellationState {
    public var isCancelled: Bool
    public var reason: RuntimeInterruptReason?

    public init(isCancelled: Bool = false, reason: RuntimeInterruptReason? = nil) {
        self.isCancelled = isCancelled
        self.reason = reason
    }

    public static let none = RuntimeCancellationState()
}

public struct AvatarState {
    public var residentID: String
    public var displayName: String
    public var mode: String
    public var presence: String
    public var moodHint: String
    public var activityHint: String
    public var particleHint: String
    public var updatedAt: Date

    public init(
        residentID: String,
        displayName: String,
        mode: String,
        presence: String,
        moodHint: String,
        activityHint: String,
        particleHint: String,
        updatedAt: Date = Date()
    ) {
        self.residentID = residentID
        self.displayName = displayName
        self.mode = mode
        self.presence = presence
        self.moodHint = moodHint
        self.activityHint = activityHint
        self.particleHint = particleHint
        self.updatedAt = updatedAt
    }
}

public struct RuntimeStepResponse {
    public var outputText: String
    public var visualState: VisualState
    public var avatarState: AvatarState
    public var cancellationState: RuntimeCancellationState
    public var traceEvents: [TraceEvent]
    public var diagnostics: RuntimeDiagnostics

    public init(
        outputText: String,
        visualState: VisualState,
        avatarState: AvatarState,
        cancellationState: RuntimeCancellationState = .none,
        traceEvents: [TraceEvent],
        diagnostics: RuntimeDiagnostics
    ) {
        self.outputText = outputText
        self.visualState = visualState
        self.avatarState = avatarState
        self.cancellationState = cancellationState
        self.traceEvents = traceEvents
        self.diagnostics = diagnostics
    }
}

public struct RuntimeDiagnostics {
    public var runtimeStepCount: Int
    public var providerMode: String
    public var providerProfileID: String?
    public var providerSecretRefPresent: Bool
    public var providerKeyRefPresent: Bool
    public var cancellationState: String

    public init(
        runtimeStepCount: Int = 0,
        providerMode: String = "mock",
        providerProfileID: String? = nil,
        providerSecretRefPresent: Bool = false,
        providerKeyRefPresent: Bool = false,
        cancellationState: String = "none"
    ) {
        self.runtimeStepCount = runtimeStepCount
        self.providerMode = providerMode
        self.providerProfileID = providerProfileID
        self.providerSecretRefPresent = providerSecretRefPresent
        self.providerKeyRefPresent = providerKeyRefPresent
        self.cancellationState = cancellationState
    }
}

public enum RuntimeStepEventType: String {
    case runtimeStep = "runtime.step"
    case providerMock = "provider.mock"
    case visualStateChanged = "visual_state.changed"
}

public struct TraceEvent {
    public var type: RuntimeStepEventType
    public var message: String

    public init(type: RuntimeStepEventType, message: String) {
        self.type = type
        self.message = message
    }
}

public enum VisualStateMode: String {
    case idle
    case thinking
    case speaking
}

public struct VisualState {
    public var mode: VisualStateMode

    public init(mode: VisualStateMode) {
        self.mode = mode
    }
}

public struct RuntimeLoadResult {
    public let isLoaded: Bool
    public let residentID: String
    public let displayName: String
    public let statusMessage: String
    public let diagnostics: String
    public let avatarState: AvatarState?
}

public final class RuntimeCore {
    private let drLoader: DRLoader
    private let executionEngine: ExecutionEngine
    private let providerRouter: ProviderRouter
    private let hostEnv: HostEnv
    private var cancellationState = RuntimeCancellationState.none

    public init(
        drLoader: DRLoader = DRLoader(),
        executionEngine: ExecutionEngine = ExecutionEngine(),
        providerRouter: ProviderRouter = ProviderRouter(),
        hostEnv: HostEnv = DefaultHostEnv()
    ) {
        self.drLoader = drLoader
        self.executionEngine = executionEngine
        self.providerRouter = providerRouter
        self.hostEnv = hostEnv
    }

    public func loadDR(from data: Data) -> RuntimeLoadResult {
        do {
            let result = try drLoader.load(request: DRLoadRequest(drData: data))
            guard let loadedDR = result.loadedDR, result.isLoaded else {
                return RuntimeLoadResult(
                    isLoaded: false,
                    residentID: "",
                    displayName: "",
                    statusMessage: "DR load failed",
                    diagnostics: result.diagnostics,
                    avatarState: nil
                )
            }

            let avatarState = AvatarState(
                residentID: loadedDR.residentID,
                displayName: loadedDR.displayName,
                mode: "idle",
                presence: "present",
                moodHint: "calm",
                activityHint: "ready",
                particleHint: "calibration_idle"
            )

            return RuntimeLoadResult(
                isLoaded: true,
                residentID: loadedDR.residentID,
                displayName: loadedDR.displayName,
                statusMessage: "DR loaded",
                diagnostics: result.diagnostics,
                avatarState: avatarState
            )
        } catch {
            return RuntimeLoadResult(
                isLoaded: false,
                residentID: "",
                displayName: "",
                statusMessage: "DR load failed",
                diagnostics: "DR load failed",
                avatarState: nil
            )
        }
    }

    public func loadDR(request: RuntimeLoadRequest) -> RuntimeLoadResult {
        loadDR(from: request.drData)
    }

    public func step(inputText: String) -> RuntimeStepResponse {
        let request = RuntimeStepRequest(residentID: "", inputText: inputText)
        return executionEngine.step(request: request)
    }

    public func step(request: RuntimeStepRequest) -> RuntimeStepResponse {
        executionEngine.step(request: request, cancellationState: cancellationState)
    }

    public func cancelCurrentStep() {
        cancellationState = RuntimeCancellationState(isCancelled: true, reason: .cancelled)
    }

    public func interrupt(request: RuntimeCancellationRequest) {
        cancellationState = RuntimeCancellationState(isCancelled: true, reason: request.reason)
    }

    public func currentRuntimeConfig() -> RuntimeConfig {
        hostEnv.runtimeConfig.currentRuntimeConfig()
    }

}
