import Foundation

final class WorksheetStore {
    private let fileManager = FileManager.default

    private var storageURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("DailyWorksheet", isDirectory: true)
    }

    private var entriesURL: URL {
        storageURL.appendingPathComponent("entries.json")
    }

    func loadEntries() -> [WorksheetEntry] {
        guard let data = try? Data(contentsOf: entriesURL) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WorksheetEntry].self, from: data)) ?? []
    }

    func saveEntries(_ entries: [WorksheetEntry]) {
        do {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: entriesURL, options: .atomic)
        } catch {
            NSLog("Failed to save worksheet entries: \(error.localizedDescription)")
        }
    }
}
