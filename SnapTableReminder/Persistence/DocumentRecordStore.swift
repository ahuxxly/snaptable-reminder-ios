import Combine
import Foundation

final class DocumentRecordStore: ObservableObject {
    @Published private(set) var records: [DocumentRecord] = []

    private let fileManager: FileManager
    private let storeURL: URL

    init(
        fileManager: FileManager = .default,
        storeURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.storeURL = storeURL ?? Self.defaultStoreURL(fileManager: fileManager)
        load()
    }

    func add(_ record: DocumentRecord) {
        records.append(record)
        save()
    }

    func update(_ record: DocumentRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        var updated = record
        updated.updatedAt = Date()
        records[index] = updated
        save()
    }

    func delete(_ record: DocumentRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            records.remove(at: index)
        }
        save()
    }

    func deleteAll() {
        records.removeAll()
        save()
    }

    func replaceAll(_ newRecords: [DocumentRecord]) {
        records = newRecords
        save()
    }

    func load() {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            records = []
            return
        }

        do {
            let data = try Data(contentsOf: storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([DocumentRecord].self, from: data)
        } catch {
            backUpCorruptStore()
            records = []
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save records: \(error)")
        }
    }

    private func backUpCorruptStore() {
        let backupURL = storeURL.deletingPathExtension().appendingPathExtension("bak.json")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.moveItem(at: storeURL, to: backupURL)
    }

    private static func defaultStoreURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("SnapTableReminder", isDirectory: true)
            .appendingPathComponent("records.json")
    }
}
