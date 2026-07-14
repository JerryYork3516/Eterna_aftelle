import Foundation

public final class TraceRecorder {
    private static let capacity = 200
    public private(set) var recordedEvents: [TraceEvent] = []

    public init() {}

    public func record(_ event: TraceEvent) {
        recordedEvents.append(event)
        if recordedEvents.count > Self.capacity {
            recordedEvents.removeFirst(recordedEvents.count - Self.capacity)
        }
    }
}
