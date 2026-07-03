import Foundation

public final class VisualStateMapper {
    public init() {}

    public func map(mode: VisualStateMode) -> VisualState {
        VisualState(mode: mode)
    }

    public func mapAvatarState(visualState: VisualState, residentID: String, displayName: String) -> AvatarState {
        switch visualState.mode {
        case .idle:
            return AvatarState(
                residentID: residentID,
                displayName: displayName,
                mode: "idle",
                presence: "present",
                moodHint: "calm",
                activityHint: "resting",
                particleHint: "calibration_idle"
            )
        case .thinking:
            return AvatarState(
                residentID: residentID,
                displayName: displayName,
                mode: "thinking",
                presence: "present",
                moodHint: "focused",
                activityHint: "processing",
                particleHint: "calibration_thinking"
            )
        case .speaking:
            return AvatarState(
                residentID: residentID,
                displayName: displayName,
                mode: "speaking",
                presence: "active",
                moodHint: "expressive",
                activityHint: "speaking",
                particleHint: "calibration_speaking"
            )
        }
    }
}
