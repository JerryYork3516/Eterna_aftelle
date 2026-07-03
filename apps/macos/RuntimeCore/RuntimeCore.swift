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

public struct RuntimeResidentState {
    public var residentID: String
    public var sessionID: String
    public var lifecycleStatus: String
    public var presence: String
    public var lastActivitySummary: String
    public var lastUpdatedAt: Date
    public var avatarMode: String?

    public init(
        residentID: String,
        sessionID: String,
        lifecycleStatus: String,
        presence: String,
        lastActivitySummary: String,
        lastUpdatedAt: Date = Date(),
        avatarMode: String? = nil
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

public struct RuntimeStepResponse {
    public var outputText: String
    public var visualState: VisualState
    public var avatarState: AvatarState
    public var residentState: RuntimeResidentState
    public var cancellationState: RuntimeCancellationState
    public var traceEvents: [TraceEvent]
    public var diagnostics: RuntimeDiagnostics

    public init(
        outputText: String,
        visualState: VisualState,
        avatarState: AvatarState,
        residentState: RuntimeResidentState,
        cancellationState: RuntimeCancellationState = .none,
        traceEvents: [TraceEvent],
        diagnostics: RuntimeDiagnostics
    ) {
        self.outputText = outputText
        self.visualState = visualState
        self.avatarState = avatarState
        self.residentState = residentState
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

public struct RuntimeSessionID: Equatable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func make() -> RuntimeSessionID {
        RuntimeSessionID(rawValue: UUID().uuidString)
    }
}

public struct RuntimeSessionContext: Equatable {
    public var residentID: String
    public var sessionID: RuntimeSessionID

    public init(residentID: String, sessionID: RuntimeSessionID) {
        self.residentID = residentID
        self.sessionID = sessionID
    }
}

public struct RuntimeClockState: Equatable {
    public var tickCount: Int
    public var lastTickAt: Date?

    public init(tickCount: Int = 0, lastTickAt: Date? = nil) {
        self.tickCount = tickCount
        self.lastTickAt = lastTickAt
    }
}

public struct RuntimeTickRequest {
    public var reason: String

    public init(reason: String = "noop") {
        self.reason = reason
    }
}

public struct RuntimeTickResponse {
    public var clockState: RuntimeClockState
    public var traceEvent: TraceEvent
    public var diagnostics: RuntimeDiagnostics

    public init(clockState: RuntimeClockState, traceEvent: TraceEvent, diagnostics: RuntimeDiagnostics) {
        self.clockState = clockState
        self.traceEvent = traceEvent
        self.diagnostics = diagnostics
    }
}

public struct RuntimeLoadResult {
    public let isLoaded: Bool
    public let residentID: String
    public let sessionID: RuntimeSessionID?
    public let displayName: String
    public let statusMessage: String
    public let diagnostics: String
    public let avatarState: AvatarState?
    public let residentState: RuntimeResidentState?
}

public struct RuntimeDialogueEntryState {
    public var role: String
    public var text: String
    public var timestamp: Date

    public init(role: String, text: String, timestamp: Date) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

public struct RuntimeSessionRestoreResult {
    public let didRestore: Bool
    public let residentID: String
    public let sessionID: String
    public let lastUserInput: String
    public let lastResidentOutput: String
    public let lastActivity: String
    public let shutdownState: SessionShutdownState
    public let recoveryRequired: Bool
    public let recoveredAt: Date?
    public let dialogueEntries: [RuntimeDialogueEntryState]

    public init(
        didRestore: Bool,
        residentID: String = "",
        sessionID: String = "",
        lastUserInput: String = "",
        lastResidentOutput: String = "",
        lastActivity: String = "",
        shutdownState: SessionShutdownState = .unclean,
        recoveryRequired: Bool = false,
        recoveredAt: Date? = nil,
        dialogueEntries: [RuntimeDialogueEntryState] = []
    ) {
        self.didRestore = didRestore
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

public final class RuntimeCore {
    private let drLoader: DRLoader
    private let executionEngine: ExecutionEngine
    private let providerRouter: ProviderRouter
    private let hostEnv: HostEnv
    private let sessionStore: SessionStore
    private let memoryController: MemoryController
    private var cancellationState = RuntimeCancellationState.none
    private var sessionContext: RuntimeSessionContext?
    private var clockState = RuntimeClockState()

    public init(
        drLoader: DRLoader = DRLoader(),
        executionEngine: ExecutionEngine = ExecutionEngine(),
        providerRouter: ProviderRouter = ProviderRouter(),
        hostEnv: HostEnv = DefaultHostEnv(),
        sessionStore: SessionStore = SessionStore(),
        memoryController: MemoryController = MemoryController()
    ) {
        self.drLoader = drLoader
        self.executionEngine = executionEngine
        self.providerRouter = providerRouter
        self.hostEnv = hostEnv
        self.sessionStore = sessionStore
        self.memoryController = memoryController
    }

    public func loadDR(from data: Data) -> RuntimeLoadResult {
        do {
            let result = try drLoader.load(request: DRLoadRequest(drData: data))
            guard let loadedDR = result.loadedDR, result.isLoaded else {
                return RuntimeLoadResult(
                    isLoaded: false,
                    residentID: "",
                    sessionID: nil,
                    displayName: "",
                    statusMessage: "DR load failed",
                    diagnostics: result.diagnostics,
                    avatarState: nil,
                    residentState: nil
                )
            }

            let sessionID = RuntimeSessionID.make()
            sessionContext = RuntimeSessionContext(residentID: loadedDR.residentID, sessionID: sessionID)
            memoryController.setActiveResidentID(loadedDR.residentID)
            let avatarState = AvatarState(
                residentID: loadedDR.residentID,
                displayName: loadedDR.displayName,
                mode: "idle",
                presence: "present",
                moodHint: "calm",
                activityHint: "ready",
                particleHint: "calibration_idle"
            )
            let residentState = RuntimeResidentState(
                residentID: loadedDR.residentID,
                sessionID: sessionID.rawValue,
                lifecycleStatus: "loaded",
                presence: "available",
                lastActivitySummary: "DR loaded",
                lastUpdatedAt: Date(),
                avatarMode: avatarState.mode
            )

            return RuntimeLoadResult(
                isLoaded: true,
                residentID: loadedDR.residentID,
                sessionID: sessionID,
                displayName: loadedDR.displayName,
                statusMessage: "DR loaded",
                diagnostics: result.diagnostics,
                avatarState: avatarState,
                residentState: residentState
            )
        } catch {
            return RuntimeLoadResult(
                isLoaded: false,
                residentID: "",
                sessionID: nil,
                displayName: "",
                statusMessage: "DR load failed",
                diagnostics: "DR load failed",
                avatarState: nil,
                residentState: nil
            )
        }
    }

    public func loadDR(request: RuntimeLoadRequest) -> RuntimeLoadResult {
        loadDR(from: request.drData)
    }

    public func restoreMostRecentSession() -> RuntimeSessionRestoreResult {
        guard let record = try? sessionStore.loadMostRecentRecord() else {
            return RuntimeSessionRestoreResult(didRestore: false)
        }
        guard record.schemaVersion == SessionStore.schemaVersion else {
            return RuntimeSessionRestoreResult(didRestore: false)
        }
        let dialogueEntries = (try? sessionStore.loadMostRecentDialogueEntries()) ?? []
        sessionContext = RuntimeSessionContext(
            residentID: record.residentID,
            sessionID: RuntimeSessionID(rawValue: record.sessionID)
        )
        memoryController.setActiveResidentID(record.residentID)
        let recoveredAt = Date()
        let recoveryRequired = record.shutdownState == .unclean
        let updatedRecord = SessionStoreRecord(
            schemaVersion: record.schemaVersion,
            residentID: record.residentID,
            sessionID: record.sessionID,
            createdAt: record.createdAt,
            updatedAt: recoveredAt,
            lastUserInput: record.lastUserInput,
            lastResidentOutput: record.lastResidentOutput,
            lastActivity: record.lastActivity,
            shutdownState: .unclean,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt
        )
        try? sessionStore.save(record: updatedRecord)
        try? sessionStore.saveDisplayCache(SessionDisplayCache(
            residentID: record.residentID,
            sessionID: record.sessionID,
            lastUserInput: record.lastUserInput,
            lastResidentOutput: record.lastResidentOutput,
            lastActivity: record.lastActivity,
            shutdownState: record.shutdownState,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt,
            updatedAt: recoveredAt
        ))
        return RuntimeSessionRestoreResult(
            didRestore: true,
            residentID: record.residentID,
            sessionID: record.sessionID,
            lastUserInput: record.lastUserInput,
            lastResidentOutput: record.lastResidentOutput,
            lastActivity: record.lastActivity,
            shutdownState: record.shutdownState,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt,
            dialogueEntries: dialogueEntries.map {
                RuntimeDialogueEntryState(role: $0.role, text: $0.text, timestamp: $0.timestamp)
            }
        )
    }

    func saveCurrentSession(
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String,
        dialogueEntries: [RuntimeDialogueEntryState]
    ) {
        persistSessionSnapshot(
            shutdownState: .clean,
            recoveryRequired: false,
            recoveredAt: nil,
            lastUserInput: lastUserInput,
            lastResidentOutput: lastResidentOutput,
            lastActivity: lastActivity,
            dialogueEntries: dialogueEntries
        )
    }

    func markSessionUnclean(
        lastUserInput: String = "",
        lastResidentOutput: String = "",
        lastActivity: String = "",
        dialogueEntries: [RuntimeDialogueEntryState] = []
    ) {
        persistSessionSnapshot(
            shutdownState: .unclean,
            recoveryRequired: false,
            recoveredAt: nil,
            lastUserInput: lastUserInput,
            lastResidentOutput: lastResidentOutput,
            lastActivity: lastActivity,
            dialogueEntries: dialogueEntries
        )
    }

    private func persistSessionSnapshot(
        shutdownState: SessionShutdownState,
        recoveryRequired: Bool,
        recoveredAt: Date?,
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String,
        dialogueEntries: [RuntimeDialogueEntryState]
    ) {
        guard let context = sessionContext else { return }
        let now = Date()
        let record = SessionStoreRecord(
            residentID: context.residentID,
            sessionID: context.sessionID.rawValue,
            createdAt: now,
            updatedAt: now,
            lastUserInput: lastUserInput,
            lastResidentOutput: lastResidentOutput,
            lastActivity: lastActivity,
            shutdownState: shutdownState,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt
        )
        try? sessionStore.save(record: record)
        try? sessionStore.saveDisplayCache(SessionDisplayCache(
            residentID: context.residentID,
            sessionID: context.sessionID.rawValue,
            lastUserInput: lastUserInput,
            lastResidentOutput: lastResidentOutput,
            lastActivity: lastActivity,
            shutdownState: shutdownState,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt,
            updatedAt: now
        ))
        let entries = dialogueEntries.map {
            SessionDialogueEntry(role: $0.role, text: $0.text, timestamp: $0.timestamp)
        }
        try? sessionStore.saveDialogueEntries(entries, for: context.sessionID.rawValue)
    }

    public func step(inputText: String) -> RuntimeStepResponse {
        let residentID = sessionContext?.residentID ?? ""
        let request = RuntimeStepRequest(residentID: residentID, inputText: inputText)
        return step(request: request)
    }

    public func step(request: RuntimeStepRequest) -> RuntimeStepResponse {
        let pendingCancellation = cancellationState
        cancellationState = .none
        let response = executionEngine.step(request: request, cancellationState: pendingCancellation)
        sessionContext = RuntimeSessionContext(residentID: request.residentID, sessionID: sessionContext?.sessionID ?? .make())
        markSessionUnclean(
            lastUserInput: request.inputText,
            lastResidentOutput: response.outputText,
            lastActivity: response.residentState.lastActivitySummary,
            dialogueEntries: [
                RuntimeDialogueEntryState(role: "user", text: request.inputText, timestamp: response.residentState.lastUpdatedAt),
                RuntimeDialogueEntryState(role: "resident", text: response.outputText, timestamp: response.residentState.lastUpdatedAt)
            ]
        )
        return response
    }

    private func persistSessionIfPossible(inputText: String, response: RuntimeStepResponse) {
        guard let context = sessionContext else { return }
        let record = SessionStoreRecord(
            residentID: context.residentID,
            sessionID: context.sessionID.rawValue,
            createdAt: response.residentState.lastUpdatedAt,
            updatedAt: response.residentState.lastUpdatedAt,
            lastUserInput: inputText,
            lastResidentOutput: response.outputText,
            lastActivity: response.residentState.lastActivitySummary
        )
        try? sessionStore.save(record: record)

        var dialogueEntries = (try? sessionStore.loadMostRecentDialogueEntries()) ?? []
        dialogueEntries.append(SessionDialogueEntry(role: "user", text: inputText, timestamp: response.residentState.lastUpdatedAt))
        dialogueEntries.append(SessionDialogueEntry(role: "resident", text: response.outputText, timestamp: response.residentState.lastUpdatedAt))
        if dialogueEntries.count > 20 {
            dialogueEntries = Array(dialogueEntries.suffix(20))
        }
        try? sessionStore.saveDialogueEntries(dialogueEntries, for: context.sessionID.rawValue)
    }

    public func readMemoryValue(for key: String, residentID: String) -> String? {
        memoryController.loadValue(for: key, residentID: residentID)
    }

    public func saveMemoryValue(_ value: String, for key: String, residentID: String) {
        memoryController.saveValue(value, for: key, residentID: residentID)
    }

    public func cancelCurrentStep() {
        cancellationState = RuntimeCancellationState(isCancelled: true, reason: .cancelled)
    }

    public func interrupt(request: RuntimeCancellationRequest) {
        cancellationState = RuntimeCancellationState(isCancelled: true, reason: request.reason)
    }

    public func runtimeTick(request: RuntimeTickRequest = RuntimeTickRequest()) -> RuntimeTickResponse {
        clockState = RuntimeClockState(tickCount: clockState.tickCount + 1, lastTickAt: Date())
        let traceEvent = TraceEvent(type: .runtimeStep, message: "system.tick no-op")
        let diagnostics = RuntimeDiagnostics(cancellationState: "none")
        return RuntimeTickResponse(clockState: clockState, traceEvent: traceEvent, diagnostics: diagnostics)
    }

    public func currentRuntimeConfig() -> RuntimeConfig {
        hostEnv.runtimeConfig.currentRuntimeConfig()
    }

}
