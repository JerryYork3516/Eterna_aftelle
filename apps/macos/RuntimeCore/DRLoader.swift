import Foundation

public struct LoadedDR {
    public let schemaVersion: String
    public let residentID: String
    public let displayName: String
}

public enum DRLoaderError: Error {
    case invalidFixture
}

public final class DRLoader {
    public init() {}

    public func load(drData: Data) throws -> LoadedDR {
        guard let object = try JSONSerialization.jsonObject(with: drData) as? [String: Any] else {
            throw DRLoaderError.invalidFixture
        }

        guard
            let schemaVersion = object["schema_version"] as? String,
            let residentID = object["resident_id"] as? String,
            let displayName = object["display_name"] as? String
        else {
            throw DRLoaderError.invalidFixture
        }

        return LoadedDR(schemaVersion: schemaVersion, residentID: residentID, displayName: displayName)
    }
}
