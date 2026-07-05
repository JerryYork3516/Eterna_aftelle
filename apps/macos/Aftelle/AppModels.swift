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

public enum ParticleAvatarMode: String, CaseIterable, Identifiable {
    case particleCore = "particle_core"
    case abstractBustReserved = "abstract_bust_reserved"

    public var id: String {
        rawValue
    }

    var localizedKey: String {
        switch self {
        case .particleCore:
            return "particleDebug.avatarMode.particleCore"
        case .abstractBustReserved:
            return "particleDebug.avatarMode.abstractBustReserved"
        }
    }

    var renderFallback: String {
        "particle_core"
    }

    var renderFallbackReason: String {
        switch self {
        case .particleCore:
            return "active_renderer"
        case .abstractBustReserved:
            return "reserved_not_implemented"
        }
    }

    var particleCoreStatus: String {
        switch self {
        case .particleCore:
            return "current / enabled"
        case .abstractBustReserved:
            return "fallback / enabled"
        }
    }

    var abstractBustStatus: String {
        switch self {
        case .particleCore:
            return "reserved / disabled"
        case .abstractBustReserved:
            return "selected / reserved / disabled"
        }
    }
}

public enum ParticleSubtitlePhase: Equatable {
    case hidden
    case showing
    case fading
}

public struct ParticleSubtitleState: Equatable {
    public var text: String
    public var phase: ParticleSubtitlePhase

    public static let hidden = ParticleSubtitleState(text: "", phase: .hidden)

    public init(text: String = "", phase: ParticleSubtitlePhase = .hidden) {
        self.text = text
        self.phase = text.isEmpty ? .hidden : phase
    }
}

public struct ParticleRenderMetrics: Equatable {
    public var fps: Double
    public var particleCount: Int
    public var drawableSize: String
    public var preferredFramesPerSecond: Int
    public var currentVisualState: String
    public var previousVisualState: String
    public var stateElapsedTime: Double
    public var lastTransitionReason: String
    public var mouseInfluenceEnabled: Bool
    public var mouseInsideParticleArea: Bool
    public var interactionStrength: Double

    public static let empty = ParticleRenderMetrics(
        fps: 0,
        particleCount: 0,
        drawableSize: "-",
        preferredFramesPerSecond: 0,
        currentVisualState: "idle",
        previousVisualState: "idle",
        stateElapsedTime: 0,
        lastTransitionReason: "startup",
        mouseInfluenceEnabled: true,
        mouseInsideParticleArea: false,
        interactionStrength: 0
    )
}

public struct ParticleDebugSnapshot: Equatable {
    public var fps: Double
    public var particleCount: Int
    public var drawableSize: String
    public var preferredFramesPerSecond: Int
    public var currentVisualState: String
    public var previousVisualState: String
    public var stateElapsedTime: Double
    public var lastTransitionReason: String
    public var sourceAvatarState: String
    public var mappedParticleState: String
    public var isDebugOverrideActive: Bool
    public var avatarMode: String
    public var particleCoreModeStatus: String
    public var abstractBustModeStatus: String
    public var renderFallback: String
    public var renderFallbackReason: String
    public var colorProfileSource: String
    public var baseColor: String
    public var ridgeColor: String
    public var highlightColor: String
    public var fallbackUsed: Bool
    public var subtitlePhase: String
    public var hasSubtitleText: Bool
    public var mouseInfluenceEnabled: Bool
    public var mouseInsideParticleArea: Bool
    public var interactionStrength: Double
    public var runtimeCoreModified: Bool
    public var runtimeAPIModified: Bool
    public var drSchemaModified: Bool
    public var providerTTSConnected: Bool

    public static let empty = ParticleDebugSnapshot(
        fps: 0,
        particleCount: 0,
        drawableSize: "-",
        preferredFramesPerSecond: 0,
        currentVisualState: "idle",
        previousVisualState: "idle",
        stateElapsedTime: 0,
        lastTransitionReason: "startup",
        sourceAvatarState: "mode=idle presence=unknown",
        mappedParticleState: "idle",
        isDebugOverrideActive: false,
        avatarMode: "particle_core",
        particleCoreModeStatus: "current / enabled",
        abstractBustModeStatus: "reserved / disabled",
        renderFallback: "particle_core",
        renderFallbackReason: "active_renderer",
        colorProfileSource: "systemDefault",
        baseColor: "0.82, 0.84, 0.88",
        ridgeColor: "0.95, 0.96, 0.98",
        highlightColor: "0.98, 0.99, 1.00",
        fallbackUsed: true,
        subtitlePhase: "hidden",
        hasSubtitleText: false,
        mouseInfluenceEnabled: true,
        mouseInsideParticleArea: false,
        interactionStrength: 0,
        runtimeCoreModified: false,
        runtimeAPIModified: false,
        drSchemaModified: false,
        providerTTSConnected: false
    )
}

struct AppParticleVisualStateMapper {
    static func map(
        visualStateMode: String? = nil,
        avatarState: AppAvatarState? = nil,
        residentState: AppResidentState? = nil,
        startupState: AppStartupState = .idle,
        runtimeState: AppRuntimeState = .idle
    ) -> ParticleCoreVisualState {
        let tokens = [
            visualStateMode,
            avatarState?.mode,
            avatarState?.presence,
            avatarState?.moodHint,
            avatarState?.activityHint,
            avatarState?.particleHint,
            residentState?.lifecycleStatus,
            residentState?.presence,
            residentState?.avatarMode,
            startupToken(for: startupState),
            runtimeToken(for: runtimeState)
        ]

        if matches(tokens, ["error", "failed", "failure", "unavailable", "degraded"]) {
            return .error
        }
        if matches(tokens, ["exit", "exiting", "closing", "dismissed"]) {
            return .exit
        }
        if runtimeState == .cancelled || runtimeState == .interrupted {
            return .idle
        }
        if matches(tokens, ["speaking", "responding", "outputting", "active"]) {
            return .speaking
        }
        if matches(tokens, ["loading", "connecting", "preparing", "waiting"]) {
            return .loading
        }
        if matches(tokens, ["thinking", "reasoning", "processing", "composing", "focused"]) {
            return .thinking
        }
        return .idle
    }

    private static func startupToken(for state: AppStartupState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .loaded:
            return "idle"
        case .failed:
            return "failed"
        }
    }

    private static func runtimeToken(for state: AppRuntimeState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .running:
            return "processing"
        case .cancelled:
            return "idle"
        case .interrupted:
            return "idle"
        }
    }

    private static func matches(_ values: [String?], _ candidates: [String]) -> Bool {
        values.contains { value in
            guard let value else { return false }
            let normalized = value.lowercased()
            return candidates.contains { normalized.contains($0) }
        }
    }
}

public struct AppDialogueEntryState: Equatable, Identifiable {
    public var id: String
    public var role: String
    public var text: String
    public var timestamp: String

    public init(id: String, role: String, text: String, timestamp: String) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

public struct AppSessionState: Equatable {
    public var residentID: String
    public var sessionID: String
    public var lastUserInput: String
    public var lastResidentOutput: String
    public var lastActivity: String
    public var shutdownState: String
    public var recoveryRequired: Bool
    public var recoveredAt: String
    public var dialogueEntries: [AppDialogueEntryState]

    public init(
        residentID: String = "",
        sessionID: String = "",
        lastUserInput: String = "",
        lastResidentOutput: String = "",
        lastActivity: String = "",
        shutdownState: String = "unknown",
        recoveryRequired: Bool = false,
        recoveredAt: String = "",
        dialogueEntries: [AppDialogueEntryState] = []
    ) {
        self.residentID = residentID
        self.sessionID = sessionID
        self.lastUserInput = lastUserInput
        self.lastResidentOutput = lastResidentOutput
        self.lastActivity = lastActivity
        self.shutdownState = shutdownState
        self.recoveryRequired = recoveryRequired
        self.recoveredAt = recoveredAt
        self.dialogueEntries = dialogueEntries
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
    public var shutdownState: String
    public var recoveryRequired: Bool
    public var recoveredAt: String

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
        cancellationStatus: String = "",
        shutdownState: String = "unknown",
        recoveryRequired: Bool = false,
        recoveredAt: String = ""
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
        self.shutdownState = shutdownState
        self.recoveryRequired = recoveryRequired
        self.recoveredAt = recoveredAt
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

    public func restoreMostRecentSession() -> RuntimeSessionRestoreResult {
        prepare()
        let result = runtimeCore.restoreMostRecentSession()
        lastDiagnostics = OrchestrationKernelDiagnostics(stateSummary: result.didRestore ? "session_restored" : "session_restore_empty")
        return result
    }

    func saveCurrentSession(
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String,
        avatarState: AvatarState,
        dialogueEntries: [RuntimeDialogueEntryState]
    ) {
        runtimeCore.saveCurrentSession(
            lastUserInput: lastUserInput,
            lastResidentOutput: lastResidentOutput,
            lastActivity: lastActivity,
            avatarState: avatarState,
            dialogueEntries: dialogueEntries
        )
    }

    func markSessionUnclean(
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String,
        avatarState: AvatarState,
        dialogueEntries: [RuntimeDialogueEntryState]
    ) {
        runtimeCore.markSessionUnclean(
            lastUserInput: lastUserInput,
            lastResidentOutput: lastResidentOutput,
            lastActivity: lastActivity,
            avatarState: avatarState,
            dialogueEntries: dialogueEntries
        )
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
