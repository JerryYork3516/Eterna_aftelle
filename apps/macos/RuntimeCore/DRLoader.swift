import Foundation

public struct DRLoadRequest {
    public let drData: Data

    public init(drData: Data) {
        self.drData = drData
    }
}

struct FirstInteractionPolicy: Equatable {
    let enabled: Bool?
    let firstLoadEnabled: Bool?
    let repeatIntroduction: Bool?
}

struct FirstGreetingConfig: Equatable {
    let locale: String?
    let contentStatus: String?
    let variants: [String]
    let repeatOnReturn: Bool?
}

struct FirstPresenceConfig: Equatable {
    let particleState: String?
    let motion: String?
    let energy: String?
    let subtitleMode: String?
}

struct InitialRelationshipConfig: Equatable {
    let defaultMode: String?
    let intimacyLevel: String?
    let trustBuilding: String?
    let romanticAssumption: Bool?
}

private struct InvalidDRFieldError: Error {
    let path: String
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
    let firstInteractionPolicy: FirstInteractionPolicy?
    let firstGreetingConfig: FirstGreetingConfig?
    let firstPresenceConfig: FirstPresenceConfig?
    let initialRelationshipConfig: InitialRelationshipConfig?
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
    case conflictingField(String)
}

public final class DRLoader {
    public init() {}

    public func load(request: DRLoadRequest) throws -> DRLoadResult {
        do {
            let loadedDR = try loadValidatedDR(drData: request.drData)
            return DRLoadResult(isLoaded: true, loadedDR: loadedDR, diagnostics: "DR load ok")
        } catch let error as InvalidDRFieldError {
            return DRLoadResult(isLoaded: false, loadedDR: nil, diagnostics: "DR load failed: invalid \(error.path)")
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
        let payloadDisplayName = identity["name"] as? String
        let manifestDisplayName = manifest["resident_name"] as? String
        if let payloadDisplayName, let manifestDisplayName, payloadDisplayName != manifestDisplayName {
            throw DRLoaderError.conflictingField("resident_name")
        }
        guard let displayName = payloadDisplayName ?? manifestDisplayName else {
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
        let memorySupportLevels = try resolveMemorySupportLevels(
            memoryPolicy: memoryPolicy,
            extensions: memoryPolicyExtensions
        )
        let firstInteractionPolicy = try parseFirstInteractionPolicy(from: payload)
        let firstGreetingConfig = try parseFirstGreetingConfig(from: payload)
        let firstPresenceConfig = try parseFirstPresenceConfig(from: payload)
        let initialRelationshipConfig = try parseInitialRelationshipConfig(from: payload)
        let payloadModules = payload["modules"] as? [Any]
        let topLevelModules = object["modules"] as? [Any]
        if let payloadModules, let topLevelModules {
            let normalizedPayloadModules = try JSONSerialization.data(withJSONObject: payloadModules, options: [.sortedKeys])
            let normalizedTopLevelModules = try JSONSerialization.data(withJSONObject: topLevelModules, options: [.sortedKeys])
            guard normalizedPayloadModules == normalizedTopLevelModules else {
                throw DRLoaderError.conflictingField("modules")
            }
        }

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
            payloadModuleCount: payloadModules?.count ?? 0,
            topLevelModuleCount: topLevelModules?.count,
            slotCount: (object["slots"] as? [Any])?.count ?? 0,
            memoryPolicySource: memoryPolicySource,
            memoryPolicyData: memoryPolicyData,
            memorySupportLevels: memorySupportLevels,
            firstInteractionPolicy: firstInteractionPolicy,
            firstGreetingConfig: firstGreetingConfig,
            firstPresenceConfig: firstPresenceConfig,
            initialRelationshipConfig: initialRelationshipConfig
        )
    }

    private func parseFirstInteractionPolicy(from payload: [String: Any]) throws -> FirstInteractionPolicy? {
        guard let behavior = try optionalObject("behavior", in: payload, path: "payload.behavior"),
              let config = try optionalObject("first_interaction", in: behavior, path: "payload.behavior.first_interaction") else {
            return nil
        }
        let scenes = try optionalObject("scenes", in: config, path: "payload.behavior.first_interaction.scenes")
        let firstLoad = try scenes.flatMap {
            try optionalObject("first_load", in: $0, path: "payload.behavior.first_interaction.scenes.first_load")
        }
        return FirstInteractionPolicy(
            enabled: try optionalValue("enabled", in: config, as: Bool.self, path: "payload.behavior.first_interaction.enabled"),
            firstLoadEnabled: try firstLoad.flatMap {
                try optionalValue("enabled", in: $0, as: Bool.self, path: "payload.behavior.first_interaction.scenes.first_load.enabled")
            },
            repeatIntroduction: try firstLoad.flatMap {
                try optionalValue("repeat_introduction", in: $0, as: Bool.self, path: "payload.behavior.first_interaction.scenes.first_load.repeat_introduction")
            }
        )
    }

    private func parseFirstGreetingConfig(from payload: [String: Any]) throws -> FirstGreetingConfig? {
        guard let expression = try optionalObject("expression", in: payload, path: "payload.expression"),
              let config = try optionalObject("first_greeting", in: expression, path: "payload.expression.first_greeting") else {
            return nil
        }
        return FirstGreetingConfig(
            locale: try optionalValue("locale", in: config, as: String.self, path: "payload.expression.first_greeting.locale"),
            contentStatus: try optionalValue("content_status", in: config, as: String.self, path: "payload.expression.first_greeting.content_status"),
            variants: try optionalValue("variants", in: config, as: [String].self, path: "payload.expression.first_greeting.variants") ?? [],
            repeatOnReturn: try optionalValue("repeat_on_return", in: config, as: Bool.self, path: "payload.expression.first_greeting.repeat_on_return")
        )
    }

    private func parseFirstPresenceConfig(from payload: [String: Any]) throws -> FirstPresenceConfig? {
        guard let expression = try optionalObject("expression", in: payload, path: "payload.expression"),
              let config = try optionalObject("first_presence", in: expression, path: "payload.expression.first_presence") else {
            return nil
        }
        return FirstPresenceConfig(
            particleState: try optionalValue("particle_state", in: config, as: String.self, path: "payload.expression.first_presence.particle_state"),
            motion: try optionalValue("motion", in: config, as: String.self, path: "payload.expression.first_presence.motion"),
            energy: try optionalValue("energy", in: config, as: String.self, path: "payload.expression.first_presence.energy"),
            subtitleMode: try optionalValue("subtitle_mode", in: config, as: String.self, path: "payload.expression.first_presence.subtitle_mode")
        )
    }

    private func parseInitialRelationshipConfig(from payload: [String: Any]) throws -> InitialRelationshipConfig? {
        guard let relationship = try optionalObject("relationship", in: payload, path: "payload.relationship"),
              let config = try optionalObject("initial_relationship", in: relationship, path: "payload.relationship.initial_relationship") else {
            return nil
        }
        return InitialRelationshipConfig(
            defaultMode: try optionalValue("default", in: config, as: String.self, path: "payload.relationship.initial_relationship.default"),
            intimacyLevel: try optionalValue("intimacy_level", in: config, as: String.self, path: "payload.relationship.initial_relationship.intimacy_level"),
            trustBuilding: try optionalValue("trust_building", in: config, as: String.self, path: "payload.relationship.initial_relationship.trust_building"),
            romanticAssumption: try optionalValue("romantic_assumption", in: config, as: Bool.self, path: "payload.relationship.initial_relationship.romantic_assumption")
        )
    }

    private func optionalObject(
        _ key: String,
        in object: [String: Any],
        path: String
    ) throws -> [String: Any]? {
        guard let rawValue = object[key] else { return nil }
        guard let value = rawValue as? [String: Any] else {
            throw InvalidDRFieldError(path: path)
        }
        return value
    }

    private func optionalValue<Value>(
        _ key: String,
        in object: [String: Any],
        as type: Value.Type,
        path: String
    ) throws -> Value? {
        guard let rawValue = object[key] else { return nil }
        guard let value = rawValue as? Value else {
            throw InvalidDRFieldError(path: path)
        }
        return value
    }

    private func resolveMemorySupportLevels(
        memoryPolicy: [String: Any]?,
        extensions: [String: Any]?
    ) throws -> [String: String] {
        if let extensions {
            let levels = extensions["memory_support_levels"] as? [String: Any] ?? [:]
            let allowedLevelsByCapability: [String: Set<String>] = [
                "short_term_memory": ["none", "policy_only", "supported"],
                "preference_memory": ["none", "policy_only", "supported_minimal_kv"],
                "event_memory": ["none", "policy_only"],
                "relationship_memory": ["none", "policy_only"],
                "interaction_log": ["none", "policy_only", "display_cache_only"]
            ]
            var validatedLevels: [String: String] = [:]
            for (capability, allowedLevels) in allowedLevelsByCapability {
                guard let rawLevel = levels[capability] else { continue }
                guard let level = rawLevel as? String, allowedLevels.contains(level) else {
                    throw DRLoaderError.unsupportedVersion("memory policy level")
                }
                validatedLevels[capability] = level
            }
            return validatedLevels
        }

        guard let memoryPolicy else { return [:] }
        let memoryTypes = Set(memoryPolicy["memory_types"] as? [String] ?? [])
        var levels: [String: String] = [:]
        if memoryTypes.contains("short_term_memory") {
            levels["short_term_memory"] = "supported"
        }
        if memoryTypes.contains("preference_memory"),
           let preferenceMemory = memoryPolicy["preference_memory"] as? [String: Any],
           preferenceMemory["type"] as? String == "kv" {
            levels["preference_memory"] = "supported_minimal_kv"
        }
        if memoryTypes.contains("interaction_log"),
           memoryPolicy["interaction_log"] as? [String: Any] != nil {
            levels["interaction_log"] = "display_cache_only"
        }
        return levels
    }

    private func diagnostics(for error: DRLoaderError) -> String {
        switch error {
        case .invalidFixture:
            return "DR load failed"
        case .missingField(let field):
            return "DR load failed: missing \(field)"
        case .unsupportedVersion(let field):
            return "DR load failed: unsupported \(field)"
        case .conflictingField(let field):
            return "DR load failed: conflicting \(field)"
        }
    }
}
