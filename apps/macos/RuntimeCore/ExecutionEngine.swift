import Foundation

public final class ExecutionEngine {
    private let providerRouter: ProviderRouter
    private let traceRecorder: TraceRecorder
    private let visualStateMapper: VisualStateMapper

    public init(
        providerRouter: ProviderRouter = ProviderRouter(),
        traceRecorder: TraceRecorder = TraceRecorder(),
        visualStateMapper: VisualStateMapper = VisualStateMapper()
    ) {
        self.providerRouter = providerRouter
        self.traceRecorder = traceRecorder
        self.visualStateMapper = visualStateMapper
    }

    public func step(request: RuntimeStepRequest) -> RuntimeStepResponse {
        let traceEvents = [
            TraceEvent(type: .runtimeStep, message: "Received runtime step request."),
            TraceEvent(type: .providerMock, message: "Mock provider routed inside RuntimeCore."),
            TraceEvent(type: .visualStateChanged, message: "Visual state mapped for runtime response.")
        ]

        traceEvents.forEach { traceRecorder.record($0) }

        return RuntimeStepResponse(
            outputText: providerRouter.routeMockProvider(),
            visualState: visualStateMapper.map(mode: .thinking),
            traceEvents: traceEvents,
            diagnostics: RuntimeDiagnostics(runtimeStepCount: 1, providerMode: "mock")
        )
    }
}
