import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var startupState: AppStartupState = .idle
    @Published private(set) var runtimeStatus = "Runtime status: not loaded"
    @Published private(set) var fixtureStatus = "DR fixture: not loaded"
    @Published private(set) var residentID = "resident_id: -"
    @Published private(set) var displayName = "display_name: -"
    @Published private(set) var diagnostics = ""
    @Published private(set) var sessionState = AppSessionState()
    @Published private(set) var avatarState = AppAvatarState()
    @Published private(set) var residentState = AppResidentState()
    @Published private(set) var traceState = RuntimeTraceViewState()
    @Published private(set) var clockState = RuntimeClockViewState()
    @Published private(set) var debugPanelState = DebugPanelViewState()
    @Published private(set) var runtimeState: AppRuntimeState = .idle
    @Published private(set) var particleVisualState: ParticleCoreVisualState = .idle
    @Published private(set) var particleAvatarMode: ParticleAvatarMode = .particleCore
    @Published private(set) var particleRenderKind: ParticleRenderKind = .particleCore
    @Published private(set) var particleColorProfile = ParticleCoreColorProfile.systemDefault
    @Published private(set) var particleSubtitleState = ParticleSubtitleState.hidden
    @Published private(set) var particleDebugSnapshot = ParticleDebugSnapshot.empty

    private let orchestrationKernel: OrchestrationKernel
    private var loadedResidentID = ""
    private var loadedSessionID = ""
    private var dialogueEntries: [AppDialogueEntryState] = []
    private var latestParticleRenderMetrics = ParticleRenderMetrics.empty
    private var effectiveParticleColorProfile = ParticleCoreColorProfile.systemDefault
    private var effectiveColorProfileSource = "systemDefault"
    private var effectiveColorProfileFallbackUsed = true
    #if DEBUG
    private let debugSubtitleKeys = [
        "particleSubtitle.test.0",
        "particleSubtitle.test.1",
        "particleSubtitle.test.2"
    ]
    private var debugSubtitleIndex = 0
    #endif

    init() {
        self.orchestrationKernel = OrchestrationKernel()
    }

    init(orchestrationKernel: OrchestrationKernel) {
        self.orchestrationKernel = orchestrationKernel
    }

    func start() {
        startupState = .loading
        refreshParticleVisualState()
        refreshParticleDebugSnapshot()

        let restoreResult = orchestrationKernel.restoreMostRecentSession()
        if restoreResult.didRestore {
            loadedResidentID = restoreResult.residentID
            loadedSessionID = restoreResult.sessionID
            dialogueEntries = restoreResult.dialogueEntries.map {
                AppDialogueEntryState(
                    id: "\($0.role)-\(Int($0.timestamp.timeIntervalSince1970))",
                    role: $0.role,
                    text: $0.text,
                    timestamp: ISO8601DateFormatter().string(from: $0.timestamp)
                )
            }
            runtimeStatus = "Runtime status: session restored"
            fixtureStatus = "DR fixture: loaded"
            residentID = "resident_id: \(restoreResult.residentID.isEmpty ? "-" : restoreResult.residentID)"
            displayName = "display_name: restored session"
            sessionState = AppSessionState(
                residentID: restoreResult.residentID,
                sessionID: restoreResult.sessionID,
                lastUserInput: restoreResult.lastUserInput,
                lastResidentOutput: restoreResult.lastResidentOutput,
                lastActivity: restoreResult.lastActivity,
                shutdownState: restoreResult.shutdownState.rawValue,
                recoveryRequired: restoreResult.recoveryRequired,
                recoveredAt: restoreResult.recoveredAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                dialogueEntries: dialogueEntries
            )
            residentState = AppResidentState(
                residentID: restoreResult.residentID,
                sessionID: restoreResult.sessionID,
                lifecycleStatus: restoreResult.recoveryRequired ? "recovered" : "restored",
                presence: "available",
                lastActivitySummary: restoreResult.lastActivity,
                lastUpdatedAt: ISO8601DateFormatter().string(from: Date()),
                avatarMode: restoreResult.avatarMode
            )
            avatarState = AppAvatarState(
                residentID: restoreResult.residentID,
                displayName: "restored session",
                mode: restoreResult.avatarMode,
                presence: restoreResult.avatarPresence,
                moodHint: restoreResult.avatarMoodHint,
                activityHint: restoreResult.avatarActivityHint,
                particleHint: restoreResult.avatarParticleHint
            )
            diagnostics = restoreResult.recoveryRequired ? "Session restored after unclean shutdown" : "Session restored"
            traceState = RuntimeTraceViewState(summary: diagnostics, entries: [])
            refreshDebugPanelState(shutdownState: restoreResult.shutdownState.rawValue, recoveryRequired: restoreResult.recoveryRequired, recoveredAt: restoreResult.recoveredAt.map { ISO8601DateFormatter().string(from: $0) } ?? "")
            startupState = .loaded
            refreshParticleVisualState()
            refreshParticleDebugSnapshot()
            return
        }

        guard let fixtureURL = Bundle.main.url(forResource: "Freezev03.calibration_fixture", withExtension: "json") else {
            applyFailure(runtimeMessage: "Runtime status: DR load failed", diagnosticsMessage: "Fixture not found")
            return
        }

        guard let fixtureData = try? Data(contentsOf: fixtureURL) else {
            applyFailure(runtimeMessage: "Runtime status: DR load failed", diagnosticsMessage: "Fixture unreadable")
            return
        }

        let result = orchestrationKernel.loadResident(fixtureData: fixtureData)
        applyLoadResult(result, drData: fixtureData, sourceLabel: "DR fixture")
    }

    func updateParticleRenderMetrics(_ metrics: ParticleRenderMetrics) {
        latestParticleRenderMetrics = metrics
        refreshParticleDebugSnapshot()
    }

    func updateEffectiveParticleColorProfile(_ profile: ParticleCoreColorProfile, savedOverride: Bool) {
        effectiveParticleColorProfile = profile
        if savedOverride {
            effectiveColorProfileSource = "debugSavedOverride"
            effectiveColorProfileFallbackUsed = false
        } else if profile != particleColorProfile {
            effectiveColorProfileSource = "debugUnsavedOverride"
            effectiveColorProfileFallbackUsed = false
        }
        refreshParticleDebugSnapshot()
    }

    #if DEBUG
    func setParticleAvatarMode(_ mode: ParticleAvatarMode) {
        particleAvatarMode = mode
        particleRenderKind = mode == .abstractBustReserved ? .abstractBustReserved : .particleCore
        refreshParticleDebugSnapshot()
    }

    func setParticleRenderKind(_ kind: ParticleRenderKind) {
        particleRenderKind = kind
        particleAvatarMode = kind.avatarMode
        refreshParticleDebugSnapshot()
    }

    func showDebugSubtitle() {
        showDebugSubtitle(at: debugSubtitleIndex)
    }

    func showNextDebugSubtitle() {
        debugSubtitleIndex = (debugSubtitleIndex + 1) % debugSubtitleKeys.count
        showDebugSubtitle(at: debugSubtitleIndex)
    }

    func hideDebugSubtitle() {
        guard !particleSubtitleState.text.isEmpty else {
            particleSubtitleState = .hidden
            return
        }
        let fadingText = particleSubtitleState.text
        particleSubtitleState = ParticleSubtitleState(text: fadingText, phase: .fading)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            if particleSubtitleState.phase == .fading, particleSubtitleState.text == fadingText {
                particleSubtitleState = .hidden
                refreshParticleDebugSnapshot()
            }
        }
        refreshParticleDebugSnapshot()
    }

    func debugImportResident(from url: URL) {
        startupState = .loading
        refreshParticleVisualState()
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let drData = try? Data(contentsOf: url) else {
            applyFailure(runtimeMessage: "Runtime status: DR load failed", diagnosticsMessage: "Debug DR unreadable")
            return
        }

        let result = orchestrationKernel.loadResident(fixtureData: drData)
        applyLoadResult(result, drData: drData, sourceLabel: "Debug DR")
    }

    private func showDebugSubtitle(at index: Int) {
        let key = debugSubtitleKeys[index]
        particleSubtitleState = ParticleSubtitleState(
            text: String(localized: String.LocalizationValue(key)),
            phase: .showing
        )
        refreshParticleDebugSnapshot()
    }
    #endif

    private func applyLoadResult(_ result: RuntimeLoadResult, drData: Data, sourceLabel: String) {
        loadedResidentID = result.isLoaded ? result.residentID : ""
        loadedSessionID = result.sessionID?.rawValue ?? ""
        particleColorProfile = result.isLoaded ? ParticleCoreColorProfile.make(fromDRData: drData) : .systemDefault
        effectiveParticleColorProfile = particleColorProfile
        effectiveColorProfileFallbackUsed = !result.isLoaded || particleColorProfile == .systemDefault
        effectiveColorProfileSource = effectiveColorProfileFallbackUsed ? "systemDefault" : "\(sourceLabel) lattice_config.color_palette"
        runtimeStatus = "Runtime status: \(result.statusMessage)"
        fixtureStatus = result.isLoaded ? "\(sourceLabel): loaded" : "\(sourceLabel): not loaded"
        residentID = "resident_id: \(result.residentID.isEmpty ? "-" : result.residentID)"
        displayName = "display_name: \(result.displayName.isEmpty ? "-" : result.displayName)"
        sessionState = AppSessionState(
            residentID: result.residentID,
            sessionID: loadedSessionID,
            lastActivity: result.residentState?.lastActivitySummary ?? ""
        )
        dialogueEntries = []
        avatarState = result.avatarState.map {
            AppAvatarState(
                residentID: $0.residentID,
                displayName: $0.displayName,
                mode: $0.mode,
                presence: $0.presence,
                moodHint: $0.moodHint,
                activityHint: $0.activityHint,
                particleHint: $0.particleHint
            )
        } ?? AppAvatarState(residentID: result.residentID, displayName: result.displayName)
        residentState = result.residentState.map {
            AppResidentState(
                residentID: $0.residentID,
                sessionID: $0.sessionID,
                lifecycleStatus: $0.lifecycleStatus,
                presence: $0.presence,
                lastActivitySummary: $0.lastActivitySummary,
                lastUpdatedAt: ISO8601DateFormatter().string(from: $0.lastUpdatedAt),
                avatarMode: $0.avatarMode ?? ""
            )
        } ?? AppResidentState(residentID: result.residentID, sessionID: result.sessionID?.rawValue ?? "")
        diagnostics = result.diagnostics
        traceState = RuntimeTraceViewState(summary: result.diagnostics, entries: [])
        refreshDebugPanelState()
        startupState = result.isLoaded ? .loaded : .failed
        refreshParticleVisualState()
        refreshParticleDebugSnapshot()
    }

    func step(inputText: String) -> RuntimeStepResponse {
        let response = orchestrationKernel.step(residentID: loadedResidentID, inputText: inputText)
        runtimeState = response.cancellationState.isCancelled ? (response.cancellationState.reason == .interrupted ? .interrupted : .cancelled) : .running
        dialogueEntries.append(
            AppDialogueEntryState(
                id: "user-\(dialogueEntries.count)",
                role: "user",
                text: inputText,
                timestamp: ISO8601DateFormatter().string(from: response.residentState.lastUpdatedAt)
            )
        )
        dialogueEntries.append(
            AppDialogueEntryState(
                id: "resident-\(dialogueEntries.count)",
                role: "resident",
                text: response.outputText,
                timestamp: ISO8601DateFormatter().string(from: response.residentState.lastUpdatedAt)
            )
        )
        if dialogueEntries.count > 20 {
            dialogueEntries = Array(dialogueEntries.suffix(20))
        }
        residentState = AppResidentState(
            residentID: response.residentState.residentID,
            sessionID: response.residentState.sessionID,
            lifecycleStatus: response.residentState.lifecycleStatus,
            presence: response.residentState.presence,
            lastActivitySummary: response.residentState.lastActivitySummary,
            lastUpdatedAt: ISO8601DateFormatter().string(from: response.residentState.lastUpdatedAt),
            avatarMode: response.residentState.avatarMode ?? ""
        )
        avatarState = AppAvatarState(
            residentID: response.avatarState.residentID,
            displayName: response.avatarState.displayName,
            mode: response.avatarState.mode,
            presence: response.avatarState.presence,
            moodHint: response.avatarState.moodHint,
            activityHint: response.avatarState.activityHint,
            particleHint: response.avatarState.particleHint
        )
        sessionState = AppSessionState(
            residentID: response.residentState.residentID,
            sessionID: response.residentState.sessionID,
            lastUserInput: inputText,
            lastResidentOutput: response.outputText,
            lastActivity: response.residentState.lastActivitySummary,
            dialogueEntries: dialogueEntries
        )
        loadedSessionID = response.residentState.sessionID
        traceState = RuntimeTraceViewState(
            summary: response.diagnostics.cancellationState,
            entries: response.traceEvents.enumerated().map {
                RuntimeTraceEntryViewState(id: "\($0.offset)", type: $0.element.type.rawValue, message: $0.element.message)
            }
        )
        refreshDebugPanelState()
        refreshParticleVisualState(visualStateMode: response.visualState.mode.rawValue)
        refreshParticleDebugSnapshot()
        return response
    }

    func cancelCurrentStep() {
        orchestrationKernel.cancelCurrentStep()
        runtimeState = .cancelled
        refreshParticleVisualState()
        refreshParticleDebugSnapshot()
    }

    func interrupt() {
        orchestrationKernel.interrupt()
        runtimeState = .interrupted
        refreshParticleVisualState()
        refreshParticleDebugSnapshot()
    }

    func runtimeTick() {
        let response = orchestrationKernel.runtimeTick()
        clockState = RuntimeClockViewState(
            tickCount: response.clockState.tickCount,
            lastTickSummary: response.traceEvent.message
        )
        traceState = RuntimeTraceViewState(
            summary: response.diagnostics.cancellationState,
            entries: [
                RuntimeTraceEntryViewState(id: "tick-\(response.clockState.tickCount)", type: response.traceEvent.type.rawValue, message: response.traceEvent.message)
            ]
        )
        refreshDebugPanelState()
        refreshParticleVisualState()
        refreshParticleDebugSnapshot()
    }

    func persistForNormalTerminationIfPossible() {
        guard !loadedResidentID.isEmpty, !loadedSessionID.isEmpty else { return }
        orchestrationKernel.saveCurrentSession(
            lastUserInput: sessionState.lastUserInput,
            lastResidentOutput: sessionState.lastResidentOutput,
            lastActivity: sessionState.lastActivity,
            avatarState: currentAvatarSnapshot(),
            dialogueEntries: dialogueEntries.compactMap {
                guard let timestamp = ISO8601DateFormatter().date(from: $0.timestamp) else { return nil }
                return RuntimeDialogueEntryState(role: $0.role, text: $0.text, timestamp: timestamp)
            }
        )
    }

    func markSessionUncleanIfPossible() {
        guard !loadedResidentID.isEmpty, !loadedSessionID.isEmpty else { return }
        orchestrationKernel.markSessionUnclean(
            lastUserInput: sessionState.lastUserInput,
            lastResidentOutput: sessionState.lastResidentOutput,
            lastActivity: sessionState.lastActivity,
            avatarState: currentAvatarSnapshot(),
            dialogueEntries: dialogueEntries.map {
                RuntimeDialogueEntryState(
                    role: $0.role,
                    text: $0.text,
                    timestamp: ISO8601DateFormatter().date(from: $0.timestamp) ?? Date()
                )
            }
        )
    }

    private func currentAvatarSnapshot() -> AvatarState {
        AvatarState(
            residentID: avatarState.residentID.isEmpty ? loadedResidentID : avatarState.residentID,
            displayName: avatarState.displayName,
            mode: avatarState.mode,
            presence: avatarState.presence,
            moodHint: avatarState.moodHint,
            activityHint: avatarState.activityHint,
            particleHint: avatarState.particleHint
        )
    }

    private func refreshDebugPanelState(shutdownState: String = "unknown", recoveryRequired: Bool = false, recoveredAt: String = "") {
        debugPanelState = DebugPanelViewState(
            residentID: residentState.residentID,
            sessionID: sessionState.sessionID.isEmpty ? loadedSessionID : sessionState.sessionID,
            lifecycleStatus: residentState.lifecycleStatus,
            presence: residentState.presence,
            avatarMode: avatarState.mode,
            lastActivitySummary: residentState.lastActivitySummary,
            traceSummary: traceState.summary,
            tickCount: clockState.tickCount,
            clockStatus: clockState.lastTickSummary.isEmpty ? "noop" : clockState.lastTickSummary,
            cancellationStatus: runtimeState == .idle ? "none" : String(describing: runtimeState),
            shutdownState: shutdownState,
            recoveryRequired: recoveryRequired,
            recoveredAt: recoveredAt
        )
    }

    private func refreshParticleVisualState(visualStateMode: String? = nil) {
        particleVisualState = AppParticleVisualStateMapper.map(
            visualStateMode: visualStateMode,
            avatarState: avatarState,
            residentState: residentState,
            startupState: startupState,
            runtimeState: runtimeState
        )
    }

    private func refreshParticleDebugSnapshot() {
        let renderState = latestParticleRenderMetrics.currentVisualState
        let mappedState = String(describing: particleVisualState)
        let renderResolution = ParticleRenderResolution.resolve(requested: particleRenderKind)
        particleDebugSnapshot = ParticleDebugSnapshot(
            fps: latestParticleRenderMetrics.fps,
            particleCount: latestParticleRenderMetrics.particleCount,
            drawableSize: latestParticleRenderMetrics.drawableSize,
            preferredFramesPerSecond: latestParticleRenderMetrics.preferredFramesPerSecond,
            currentVisualState: renderState,
            previousVisualState: latestParticleRenderMetrics.previousVisualState,
            stateElapsedTime: latestParticleRenderMetrics.stateElapsedTime,
            lastTransitionReason: latestParticleRenderMetrics.lastTransitionReason,
            sourceAvatarState: avatarStateSummary(),
            mappedParticleState: mappedState,
            isDebugOverrideActive: renderState != mappedState || latestParticleRenderMetrics.lastTransitionReason.hasPrefix("debugKey"),
            avatarMode: particleAvatarMode.rawValue,
            particleCoreModeStatus: particleAvatarMode.particleCoreStatus,
            abstractBustModeStatus: particleAvatarMode.abstractBustStatus,
            renderFallback: renderResolution.fallbackRenderer,
            renderFallbackReason: renderResolution.reason,
            requestedRenderKind: renderResolution.requestedMode,
            activeRenderer: renderResolution.activeRenderer,
            fallbackRenderer: renderResolution.fallbackRenderer,
            fallbackReason: renderResolution.reason,
            supportedRenderers: renderResolution.supportedRenderers,
            reservedRenderers: renderResolution.reservedRenderers,
            colorProfileSource: effectiveColorProfileSource,
            baseColor: colorString(
                red: effectiveParticleColorProfile.baseRed,
                green: effectiveParticleColorProfile.baseGreen,
                blue: effectiveParticleColorProfile.baseBlue
            ),
            ridgeColor: colorString(
                red: effectiveParticleColorProfile.ridgeRed,
                green: effectiveParticleColorProfile.ridgeGreen,
                blue: effectiveParticleColorProfile.ridgeBlue
            ),
            highlightColor: colorString(
                red: effectiveParticleColorProfile.highlightRed,
                green: effectiveParticleColorProfile.highlightGreen,
                blue: effectiveParticleColorProfile.highlightBlue
            ),
            fallbackUsed: effectiveColorProfileFallbackUsed,
            subtitlePhase: String(describing: particleSubtitleState.phase),
            hasSubtitleText: !particleSubtitleState.text.isEmpty,
            mouseInfluenceEnabled: latestParticleRenderMetrics.mouseInfluenceEnabled,
            mouseInsideParticleArea: latestParticleRenderMetrics.mouseInsideParticleArea,
            interactionStrength: latestParticleRenderMetrics.interactionStrength,
            runtimeCoreModified: false,
            runtimeAPIModified: false,
            drSchemaModified: false,
            providerTTSConnected: false
        )
    }

    private func avatarStateSummary() -> String {
        "mode=\(avatarState.mode) presence=\(avatarState.presence) mood=\(avatarState.moodHint) activity=\(avatarState.activityHint) particle=\(avatarState.particleHint)"
    }

    private func colorString(red: Double, green: Double, blue: Double) -> String {
        String(format: "%.2f, %.2f, %.2f", red, green, blue)
    }

    private func applyFailure(runtimeMessage: String, diagnosticsMessage: String) {
        runtimeStatus = runtimeMessage
        fixtureStatus = "DR fixture: not loaded"
        loadedResidentID = ""
        loadedSessionID = ""
        residentID = "resident_id: -"
        displayName = "display_name: -"
        sessionState = AppSessionState()
        dialogueEntries = []
        avatarState = AppAvatarState()
        particleColorProfile = .systemDefault
        effectiveParticleColorProfile = .systemDefault
        effectiveColorProfileSource = "systemDefault"
        effectiveColorProfileFallbackUsed = true
        traceState = RuntimeTraceViewState(summary: diagnosticsMessage, entries: [])
        runtimeState = .idle
        diagnostics = diagnosticsMessage
        refreshDebugPanelState()
        startupState = .failed
        refreshParticleVisualState()
        refreshParticleDebugSnapshot()
    }
}
