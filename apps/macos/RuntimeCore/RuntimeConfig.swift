import Foundation

public struct ProviderRuntimeConfig: Equatable {
    public var providerProfileID: String?
    public var secretRef: String?
    public var isEnabled: Bool

    public init(
        providerProfileID: String? = nil,
        secretRef: String? = nil,
        isEnabled: Bool = false
    ) {
        self.providerProfileID = providerProfileID
        self.secretRef = secretRef
        self.isEnabled = isEnabled
    }

    public static let disabled = ProviderRuntimeConfig()
}

public enum SecretResolutionStatus: Equatable {
    case notConfigured
    case unavailable
    case referenced
}

public struct SecretReferenceState: Equatable {
    public var keyRefPresent: Bool
    public var secretRefPresent: Bool
    public var resolutionStatus: SecretResolutionStatus

    public init(
        keyRefPresent: Bool = false,
        secretRefPresent: Bool = false,
        resolutionStatus: SecretResolutionStatus = .notConfigured
    ) {
        self.keyRefPresent = keyRefPresent
        self.secretRefPresent = secretRefPresent
        self.resolutionStatus = resolutionStatus
    }

    public static let notConfigured = SecretReferenceState()
}

public struct NoopSecretReferenceResolver {
    public init() {}

    public func resolve(keyRef: String?, secretRef: String?) -> SecretReferenceState {
        let hasKeyRef = !(keyRef?.isEmpty ?? true)
        let hasSecretRef = !(secretRef?.isEmpty ?? true)

        guard hasKeyRef || hasSecretRef else {
            return .notConfigured
        }

        return SecretReferenceState(
            keyRefPresent: hasKeyRef,
            secretRefPresent: hasSecretRef,
            resolutionStatus: .unavailable
        )
    }
}

public struct RuntimeConfig: Equatable {
    public var runtimeMode: String
    public var provider: ProviderRuntimeConfig
    public var diagnosticsLevel: String
    public var featureFlags: [String: Bool]

    public init(
        runtimeMode: String = "mock",
        provider: ProviderRuntimeConfig = .disabled,
        diagnosticsLevel: String = "basic",
        featureFlags: [String: Bool] = [:]
    ) {
        self.runtimeMode = runtimeMode
        self.provider = provider
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
