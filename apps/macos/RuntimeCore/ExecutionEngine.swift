import Foundation

public final class ExecutionEngine {
    public init() {}

    public func step(request: RuntimeStepRequest) -> RuntimeStepResponse {
        let traceEvents = [
            TraceEvent(type: .runtimeStep, message: "Received runtime step request."),
            TraceEvent(type: .providerMock, message: "Mock provider routed inside RuntimeCore."),
            TraceEvent(type: .visualStateChanged, message: "Visual state mapped for runtime response.")
        ]

        return RuntimeStepResponse(
            outputText: "",
            visualState: VisualState(mode: .idle),
            traceEvents: traceEvents,
            diagnostics: RuntimeDiagnostics(runtimeStepCount: 1, providerMode: "mock")
        )
    }
}
