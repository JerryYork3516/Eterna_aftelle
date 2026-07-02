import Foundation

public final class DRLoader {
    public init() {}

    public func load(drData: Data) throws -> LoadedDR {
        LoadedDR(rawData: drData)
    }
}

public struct LoadedDR {
    public var rawData: Data

    public init(rawData: Data) {
        self.rawData = rawData
    }
}
