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
        let thinkingState = visualStateMapper.map(mode: .thinking)
        let speakingState = visualStateMapper.map(mode: .speaking)
        let outputText = providerRouter.routeMockProvider()
        let traceEvents = [
            TraceEvent(type: .runtimeStep, message: "Received runtime step request."),
            TraceEvent(type: .providerMock, message: "Mock provider routed inside RuntimeCore."),
            TraceEvent(type: .visualStateChanged, message: "Visual state mapped for runtime response.")
        ]

        traceEvents.forEach { traceRecorder.record($0) }

        return RuntimeStepResponse(
            outputText: outputText,
            visualState: visualStateMapper.map(mode: speakingState.mode == .speaking ? .idle : thinkingState.mode),
            traceEvents: traceEvents,
            diagnostics: RuntimeDiagnostics(runtimeStepCount: 1, providerMode: "mock")
        )
    }
}
