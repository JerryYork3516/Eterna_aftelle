import Foundation

public enum SessionShutdownState: String, Codable, Equatable {
    case clean
    case unclean
}

public struct SessionStoreRecord: Codable, Equatable {
    public var schemaVersion: String
    public var residentID: String
    public var sessionID: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUserInput: String
    public var lastResidentOutput: String
    public var lastActivity: String
    public var shutdownState: SessionShutdownState
    public var recoveryRequired: Bool
    public var recoveredAt: Date?

    public init(
        schemaVersion: String = SessionStore.schemaVersion,
        residentID: String,
        sessionID: String,
        createdAt: Date,
        updatedAt: Date,
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String,
        shutdownState: SessionShutdownState = .unclean,
        recoveryRequired: Bool = false,
        recoveredAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.residentID = residentID
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUserInput = lastUserInput
        self.lastResidentOutput = lastResidentOutput
        self.lastActivity = lastActivity
        self.shutdownState = shutdownState
        self.recoveryRequired = recoveryRequired
        self.recoveredAt = recoveredAt
    }
}

public struct SessionDisplayCache: Codable, Equatable {
    public var residentID: String
    public var sessionID: String
    public var lastUserInput: String
    public var lastResidentOutput: String
    public var lastActivity: String
    public var avatarMode: String
    public var avatarPresence: String
    public var avatarMoodHint: String
    public var avatarActivityHint: String
    public var avatarParticleHint: String
    public var shutdownState: SessionShutdownState
    public var recoveryRequired: Bool
    public var recoveredAt: Date?
    public var updatedAt: Date

    public init(
        residentID: String,
        sessionID: String,
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String,
        avatarMode: String = "idle",
        avatarPresence: String = "unknown",
        avatarMoodHint: String = "",
        avatarActivityHint: String = "",
        avatarParticleHint: String = "",
        shutdownState: SessionShutdownState = .unclean,
        recoveryRequired: Bool = false,
        recoveredAt: Date? = nil,
        updatedAt: Date
    ) {
        self.residentID = residentID
        self.sessionID = sessionID
        self.lastUserInput = lastUserInput
        self.lastResidentOutput = lastResidentOutput
        self.lastActivity = lastActivity
        self.avatarMode = avatarMode
        self.avatarPresence = avatarPresence
        self.avatarMoodHint = avatarMoodHint
        self.avatarActivityHint = avatarActivityHint
        self.avatarParticleHint = avatarParticleHint
        self.shutdownState = shutdownState
        self.recoveryRequired = recoveryRequired
        self.recoveredAt = recoveredAt
        self.updatedAt = updatedAt
    }
}

public struct SessionDialogueEntry: Codable, Equatable {
    public var role: String
    public var text: String
    public var timestamp: Date

    public init(role: String, text: String, timestamp: Date) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

public final class SessionStore {
    public static let schemaVersion = "0.1.0"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let baseURL: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.baseURL = baseDirectory.appendingPathComponent("Aftelle/SessionStore", isDirectory: true)
    }

    public func save(record: SessionStoreRecord) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(record)
        try data.write(to: fileURL(for: record.sessionID), options: [.atomic])
    }

    public func saveDisplayCache(_ cache: SessionDisplayCache) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(cache)
        try data.write(to: displayCacheURL, options: Data.WritingOptions.atomic)
    }

    public func loadDisplayCache() throws -> SessionDisplayCache? {
        guard fileManager.fileExists(atPath: displayCacheURL.path) else { return nil }
        let data = try Data(contentsOf: displayCacheURL)
        return try decoder.decode(SessionDisplayCache.self, from: data)
    }

    public func load(sessionID: String) throws -> SessionStoreRecord? {
        let url = fileURL(for: sessionID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(SessionStoreRecord.self, from: data)
    }

    public func loadMostRecentRecord() throws -> SessionStoreRecord? {
        guard fileManager.fileExists(atPath: baseURL.path) else { return nil }
        let urls = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        let sortedURLs = urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
        for url in sortedURLs where url.pathExtension == "json" {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url)
            if let record = try? decoder.decode(SessionStoreRecord.self, from: data), record.schemaVersion == Self.schemaVersion {
                return record
            }
        }
        return nil
    }

    public func loadMostRecentDialogueEntries(limit: Int = 10) throws -> [SessionDialogueEntry] {
        guard let record = try loadMostRecentRecord() else { return [] }
        let historyURL = historyURL(for: record.sessionID)
        guard fileManager.fileExists(atPath: historyURL.path) else { return [] }
        let data = try Data(contentsOf: historyURL)
        guard let entries = try? decoder.decode([SessionDialogueEntry].self, from: data) else { return [] }
        return Array(entries.suffix(limit))
    }

    public func saveDialogueEntries(_ entries: [SessionDialogueEntry], for sessionID: String) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(entries)
        try data.write(to: historyURL(for: sessionID), options: [.atomic])
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }

    private var displayCacheURL: URL {
        baseURL.appendingPathComponent("display_cache.json", isDirectory: false)
    }

    private func fileURL(for sessionID: String) -> URL {
        baseURL.appendingPathComponent("\(sessionID).json", isDirectory: false)
    }

    private func historyURL(for sessionID: String) -> URL {
        baseURL.appendingPathComponent("\(sessionID).history.json", isDirectory: false)
    }
}
