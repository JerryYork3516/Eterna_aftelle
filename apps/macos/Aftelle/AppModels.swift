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

public struct AppSessionState: Equatable {
    public var residentID: String
    public var sessionID: String

    public init(residentID: String = "", sessionID: String = "") {
        self.residentID = residentID
        self.sessionID = sessionID
    }
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

public struct AppResidentState: Equatable {
    public var residentID: String
    public var sessionID: String
    public var lifecycleStatus: String
    public var presence: String
    public var lastActivitySummary: String
    public var lastUpdatedAt: String
    public var avatarMode: String

    public init(
        residentID: String = "",
        sessionID: String = "",
        lifecycleStatus: String = "loaded",
        presence: String = "unknown",
        lastActivitySummary: String = "",
        lastUpdatedAt: String = "",
        avatarMode: String = ""
    ) {
        self.residentID = residentID
        self.sessionID = sessionID
        self.lifecycleStatus = lifecycleStatus
        self.presence = presence
        self.lastActivitySummary = lastActivitySummary
        self.lastUpdatedAt = lastUpdatedAt
        self.avatarMode = avatarMode
    }
}

public struct RuntimeTraceEntryViewState: Equatable, Identifiable {
    public var id: String
    public var type: String
    public var message: String

    public init(id: String, type: String, message: String) {
        self.id = id
        self.type = type
        self.message = message
    }
}

public struct RuntimeTraceViewState: Equatable {
    public var summary: String
    public var entries: [RuntimeTraceEntryViewState]

    public init(summary: String = "", entries: [RuntimeTraceEntryViewState] = []) {
        self.summary = summary
        self.entries = entries
    }
}

public struct RuntimeClockViewState: Equatable {
    public var tickCount: Int
    public var lastTickSummary: String

    public init(tickCount: Int = 0, lastTickSummary: String = "") {
        self.tickCount = tickCount
        self.lastTickSummary = lastTickSummary
    }
}

public struct DebugPanelViewState: Equatable {
    public var residentID: String
    public var sessionID: String
    public var lifecycleStatus: String
    public var presence: String
    public var avatarMode: String
    public var lastActivitySummary: String
    public var traceSummary: String
    public var tickCount: Int
    public var clockStatus: String
    public var cancellationStatus: String

    public init(
        residentID: String = "",
        sessionID: String = "",
        lifecycleStatus: String = "",
        presence: String = "",
        avatarMode: String = "",
        lastActivitySummary: String = "",
        traceSummary: String = "",
        tickCount: Int = 0,
        clockStatus: String = "",
        cancellationStatus: String = ""
    ) {
        self.residentID = residentID
        self.sessionID = sessionID
        self.lifecycleStatus = lifecycleStatus
        self.presence = presence
        self.avatarMode = avatarMode
        self.lastActivitySummary = lastActivitySummary
        self.traceSummary = traceSummary
        self.tickCount = tickCount
        self.clockStatus = clockStatus
        self.cancellationStatus = cancellationStatus
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

    public init(runtimeCore: RuntimeCore) {
        self.runtimeCore = runtimeCore
    }

    @MainActor
    public convenience init() {
        self.init(runtimeCore: RuntimeCore())
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
        lastDiagnostics = OrchestrationKernelDiagnostics(stateSummary: "passthrough_step")
        return runtimeCore.step(request: RuntimeStepRequest(residentID: residentID, inputText: inputText))
    }

    public func cancelCurrentStep() {
        runtimeCore.cancelCurrentStep()
    }

    public func interrupt() {
        runtimeCore.interrupt(request: RuntimeCancellationRequest(reason: .interrupted))
    }

    public func runtimeTick() -> RuntimeTickResponse {
        runtimeCore.runtimeTick()
    }
}
