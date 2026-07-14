import Foundation

public struct DRLoadRequest {
    public let drData: Data

    public init(drData: Data) {
        self.drData = drData
    }
}

public struct LoadedDR {
    public let drVersion: String
    public let drSchemaVersion: String
    public let protocolVersion: String?
    public let schemaVersion: String
    public let revision: String
    public let residentID: String
    public let displayName: String
    public let primaryLanguage: String
    public let citySymbol: String?
    public let personalitySummary: String?
    public let domainFocus: [String]
    public let residentDescription: String?
    public let residentDisclosure: String?
    public let sourceData: Data
    public let layerCount: Int
    public let payloadModuleCount: Int
    public let topLevelModuleCount: Int?
    public let slotCount: Int
    public let memoryPolicySource: String
    public let memoryPolicyData: Data?
    public let memorySupportLevels: [String: String]
}

public struct DRLoadResult {
    public let isLoaded: Bool
    public let loadedDR: LoadedDR?
    public let diagnostics: String
}

public enum DRLoaderError: Error {
    case invalidFixture
    case missingField(String)
    case unsupportedVersion(String)
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

        guard let drVersion = object["dr_version"] as? String else {
            throw DRLoaderError.missingField("dr_version")
        }
        guard drVersion == "0.3" else {
            throw DRLoaderError.unsupportedVersion("dr_version")
        }
        guard let drSchemaVersion = object["dr_schema_version"] as? String else {
            throw DRLoaderError.missingField("dr_schema_version")
        }
        guard drSchemaVersion == "0.3.0" else {
            throw DRLoaderError.unsupportedVersion("dr_schema_version")
        }
        let protocolVersion = object["protocol_version"] as? String
        if let protocolVersion, protocolVersion != "0.4.0" {
            throw DRLoaderError.unsupportedVersion("protocol_version")
        }
        guard let schemaVersion = object["schema_version"] as? String else {
            throw DRLoaderError.missingField("schema_version")
        }
        guard schemaVersion == "0.4.0" else {
            throw DRLoaderError.unsupportedVersion("schema_version")
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
        guard let primaryLanguage = identity["primary_language"] as? String else {
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

        let resident = object["resident"] as? [String: Any]
        let memoryPolicy = object["memory_policy"] as? [String: Any]
        let memoryPolicyExtensions = memoryPolicy?["memory_policy_extensions"] as? [String: Any]
        let effectiveMemoryPolicy = memoryPolicyExtensions ?? memoryPolicy
        let memoryPolicyData = try effectiveMemoryPolicy.map {
            try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])
        }
        let memoryPolicySource = memoryPolicyExtensions != nil
            ? "memory_policy_extensions"
            : (memoryPolicy != nil ? "memory_policy" : "none")

        return LoadedDR(
            drVersion: drVersion,
            drSchemaVersion: drSchemaVersion,
            protocolVersion: protocolVersion,
            schemaVersion: schemaVersion,
            revision: revision,
            residentID: manifestResidentID,
            displayName: displayName,
            primaryLanguage: primaryLanguage,
            citySymbol: identity["city_symbol"] as? String,
            personalitySummary: identity["personality_summary"] as? String,
            domainFocus: identity["domain_focus"] as? [String] ?? [],
            residentDescription: resident?["description"] as? String,
            residentDisclosure: resident?["disclosure"] as? String,
            sourceData: drData,
            layerCount: (object["layers"] as? [Any])?.count ?? 0,
            payloadModuleCount: (payload["modules"] as? [Any])?.count ?? 0,
            topLevelModuleCount: (object["modules"] as? [Any])?.count,
            slotCount: (object["slots"] as? [Any])?.count ?? 0,
            memoryPolicySource: memoryPolicySource,
            memoryPolicyData: memoryPolicyData,
            memorySupportLevels: memoryPolicyExtensions?["memory_support_levels"] as? [String: String] ?? [:]
        )
    }

    private func diagnostics(for error: DRLoaderError) -> String {
        switch error {
        case .invalidFixture:
            return "DR load failed"
        case .missingField(let field):
            return "DR load failed: missing \(field)"
        case .unsupportedVersion(let field):
            return "DR load failed: unsupported \(field)"
        }
    }
}
