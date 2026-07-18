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

struct RuntimeDialogueInstruction: Equatable {
    let instruction: String
    let sourceRuleRefs: [String]
}

struct RuntimeDialogueSourceRuleCoverage: Equatable {
    let selectedSemanticRuleCount: Int
    let translatedRuleCount: Int
    let unmappedRuleRefs: [String]
    let validationRuleCountExcluded: Int
}

struct RuntimeDialogueScenario: Equatable {
    let sceneID: String
    let intent: String
    let responseStrategy: String
    let followUpAllowed: Bool
    let adviceAllowed: Bool
    let recommendedLength: String
    let prohibitedBehaviors: [String]
    let linkedPolicyIDs: [String]
    let sourceRuleRefs: [String]
}

struct RuntimeDialogueExampleTurn: Equatable {
    let role: String
    let text: String
}

struct RuntimeDialogueFewShotExample: Equatable {
    let exampleID: String
    let label: String
    let sceneID: String
    let turns: [RuntimeDialogueExampleTurn]
    let usage: String
    let notFixedResponse: Bool
    let notKeywordMatching: Bool
}

struct RuntimeDialogueFewShotSelection: Equatable {
    let usage: String
    let notFixedResponse: Bool
    let notKeywordMatching: Bool
    let selectionMode: String
    let recommendedMaxExamplesPerRequest: Int
    let studioPerformsTokenTrimming: Bool
}

struct RuntimeDialogueProhibitedPattern: Equatable {
    let patternID: String
    let reason: String
    let examples: [String]
    let sourceRuleRefs: [String]
    let status: String
}

struct RuntimeDialogueContextSourceRule: Equatable {
    let sourceID: String
    let instruction: String
}

struct RuntimeDialogueContextUsagePolicy: Equatable {
    let allowedSources: [RuntimeDialogueContextSourceRule]
    let forbiddenSources: [RuntimeDialogueContextSourceRule]
    let studioBoundary: String
}

struct RuntimeDialogueFallbackBehavior: Equatable {
    let trigger: String
    let locale: String
    let text: String
    let constraints: [String]
}

struct RuntimeDialogueProjection: Equatable {
    let schemaVersion: String
    let projectionType: String
    let derived: Bool
    let readOnly: Bool
    let primarySourcePath: String
    let supportingSourcePaths: [String]
    let locale: String
    let usage: String
    let notFixedResponse: Bool
    let notKeywordMatching: Bool
    let systemInstruction: String
    let languagePolicy: RuntimeDialogueInstruction
    let responseStyle: RuntimeDialogueInstruction
    let responseOrder: RuntimeDialogueInstruction
    let followUpPolicy: RuntimeDialogueInstruction
    let advicePolicy: RuntimeDialogueInstruction
    let silencePolicy: RuntimeDialogueInstruction
    let relationshipPolicy: RuntimeDialogueInstruction
    let memoryUsagePolicy: RuntimeDialogueInstruction
    let selfDisclosurePolicy: RuntimeDialogueInstruction
    let endingPolicy: RuntimeDialogueInstruction
    let sourceRuleCoverage: RuntimeDialogueSourceRuleCoverage
    let scenarios: [RuntimeDialogueScenario]
    let fewShotSelection: RuntimeDialogueFewShotSelection
    let fewShotExamples: [RuntimeDialogueFewShotExample]
    let prohibitedPatterns: [RuntimeDialogueProhibitedPattern]
    let contextUsagePolicy: RuntimeDialogueContextUsagePolicy
    let fallbackBehavior: RuntimeDialogueFallbackBehavior
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
    let runtimeDialogueProjection: RuntimeDialogueProjection?
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
        let runtimeDialogueProjection = try parseRuntimeDialogueProjection(from: payload)
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
            initialRelationshipConfig: initialRelationshipConfig,
            runtimeDialogueProjection: runtimeDialogueProjection
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

    private func parseRuntimeDialogueProjection(from payload: [String: Any]) throws -> RuntimeDialogueProjection? {
        let path = "payload.runtime_dialogue_projection"
        guard let projection = try optionalObject("runtime_dialogue_projection", in: payload, path: path) else {
            return nil
        }
        _ = try requiredObject("behavior_policy", in: payload, path: "payload.behavior_policy")

        let derived = try requiredValue("derived", in: projection, as: Bool.self, path: "\(path).derived")
        let readOnly = try requiredValue("read_only", in: projection, as: Bool.self, path: "\(path).read_only")
        let primarySourcePath = try requiredValue("primary_source_path", in: projection, as: String.self, path: "\(path).primary_source_path")
        let usage = try requiredValue("usage", in: projection, as: String.self, path: "\(path).usage")
        let notFixedResponse = try requiredValue("not_fixed_response", in: projection, as: Bool.self, path: "\(path).not_fixed_response")
        let notKeywordMatching = try requiredValue("not_keyword_matching", in: projection, as: Bool.self, path: "\(path).not_keyword_matching")

        guard derived else { throw DRLoaderError.conflictingField("\(path).derived") }
        guard readOnly else { throw DRLoaderError.conflictingField("\(path).read_only") }
        guard primarySourcePath == "payload.behavior_policy" else {
            throw DRLoaderError.conflictingField("\(path).primary_source_path")
        }
        guard usage == "llm_system_context" else {
            throw DRLoaderError.conflictingField("\(path).usage")
        }
        guard notFixedResponse else { throw DRLoaderError.conflictingField("\(path).not_fixed_response") }
        guard notKeywordMatching else { throw DRLoaderError.conflictingField("\(path).not_keyword_matching") }

        let fewShotSelection = try parseFewShotSelection(from: projection, path: path)
        guard fewShotSelection.usage == "behavior_guidance_only" else {
            throw DRLoaderError.conflictingField("\(path).few_shot_selection.usage")
        }
        guard fewShotSelection.notFixedResponse else {
            throw DRLoaderError.conflictingField("\(path).few_shot_selection.not_fixed_response")
        }
        guard fewShotSelection.notKeywordMatching else {
            throw DRLoaderError.conflictingField("\(path).few_shot_selection.not_keyword_matching")
        }

        return RuntimeDialogueProjection(
            schemaVersion: try requiredValue("schema_version", in: projection, as: String.self, path: "\(path).schema_version"),
            projectionType: try requiredValue("projection_type", in: projection, as: String.self, path: "\(path).projection_type"),
            derived: derived,
            readOnly: readOnly,
            primarySourcePath: primarySourcePath,
            supportingSourcePaths: try requiredValue(
                "supporting_source_paths",
                in: projection,
                as: [String].self,
                path: "\(path).supporting_source_paths"
            ),
            locale: try requiredValue("locale", in: projection, as: String.self, path: "\(path).locale"),
            usage: usage,
            notFixedResponse: notFixedResponse,
            notKeywordMatching: notKeywordMatching,
            systemInstruction: try requiredValue("system_instruction", in: projection, as: String.self, path: "\(path).system_instruction"),
            languagePolicy: try parseDialogueInstruction("language_policy", from: projection, path: path),
            responseStyle: try parseDialogueInstruction("response_style", from: projection, path: path),
            responseOrder: try parseDialogueInstruction("response_order", from: projection, path: path),
            followUpPolicy: try parseDialogueInstruction("follow_up_policy", from: projection, path: path),
            advicePolicy: try parseDialogueInstruction("advice_policy", from: projection, path: path),
            silencePolicy: try parseDialogueInstruction("silence_policy", from: projection, path: path),
            relationshipPolicy: try parseDialogueInstruction("relationship_policy", from: projection, path: path),
            memoryUsagePolicy: try parseDialogueInstruction("memory_usage_policy", from: projection, path: path),
            selfDisclosurePolicy: try parseDialogueInstruction("self_disclosure_policy", from: projection, path: path),
            endingPolicy: try parseDialogueInstruction("ending_policy", from: projection, path: path),
            sourceRuleCoverage: try parseSourceRuleCoverage(from: projection, path: path),
            scenarios: try parseDialogueScenarios(from: projection, path: path),
            fewShotSelection: fewShotSelection,
            fewShotExamples: try parseFewShotExamples(from: projection, path: path),
            prohibitedPatterns: try parseProhibitedPatterns(from: projection, path: path),
            contextUsagePolicy: try parseContextUsagePolicy(from: projection, path: path),
            fallbackBehavior: try parseFallbackBehavior(from: projection, path: path)
        )
    }

    private func parseDialogueInstruction(
        _ key: String,
        from projection: [String: Any],
        path: String
    ) throws -> RuntimeDialogueInstruction {
        let instructionPath = "\(path).\(key)"
        let object = try requiredObject(key, in: projection, path: instructionPath)
        return RuntimeDialogueInstruction(
            instruction: try requiredValue("instruction", in: object, as: String.self, path: "\(instructionPath).instruction"),
            sourceRuleRefs: try requiredValue("source_rule_refs", in: object, as: [String].self, path: "\(instructionPath).source_rule_refs")
        )
    }

    private func parseSourceRuleCoverage(
        from projection: [String: Any],
        path: String
    ) throws -> RuntimeDialogueSourceRuleCoverage {
        let coveragePath = "\(path).source_rule_coverage"
        let object = try requiredObject("source_rule_coverage", in: projection, path: coveragePath)
        return RuntimeDialogueSourceRuleCoverage(
            selectedSemanticRuleCount: try requiredValue(
                "selected_semantic_rule_count",
                in: object,
                as: Int.self,
                path: "\(coveragePath).selected_semantic_rule_count"
            ),
            translatedRuleCount: try requiredValue("translated_rule_count", in: object, as: Int.self, path: "\(coveragePath).translated_rule_count"),
            unmappedRuleRefs: try requiredValue("unmapped_rule_refs", in: object, as: [String].self, path: "\(coveragePath).unmapped_rule_refs"),
            validationRuleCountExcluded: try requiredValue(
                "validation_rule_count_excluded",
                in: object,
                as: Int.self,
                path: "\(coveragePath).validation_rule_count_excluded"
            )
        )
    }

    private func parseDialogueScenarios(
        from projection: [String: Any],
        path: String
    ) throws -> [RuntimeDialogueScenario] {
        let scenariosPath = "\(path).scenarios"
        let objects = try requiredObjectArray("scenarios", in: projection, path: scenariosPath)
        return try objects.enumerated().map { index, object in
            let itemPath = "\(scenariosPath).\(index)"
            return RuntimeDialogueScenario(
                sceneID: try requiredValue("scene_id", in: object, as: String.self, path: "\(itemPath).scene_id"),
                intent: try requiredValue("intent", in: object, as: String.self, path: "\(itemPath).intent"),
                responseStrategy: try requiredValue("response_strategy", in: object, as: String.self, path: "\(itemPath).response_strategy"),
                followUpAllowed: try requiredValue("follow_up_allowed", in: object, as: Bool.self, path: "\(itemPath).follow_up_allowed"),
                adviceAllowed: try requiredValue("advice_allowed", in: object, as: Bool.self, path: "\(itemPath).advice_allowed"),
                recommendedLength: try requiredValue("recommended_length", in: object, as: String.self, path: "\(itemPath).recommended_length"),
                prohibitedBehaviors: try requiredValue(
                    "prohibited_behaviors",
                    in: object,
                    as: [String].self,
                    path: "\(itemPath).prohibited_behaviors"
                ),
                linkedPolicyIDs: try requiredValue("linked_policy_ids", in: object, as: [String].self, path: "\(itemPath).linked_policy_ids"),
                sourceRuleRefs: try requiredValue("source_rule_refs", in: object, as: [String].self, path: "\(itemPath).source_rule_refs")
            )
        }
    }

    private func parseFewShotSelection(
        from projection: [String: Any],
        path: String
    ) throws -> RuntimeDialogueFewShotSelection {
        let selectionPath = "\(path).few_shot_selection"
        let object = try requiredObject("few_shot_selection", in: projection, path: selectionPath)
        return RuntimeDialogueFewShotSelection(
            usage: try requiredValue("usage", in: object, as: String.self, path: "\(selectionPath).usage"),
            notFixedResponse: try requiredValue("not_fixed_response", in: object, as: Bool.self, path: "\(selectionPath).not_fixed_response"),
            notKeywordMatching: try requiredValue("not_keyword_matching", in: object, as: Bool.self, path: "\(selectionPath).not_keyword_matching"),
            selectionMode: try requiredValue("selection_mode", in: object, as: String.self, path: "\(selectionPath).selection_mode"),
            recommendedMaxExamplesPerRequest: try requiredValue(
                "recommended_max_examples_per_request",
                in: object,
                as: Int.self,
                path: "\(selectionPath).recommended_max_examples_per_request"
            ),
            studioPerformsTokenTrimming: try requiredValue(
                "studio_performs_token_trimming",
                in: object,
                as: Bool.self,
                path: "\(selectionPath).studio_performs_token_trimming"
            )
        )
    }

    private func parseFewShotExamples(
        from projection: [String: Any],
        path: String
    ) throws -> [RuntimeDialogueFewShotExample] {
        let examplesPath = "\(path).few_shot_examples"
        let objects = try requiredObjectArray("few_shot_examples", in: projection, path: examplesPath)
        return try objects.enumerated().map { index, object in
            let itemPath = "\(examplesPath).\(index)"
            let turnObjects = try requiredObjectArray("turns", in: object, path: "\(itemPath).turns")
            let turns = try turnObjects.enumerated().map { turnIndex, turn in
                let turnPath = "\(itemPath).turns.\(turnIndex)"
                return RuntimeDialogueExampleTurn(
                    role: try requiredValue("role", in: turn, as: String.self, path: "\(turnPath).role"),
                    text: try requiredValue("text", in: turn, as: String.self, path: "\(turnPath).text")
                )
            }
            return RuntimeDialogueFewShotExample(
                exampleID: try requiredValue("example_id", in: object, as: String.self, path: "\(itemPath).example_id"),
                label: try requiredValue("label", in: object, as: String.self, path: "\(itemPath).label"),
                sceneID: try requiredValue("scene_id", in: object, as: String.self, path: "\(itemPath).scene_id"),
                turns: turns,
                usage: try requiredValue("usage", in: object, as: String.self, path: "\(itemPath).usage"),
                notFixedResponse: try requiredValue("not_fixed_response", in: object, as: Bool.self, path: "\(itemPath).not_fixed_response"),
                notKeywordMatching: try requiredValue("not_keyword_matching", in: object, as: Bool.self, path: "\(itemPath).not_keyword_matching")
            )
        }
    }

    private func parseProhibitedPatterns(
        from projection: [String: Any],
        path: String
    ) throws -> [RuntimeDialogueProhibitedPattern] {
        let patternsPath = "\(path).prohibited_patterns"
        let objects = try requiredObjectArray("prohibited_patterns", in: projection, path: patternsPath)
        return try objects.enumerated().map { index, object in
            let itemPath = "\(patternsPath).\(index)"
            return RuntimeDialogueProhibitedPattern(
                patternID: try requiredValue("pattern_id", in: object, as: String.self, path: "\(itemPath).pattern_id"),
                reason: try requiredValue("reason", in: object, as: String.self, path: "\(itemPath).reason"),
                examples: try requiredValue("examples", in: object, as: [String].self, path: "\(itemPath).examples"),
                sourceRuleRefs: try requiredValue("source_rule_refs", in: object, as: [String].self, path: "\(itemPath).source_rule_refs"),
                status: try requiredValue("status", in: object, as: String.self, path: "\(itemPath).status")
            )
        }
    }

    private func parseContextUsagePolicy(
        from projection: [String: Any],
        path: String
    ) throws -> RuntimeDialogueContextUsagePolicy {
        let policyPath = "\(path).context_usage_policy"
        let object = try requiredObject("context_usage_policy", in: projection, path: policyPath)
        return RuntimeDialogueContextUsagePolicy(
            allowedSources: try parseContextSourceRules("allowed_sources", from: object, path: policyPath),
            forbiddenSources: try parseContextSourceRules("forbidden_sources", from: object, path: policyPath),
            studioBoundary: try requiredValue("studio_boundary", in: object, as: String.self, path: "\(policyPath).studio_boundary")
        )
    }

    private func parseContextSourceRules(
        _ key: String,
        from policy: [String: Any],
        path: String
    ) throws -> [RuntimeDialogueContextSourceRule] {
        let rulesPath = "\(path).\(key)"
        let objects = try requiredObjectArray(key, in: policy, path: rulesPath)
        return try objects.enumerated().map { index, object in
            let itemPath = "\(rulesPath).\(index)"
            return RuntimeDialogueContextSourceRule(
                sourceID: try requiredValue("source_id", in: object, as: String.self, path: "\(itemPath).source_id"),
                instruction: try requiredValue("instruction", in: object, as: String.self, path: "\(itemPath).instruction")
            )
        }
    }

    private func parseFallbackBehavior(
        from projection: [String: Any],
        path: String
    ) throws -> RuntimeDialogueFallbackBehavior {
        let fallbackPath = "\(path).fallback_behavior"
        let object = try requiredObject("fallback_behavior", in: projection, path: fallbackPath)
        return RuntimeDialogueFallbackBehavior(
            trigger: try requiredValue("trigger", in: object, as: String.self, path: "\(fallbackPath).trigger"),
            locale: try requiredValue("locale", in: object, as: String.self, path: "\(fallbackPath).locale"),
            text: try requiredValue("text", in: object, as: String.self, path: "\(fallbackPath).text"),
            constraints: try requiredValue("constraints", in: object, as: [String].self, path: "\(fallbackPath).constraints")
        )
    }

    private func requiredObject(
        _ key: String,
        in object: [String: Any],
        path: String
    ) throws -> [String: Any] {
        guard let value = try optionalObject(key, in: object, path: path) else {
            throw DRLoaderError.missingField(path)
        }
        return value
    }

    private func requiredObjectArray(
        _ key: String,
        in object: [String: Any],
        path: String
    ) throws -> [[String: Any]] {
        let values = try requiredValue(key, in: object, as: [Any].self, path: path)
        return try values.enumerated().map { index, value in
            guard let object = value as? [String: Any] else {
                throw InvalidDRFieldError(path: "\(path).\(index)")
            }
            return object
        }
    }

    private func requiredValue<Value>(
        _ key: String,
        in object: [String: Any],
        as type: Value.Type,
        path: String
    ) throws -> Value {
        guard let value = try optionalValue(key, in: object, as: type, path: path) else {
            throw DRLoaderError.missingField(path)
        }
        return value
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
