import Foundation

public struct LoadedDR {
    public let schemaVersion: String
    public let revision: String
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
            let revision = object["revision"] as? String,
            object["not_executable"] as? Bool == true,
            let manifest = object["manifest"] as? [String: Any],
            let payload = object["payload"] as? [String: Any],
            let identity = payload["resident_identity"] as? [String: Any],
            let manifestResidentID = manifest["resident_id"] as? String,
            let identityResidentID = identity["resident_id"] as? String,
            manifestResidentID == identityResidentID,
            let displayName = identity["name"] as? String,
            identity["primary_language"] as? String != nil,
            object["lattice_config"] as? [String: Any] != nil,
            object["runtime_requirements"] as? [String: Any] != nil,
            let safetyPolicy = object["safety_policy"] as? [String: Any],
            safetyPolicy["no_secret_in_dr"] as? Bool == true,
            safetyPolicy["no_direct_provider_binding"] as? Bool == true,
            safetyPolicy["user_data_not_embedded"] as? Bool == true,
            safetyPolicy["not_executable"] as? Bool == true
        else {
            throw DRLoaderError.invalidFixture
        }

        return LoadedDR(
            schemaVersion: schemaVersion,
            revision: revision,
            residentID: manifestResidentID,
            displayName: displayName
        )
    }
}
