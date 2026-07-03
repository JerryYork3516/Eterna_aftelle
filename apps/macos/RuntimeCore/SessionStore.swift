import Foundation

public struct SessionStoreRecord: Codable, Equatable {
    public var schemaVersion: String
    public var residentID: String
    public var sessionID: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUserInput: String
    public var lastResidentOutput: String
    public var lastActivity: String

    public init(
        schemaVersion: String = SessionStore.schemaVersion,
        residentID: String,
        sessionID: String,
        createdAt: Date,
        updatedAt: Date,
        lastUserInput: String,
        lastResidentOutput: String,
        lastActivity: String
    ) {
        self.schemaVersion = schemaVersion
        self.residentID = residentID
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUserInput = lastUserInput
        self.lastResidentOutput = lastResidentOutput
        self.lastActivity = lastActivity
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

    public func load(sessionID: String) throws -> SessionStoreRecord? {
        let url = fileURL(for: sessionID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(SessionStoreRecord.self, from: data)
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for sessionID: String) -> URL {
        baseURL.appendingPathComponent("\(sessionID).json", isDirectory: false)
    }
}
