import Foundation

public final class TraceRecorder {
    public private(set) var recordedEvents: [TraceEvent] = []

    public init() {}

    public func record(_ event: TraceEvent) {
        recordedEvents.append(event)
    }
}
