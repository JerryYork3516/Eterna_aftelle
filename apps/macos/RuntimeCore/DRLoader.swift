import Foundation

public struct DRLoadRequest {
    public let drData: Data

    public init(drData: Data) {
        self.drData = drData
    }
}

public struct LoadedDR {
    public let schemaVersion: String
    public let revision: String
    public let residentID: String
    public let displayName: String
}

public struct DRLoadResult {
    public let isLoaded: Bool
    public let loadedDR: LoadedDR?
    public let diagnostics: String
}

public enum DRLoaderError: Error {
    case invalidFixture
    case missingField(String)
}

public final class DRLoader {
    public init() {}

    public func load(request: DRLoadRequest) throws -> DRLoadResult {
        do {
            let loadedDR = try loadValidatedDR(drData: request.drData)
            return DRLoadResult(isLoaded: true, loadedDR: loadedDR, diagnostics: "DR load ok")
        } catch let error as DRLoaderError {
            return DRLoadResult(isLoaded: false, loadedDR: nil, diagnostics: diagnostics(for: error))
        } catch {
            return DRLoadResult(isLoaded: false, loadedDR: nil, diagnostics: "DR load failed")
        }
    }

    private func loadValidatedDR(drData: Data) throws -> LoadedDR {
        guard let object = try JSONSerialization.jsonObject(with: drData) as? [String: Any] else {
            throw DRLoaderError.invalidFixture
        }

        guard let schemaVersion = object["schema_version"] as? String else {
            throw DRLoaderError.missingField("schema_version")
        }
        guard let revision = object["revision"] as? String else {
            throw DRLoaderError.missingField("revision")
        }
        guard object["not_executable"] as? Bool == true else {
            throw DRLoaderError.missingField("not_executable")
        }
        guard let manifest = object["manifest"] as? [String: Any] else {
            throw DRLoaderError.missingField("manifest")
        }
        guard let payload = object["payload"] as? [String: Any] else {
            throw DRLoaderError.missingField("payload")
        }
        guard let identity = payload["resident_identity"] as? [String: Any] else {
            throw DRLoaderError.missingField("payload.resident_identity")
        }
        guard let manifestResidentID = manifest["resident_id"] as? String else {
            throw DRLoaderError.missingField("manifest.resident_id")
        }
        guard let identityResidentID = identity["resident_id"] as? String else {
            throw DRLoaderError.missingField("payload.resident_identity.resident_id")
        }
        guard manifestResidentID == identityResidentID else {
            throw DRLoaderError.invalidFixture
        }
        guard let displayName = identity["name"] as? String else {
            throw DRLoaderError.missingField("payload.resident_identity.name")
        }
        guard identity["primary_language"] as? String != nil else {
            throw DRLoaderError.missingField("payload.resident_identity.primary_language")
        }
        guard object["lattice_config"] as? [String: Any] != nil else {
            throw DRLoaderError.missingField("lattice_config")
        }
        guard object["runtime_requirements"] as? [String: Any] != nil else {
            throw DRLoaderError.missingField("runtime_requirements")
        }
        guard let safetyPolicy = object["safety_policy"] as? [String: Any] else {
            throw DRLoaderError.missingField("safety_policy")
        }
        guard safetyPolicy["no_secret_in_dr"] as? Bool == true else {
            throw DRLoaderError.missingField("safety_policy.no_secret_in_dr")
        }
        guard safetyPolicy["no_direct_provider_binding"] as? Bool == true else {
            throw DRLoaderError.missingField("safety_policy.no_direct_provider_binding")
        }
        guard safetyPolicy["user_data_not_embedded"] as? Bool == true else {
            throw DRLoaderError.missingField("safety_policy.user_data_not_embedded")
        }
        guard safetyPolicy["not_executable"] as? Bool == true else {
            throw DRLoaderError.missingField("safety_policy.not_executable")
        }

        return LoadedDR(
            schemaVersion: schemaVersion,
            revision: revision,
            residentID: manifestResidentID,
            displayName: displayName
        )
    }

    private func diagnostics(for error: DRLoaderError) -> String {
        switch error {
        case .invalidFixture:
            return "DR load failed"
        case .missingField(let field):
            return "DR load failed: missing \(field)"
        }
    }
}
