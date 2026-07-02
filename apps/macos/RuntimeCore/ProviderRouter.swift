import Foundation

public struct ProviderRoutingDiagnostics: Equatable {
    public let providerProfileID: String?
    public let secretRefPresent: Bool
    public let keyRefPresent: Bool
    public let mode: String

    public init(providerProfileID: String?, secretRefPresent: Bool, keyRefPresent: Bool, mode: String) {
        self.providerProfileID = providerProfileID
        self.secretRefPresent = secretRefPresent
        self.keyRefPresent = keyRefPresent
        self.mode = mode
    }
}

public final class ProviderRouter {
    public init() {}

    public func routeMockProvider() -> String {
        "Mock response received."
    }

    public func diagnostics(for config: ProviderRuntimeConfig, secretState: SecretReferenceState) -> ProviderRoutingDiagnostics {
        ProviderRoutingDiagnostics(
            providerProfileID: config.providerProfileID,
            secretRefPresent: secretState.secretRefPresent,
            keyRefPresent: secretState.keyRefPresent,
            mode: config.isEnabled ? "mock-enabled" : "disabled"
        )
    }
}
