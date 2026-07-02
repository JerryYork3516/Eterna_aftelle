//
//  Eterna_aftelleTests.swift
//  Eterna_aftelleTests
//
//  Created by Jerry York on 2026/7/1.
//

import Foundation
import Testing

@testable import Eterna_aftelle

struct Eterna_aftelleTests {

    @Test func stage7CalibrationResidentFixtureMatchesContract() throws {
        let fixture = try loadCalibrationFixture()

        #expect(fixture["file_type"] as? String == "digital_resident")
        #expect(fixture["dr_version"] as? String == "0.3")
        #expect(fixture["dr_schema_version"] as? String == "0.3.0")
        #expect(fixture["schema_version"] as? String == "0.4.0")
        #expect(fixture["revision"] as? String == "1")
        #expect(fixture["not_executable"] as? Bool == true)

        let manifest = try #require(fixture["manifest"] as? [String: Any])
        let payload = try #require(fixture["payload"] as? [String: Any])
        let identity = try #require(payload["resident_identity"] as? [String: Any])

        let manifestResidentID = try #require(manifest["resident_id"] as? String)
        let identityResidentID = try #require(identity["resident_id"] as? String)

        #expect(manifestResidentID == identityResidentID)
        #expect(identity["name"] as? String != nil)
        #expect(identity["primary_language"] as? String == "zh")

        let lattice = try #require(fixture["lattice_config"] as? [String: Any])
        #expect(lattice["emotion"] as? String == "neutral")
        #expect(number(in: lattice, key: "energy") == 0.5)
        #expect(lattice["attention"] != nil)
        #expect(lattice["motion"] as? String == "idle_breathing")
        #expect(lattice["voice_state"] as? String == "idle")
        #expect(number(in: lattice, key: "particle_density") == 0.5)
        #expect(lattice["focus_target"] as? String == "none")
        let colorPalette = try #require(lattice["color_palette"] as? [String])
        #expect(colorPalette == ["#7aa2f7", "#5dd39e", "#f2a65a"])

        let requirements = try #require(fixture["runtime_requirements"] as? [String: Any])
        #expect(requirements["runtime_api_version"] as? String == "0.4.0")
        #expect(requirements["execution_mode"] as? String == "mock")
        #expect(requirements["fallback_mode"] as? String == "mock_fallback")

        let safety = try #require(fixture["safety_policy"] as? [String: Any])
        #expect(safety["no_secret_in_dr"] as? Bool == true)
        #expect(safety["no_direct_provider_binding"] as? Bool == true)
        #expect(safety["mock_screen_only"] as? Bool == true)
        #expect(safety["user_data_not_embedded"] as? Bool == true)
        #expect(safety["not_executable"] as? Bool == true)
        #expect(containsForbiddenProviderConfig(fixture) == false)
    }

    private func loadCalibrationFixture() throws -> [String: Any] {
        let testFile = URL(fileURLWithPath: #filePath)
        let testDirectory = testFile.deletingLastPathComponent()
        let repositoryRoot = testDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot.appendingPathComponent("docs/Freezev03.digital_resident")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: sourceURL.path])
        }

        print("stage7_calibration_fixture=\(sourceURL.path)")

        let data = try Data(contentsOf: sourceURL)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func containsForbiddenProviderConfig(_ value: Any) -> Bool {
        let forbiddenKeys = [
            ["api", "key"].joined(separator: "_"),
            ["api", "Key"].joined(),
            "base_url",
            "baseURL",
            ["key", "ref"].joined(separator: "_"),
            "keyRef",
            "model",
            "provider_key"
        ]

        if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                if forbiddenKeys.contains(key) || containsForbiddenProviderConfig(nestedValue) {
                    return true
                }
            }
            return false
        }

        if let array = value as? [Any] {
            return array.contains { containsForbiddenProviderConfig($0) }
        }

        return false
    }

    private func number(in dictionary: [String: Any], key: String) -> Double? {
        if let value = dictionary[key] as? Double {
            return value
        }

        if let value = dictionary[key] as? Int {
            return Double(value)
        }

        return nil
    }
}
