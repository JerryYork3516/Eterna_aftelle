import Foundation

public protocol HostEnv {
    var clock: HostClock { get }
    var fileAccess: FileAccess { get }
    var runtimeConfig: RuntimeConfigAccess { get }
    var providerProfileReference: ProviderProfileReferenceAccess { get }
    var secureSecretReference: SecureSecretReferenceAccess { get }
}

public protocol PlatformAdapter {
    var hostEnv: HostEnv { get }
}

public protocol HostClock {
    func now() -> Date
}

public struct NoopHostClock: HostClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public protocol FileAccess {
    func canReadFile(at path: String) -> Bool
}

public struct NoopFileAccess: FileAccess {
    public init() {}

    public func canReadFile(at path: String) -> Bool {
        !path.isEmpty
    }
}

public protocol RuntimeConfigAccess {
    func currentRuntimeConfig() -> [String: String]
}

public struct NoopRuntimeConfigAccess: RuntimeConfigAccess {
    public init() {}

    public func currentRuntimeConfig() -> [String: String] {
        [:]
    }
}

public protocol ProviderProfileReferenceAccess {
    func currentProviderProfileReference() -> String?
}

public struct NoopProviderProfileReferenceAccess: ProviderProfileReferenceAccess {
    public init() {}

    public func currentProviderProfileReference() -> String? {
        nil
    }
}

public protocol SecureSecretReferenceAccess {
    func currentSecureSecretReference() -> String?
}

public struct NoopSecureSecretReferenceAccess: SecureSecretReferenceAccess {
    public init() {}

    public func currentSecureSecretReference() -> String? {
        nil
    }
}

public struct DefaultHostEnv: HostEnv {
    public let clock: HostClock
    public let fileAccess: FileAccess
    public let runtimeConfig: RuntimeConfigAccess
    public let providerProfileReference: ProviderProfileReferenceAccess
    public let secureSecretReference: SecureSecretReferenceAccess

    public init(
        clock: HostClock = NoopHostClock(),
        fileAccess: FileAccess = NoopFileAccess(),
        runtimeConfig: RuntimeConfigAccess = NoopRuntimeConfigAccess(),
        providerProfileReference: ProviderProfileReferenceAccess = NoopProviderProfileReferenceAccess(),
        secureSecretReference: SecureSecretReferenceAccess = NoopSecureSecretReferenceAccess()
    ) {
        self.clock = clock
        self.fileAccess = fileAccess
        self.runtimeConfig = runtimeConfig
        self.providerProfileReference = providerProfileReference
        self.secureSecretReference = secureSecretReference
    }
}

public struct PlatformAdapterEnvironment: PlatformAdapter {
    public let hostEnv: HostEnv

    public init(hostEnv: HostEnv = DefaultHostEnv()) {
        self.hostEnv = hostEnv
    }
}
