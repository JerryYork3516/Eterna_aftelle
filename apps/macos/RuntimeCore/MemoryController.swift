import Foundation

public struct MemoryEntryRecord: Codable, Equatable {
    public var key: String
    public var value: String
    public var updatedAt: Date

    public init(key: String, value: String, updatedAt: Date) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

public struct MemoryStoreRecord: Codable, Equatable {
    public var schemaVersion: String
    public var residentID: String
    public var entries: [MemoryEntryRecord]

    public init(
        schemaVersion: String = MemoryController.schemaVersion,
        residentID: String,
        entries: [MemoryEntryRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.residentID = residentID
        self.entries = entries
    }
}

public final class MemoryStore {
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
        self.baseURL = baseDirectory.appendingPathComponent("Aftelle/MemoryStore", isDirectory: true)
    }

    public func load(residentID: String) throws -> MemoryStoreRecord? {
        let url = fileURL(for: residentID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(MemoryStoreRecord.self, from: data)
    }

    public func save(record: MemoryStoreRecord) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(record)
        try data.write(to: fileURL(for: record.residentID), options: [.atomic])
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for residentID: String) -> URL {
        baseURL.appendingPathComponent("\(residentID).json", isDirectory: false)
    }
}

public final class MemoryController {
    public static let schemaVersion = "0.1.0"
    private let store: MemoryStore
    private var activeResidentID: String?

    public init(store: MemoryStore = MemoryStore()) {
        self.store = store
    }

    public func setActiveResidentID(_ residentID: String?) {
        activeResidentID = residentID?.isEmpty == true ? nil : residentID
    }

    public func loadValue(for key: String, residentID: String) -> String? {
        guard matchesActiveResident(residentID), let record = try? store.load(residentID: residentID), record.schemaVersion == Self.schemaVersion else { return nil }
        return record.entries.last(where: { $0.key == key })?.value
    }

    public func saveValue(_ value: String, for key: String, residentID: String) {
        guard matchesActiveResident(residentID) else { return }
        let existing = (try? store.load(residentID: residentID))
        let entries = (existing?.entries ?? []).filter { $0.key != key } + [MemoryEntryRecord(key: key, value: value, updatedAt: Date())]
        let record = MemoryStoreRecord(residentID: residentID, entries: entries)
        try? store.save(record: record)
    }

    private func matchesActiveResident(_ residentID: String) -> Bool {
        guard let activeResidentID else { return false }
        return !residentID.isEmpty && residentID == activeResidentID
    }
}
