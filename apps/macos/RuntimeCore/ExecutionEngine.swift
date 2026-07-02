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
        let hasInput = !request.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let traceEvents = [
            TraceEvent(type: .runtimeStep, message: hasInput ? "Received runtime step request." : "Received empty runtime step request."),
            TraceEvent(type: .providerMock, message: "Mock provider routed inside RuntimeCore."),
            TraceEvent(type: .visualStateChanged, message: "Visual state mapped for runtime response.")
        ]

        traceEvents.forEach { traceRecorder.record($0) }

        return RuntimeStepResponse(
            outputText: providerRouter.routeMockProvider(),
            visualState: visualStateMapper.map(mode: .speaking),
            traceEvents: traceEvents,
            diagnostics: RuntimeDiagnostics(runtimeStepCount: 1, providerMode: "mock")
        )
    }
}
