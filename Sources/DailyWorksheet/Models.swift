import Foundation

enum WorkCategory: String, Codable, CaseIterable, Identifiable {
    case creative = "Creative"
    case admin = "Admin"

    var id: String { rawValue }
}

enum EntrySource: String, Codable {
    case dailyAPI
    case manualAdmin
}

struct WorksheetEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var project: String
    var activity: String
    var seconds: Int
    var originalSeconds: Int?
    var category: WorkCategory
    var source: EntrySource
    var externalKey: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        project: String,
        activity: String,
        seconds: Int,
        originalSeconds: Int? = nil,
        category: WorkCategory,
        source: EntrySource,
        externalKey: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.project = project
        self.activity = activity
        self.seconds = seconds
        self.originalSeconds = originalSeconds
        self.category = category
        self.source = source
        self.externalKey = externalKey
        self.updatedAt = updatedAt
    }

    var hours: Double {
        Double(seconds) / 3600
    }

    var originalHours: Double? {
        originalSeconds.map { Double($0) / 3600 }
    }

    var isLocallyChanged: Bool {
        source == .manualAdmin
    }

    var statusLabel: String {
        switch source {
        case .dailyAPI:
            return "Synced"
        case .manualAdmin:
            return "Manual admin"
        }
    }

    mutating func markUpdated() {
        updatedAt = Date()
    }

    mutating func setHours(_ value: Double) {
        markUpdated()
        seconds = max(0, Int((value * 3600).rounded()))
    }
}

struct ProjectTotal: Identifiable {
    var id: String { project }
    let project: String
    let creativeSeconds: Int
    let adminSeconds: Int

    var totalSeconds: Int {
        creativeSeconds + adminSeconds
    }
}

struct WorksheetTotals {
    let creativeSeconds: Int
    let adminSeconds: Int

    var totalSeconds: Int {
        creativeSeconds + adminSeconds
    }

    var creativeRatio: Double {
        totalSeconds == 0 ? 0 : Double(creativeSeconds) / Double(totalSeconds)
    }

    var adminRatio: Double {
        totalSeconds == 0 ? 0 : Double(adminSeconds) / Double(totalSeconds)
    }
}

struct DailyUserResponse: Decodable {
    let dataRetention: Int
    let lastSynced: String?
}

struct DailyTimesheetDay: Decodable {
    let date: String
    let activities: [DailyTimesheetActivity]
}

struct DailyTimesheetActivity: Decodable {
    let activity: String
    let group: String?
    let duration: Int
}
