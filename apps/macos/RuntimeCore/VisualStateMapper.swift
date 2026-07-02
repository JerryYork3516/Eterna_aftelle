import Foundation

public final class VisualStateMapper {
    public init() {}

    public func map(mode: VisualStateMode) -> VisualState {
        VisualState(mode: mode)
    }
}
