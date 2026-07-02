import Foundation

public final class RuntimeCore {
    public let drLoader: DRLoader
    public let executionEngine: ExecutionEngine
    public let providerRouter: ProviderRouter
    public let traceRecorder: TraceRecorder
    public let visualStateMapper: VisualStateMapper

    public init(
        drLoader: DRLoader = DRLoader(),
        executionEngine: ExecutionEngine = ExecutionEngine(),
        providerRouter: ProviderRouter = ProviderRouter(),
        traceRecorder: TraceRecorder = TraceRecorder(),
        visualStateMapper: VisualStateMapper = VisualStateMapper()
    ) {
        self.drLoader = drLoader
        self.executionEngine = executionEngine
        self.providerRouter = providerRouter
        self.traceRecorder = traceRecorder
        self.visualStateMapper = visualStateMapper
    }
}

public struct RuntimeStepRequest {
    public var residentID: String
    public var inputText: String

    public init(residentID: String, inputText: String) {
        self.residentID = residentID
        self.inputText = inputText
    }
}

public struct RuntimeStepResponse {
    public var outputText: String
    public var visualState: VisualState
    public var traceEvents: [TraceEvent]
    public var diagnostics: RuntimeDiagnostics

    public init(
        outputText: String,
        visualState: VisualState,
        traceEvents: [TraceEvent],
        diagnostics: RuntimeDiagnostics
    ) {
        self.outputText = outputText
        self.visualState = visualState
        self.traceEvents = traceEvents
        self.diagnostics = diagnostics
    }
}

public struct RuntimeDiagnostics {
    public var runtimeStepCount: Int
    public var providerMode: String

    public init(runtimeStepCount: Int = 0, providerMode: String = "mock") {
        self.runtimeStepCount = runtimeStepCount
        self.providerMode = providerMode
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
