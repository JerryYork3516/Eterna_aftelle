import Foundation

public struct RuntimeConfig: Equatable {
    public var runtimeMode: String
    public var providerProfileID: String?
    public var secretRef: String?
    public var diagnosticsLevel: String
    public var featureFlags: [String: Bool]

    public init(
        runtimeMode: String = "mock",
        providerProfileID: String? = nil,
        secretRef: String? = nil,
        diagnosticsLevel: String = "basic",
        featureFlags: [String: Bool] = [:]
    ) {
        self.runtimeMode = runtimeMode
        self.providerProfileID = providerProfileID
        self.secretRef = secretRef
        self.diagnosticsLevel = diagnosticsLevel
        self.featureFlags = featureFlags
    }

    public static let safeDefault = RuntimeConfig()
}

public protocol RuntimeConfigProviding {
    func currentRuntimeConfig() -> RuntimeConfig
}

public struct NoopRuntimeConfigProvider: RuntimeConfigProviding {
    public init() {}

    public func currentRuntimeConfig() -> RuntimeConfig {
        .safeDefault
    }
}
