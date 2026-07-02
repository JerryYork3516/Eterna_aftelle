import Foundation

public enum AppStartupState {
    case idle
    case loading
    case loaded
    case failed
}

public enum AppRuntimeState: Equatable {
    case idle
    case running
    case cancelled
    case interrupted
}

public struct AppAvatarState: Equatable {
    public var residentID: String
    public var displayName: String
    public var mode: String
    public var presence: String
    public var moodHint: String
    public var activityHint: String
    public var particleHint: String

    public init(
        residentID: String = "",
        displayName: String = "",
        mode: String = "idle",
        presence: String = "unknown",
        moodHint: String = "",
        activityHint: String = "",
        particleHint: String = ""
    ) {
        self.residentID = residentID
        self.displayName = displayName
        self.mode = mode
        self.presence = presence
        self.moodHint = moodHint
        self.activityHint = activityHint
        self.particleHint = particleHint
    }
}

public struct OrchestrationKernelDiagnostics: Equatable {
    public var stateSummary: String

    public init(stateSummary: String = "unprepared") {
        self.stateSummary = stateSummary
    }
}

@MainActor
public final class OrchestrationKernel {
    private let runtimeCore: RuntimeCore
    private var isPrepared = false
    private var lastDiagnostics = OrchestrationKernelDiagnostics()

    public init(runtimeCore: RuntimeCore = RuntimeCore()) {
        self.runtimeCore = runtimeCore
    }

    public func prepare() {
        isPrepared = true
        lastDiagnostics = OrchestrationKernelDiagnostics(stateSummary: "prepared")
    }

    public func currentDiagnostics() -> OrchestrationKernelDiagnostics {
        lastDiagnostics
    }

    public func loadResident(fixtureData: Data) -> RuntimeLoadResult {
        prepare()
        let result = runtimeCore.loadDR(request: RuntimeLoadRequest(drData: fixtureData))
        lastDiagnostics = OrchestrationKernelDiagnostics(stateSummary: result.isLoaded ? "resident_loaded" : "resident_load_failed")
        return result
    }

    public func step(residentID: String, inputText: String) -> RuntimeStepResponse {
        prepare()
        return runtimeCore.step(request: RuntimeStepRequest(residentID: residentID, inputText: inputText))
    }

    public func cancelCurrentStep() {
        runtimeCore.cancelCurrentStep()
    }

    public func interrupt() {
        runtimeCore.interrupt(request: RuntimeCancellationRequest(reason: .interrupted))
    }
}
