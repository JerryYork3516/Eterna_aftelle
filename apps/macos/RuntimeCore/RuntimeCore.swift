import Foundation

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

public struct RuntimeLoadResult {
    public let isLoaded: Bool
    public let residentID: String
    public let displayName: String
    public let statusMessage: String
    public let diagnostics: String
}

public final class RuntimeCore {
    private let drLoader: DRLoader
    private let executionEngine: ExecutionEngine

    public init(
        drLoader: DRLoader = DRLoader(),
        executionEngine: ExecutionEngine = ExecutionEngine()
    ) {
        self.drLoader = drLoader
        self.executionEngine = executionEngine
    }

    public func loadDR(from data: Data) -> RuntimeLoadResult {
        do {
            let loadedDR = try drLoader.load(drData: data)
            return RuntimeLoadResult(
                isLoaded: true,
                residentID: loadedDR.residentID,
                displayName: loadedDR.displayName,
                statusMessage: "DR loaded",
                diagnostics: "OK"
            )
        } catch {
            return RuntimeLoadResult(
                isLoaded: false,
                residentID: "",
                displayName: "",
                statusMessage: "DR load failed",
                diagnostics: "Read-only fixture load failed"
            )
        }
    }

    public func step(inputText: String) -> RuntimeStepResponse {
        let request = RuntimeStepRequest(residentID: "", inputText: inputText)
        return executionEngine.step(request: request)
    }
}
