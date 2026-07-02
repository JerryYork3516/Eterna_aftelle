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
