import Foundation
import SwiftUI

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var apiKey: String
    @Published var selectedMonth: Date
    @Published var entries: [WorksheetEntry]
    @Published var statusMessage: String = "Ready"
    @Published var isSyncing = false
    @Published var lastDailySync: String = "Unknown"
    @Published var lastHistorySyncError: String?

    private let apiClient = DailyAPIClient()
    private let store = WorksheetStore()
    private let calendar = Calendar(identifier: .gregorian)
    private var syncTimer: Timer?

    private init() {
        self.apiKey = KeychainStore.shared.loadAPIKey()
        self.selectedMonth = Calendar(identifier: .gregorian).monthInterval(containing: Date()).start
        self.entries = store.loadEntries()
    }

    var monthTitle: String {
        Formatters.monthTitle.string(from: selectedMonth)
    }

    var monthEntries: [WorksheetEntry] {
        let interval = calendar.monthInterval(containing: selectedMonth)
        return entries
            .filter { interval.contains($0.date) }
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                if $0.project != $1.project { return $0.project < $1.project }
                return $0.activity < $1.activity
            }
    }

    var totals: WorksheetTotals {
        let creative = monthEntries.filter { $0.category == .creative }.map(\.seconds).reduce(0, +)
        let admin = monthEntries.filter { $0.category == .admin }.map(\.seconds).reduce(0, +)
        return WorksheetTotals(creativeSeconds: creative, adminSeconds: admin)
    }

    var projectTotals: [ProjectTotal] {
        let grouped = Dictionary(grouping: monthEntries, by: \.project)
        return grouped.map { project, entries in
            ProjectTotal(
                project: project,
                creativeSeconds: entries.filter { $0.category == .creative }.map(\.seconds).reduce(0, +),
                adminSeconds: entries.filter { $0.category == .admin }.map(\.seconds).reduce(0, +)
            )
        }
        .sorted { $0.project < $1.project }
    }

    func saveAPIKey() {
        KeychainStore.shared.saveAPIKey(apiKey)
        statusMessage = "API key saved"
    }

    func startBackgroundSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.syncSelectedMonth()
        }
    }

    func previousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }

    func nextMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }

    func addAdminEntry() {
        let entry = WorksheetEntry(
            date: selectedMonth,
            project: "Admin",
            activity: "Admin time",
            seconds: 3600,
            category: .admin,
            source: .manualAdmin,
            externalKey: nil
        )
        entries.append(entry)
        persist()
    }

    func binding(for id: UUID) -> Binding<WorksheetEntry>? {
        guard entries.firstIndex(where: { $0.id == id }) != nil else {
            return nil
        }
        return Binding<WorksheetEntry>(
            get: {
                self.entries.first(where: { $0.id == id })!
            },
            set: { newValue in
                guard let index = self.entries.firstIndex(where: { $0.id == id }) else { return }
                self.entries[index] = newValue
                self.persist()
            }
        )
    }

    func delete(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        persist()
    }

    func syncSelectedMonth() {
        guard isSyncing == false else { return }
        isSyncing = true
        statusMessage = "Checking Daily sync status..."
        lastHistorySyncError = nil

        let key = apiKey
        apiClient.fetchUser(apiKey: key) { [weak self] userResult in
            guard let self = self else { return }
            switch userResult {
            case .success(let user):
                self.lastDailySync = user.lastSynced ?? "Never"
                self.fetchMonth(containing: self.selectedMonth, apiKey: key) { result in
                    self.isSyncing = false
                    switch result {
                    case .success:
                        self.statusMessage = "Synced \(self.monthTitle)"
                    case .failure(let error):
                        self.statusMessage = "Could not sync \(self.monthTitle): \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                self.isSyncing = false
                self.statusMessage = error.localizedDescription
            }
        }
    }

    func syncAvailableHistory() {
        guard isSyncing == false else { return }
        isSyncing = true
        statusMessage = "Checking Daily retention window..."
        lastHistorySyncError = nil

        let key = apiKey
        apiClient.fetchUser(apiKey: key) { [weak self] userResult in
            guard let self = self else { return }

            switch userResult {
            case .success(let user):
                self.lastDailySync = user.lastSynced ?? "Never"
                let months = self.availableHistoryMonths(dataRetentionDays: user.dataRetention)
                guard months.isEmpty == false else {
                    self.isSyncing = false
                    self.statusMessage = "Daily did not report any syncable history."
                    return
                }
                self.syncMonths(months, index: 0, apiKey: key, failedMonths: [])
            case .failure(let error):
                self.isSyncing = false
                self.statusMessage = "Could not check Daily retention: \(error.localizedDescription)"
            }
        }
    }

    private func fetchMonth(containing month: Date, apiKey: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let interval = calendar.monthInterval(containing: month)
        let start = interval.start
        let end = calendar.lastDayOfMonth(containing: month)
        statusMessage = "Syncing \(Formatters.monthTitle.string(from: month))..."

        apiClient.fetchTimesheet(start: start, end: end, apiKey: apiKey) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let days):
                self.mergeDailyTimesheet(days, replacing: interval)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func syncMonths(_ months: [Date], index: Int, apiKey: String, failedMonths: [String]) {
        guard index < months.count else {
            isSyncing = false
            if failedMonths.isEmpty {
                statusMessage = "Synced available Daily history: \(months.count) months"
            } else {
                let failed = failedMonths.joined(separator: ", ")
                lastHistorySyncError = "Failed months: \(failed)"
                statusMessage = "History sync finished with \(failedMonths.count) failed month(s)."
            }
            return
        }

        let month = months[index]
        let title = Formatters.monthTitle.string(from: month)
        statusMessage = "Syncing history \(index + 1)/\(months.count): \(title)"

        fetchMonth(containing: month, apiKey: apiKey) { [weak self] result in
            guard let self = self else { return }
            var failures = failedMonths
            if case .failure = result {
                failures.append(title)
            }
            self.syncMonths(months, index: index + 1, apiKey: apiKey, failedMonths: failures)
        }
    }

    private func availableHistoryMonths(dataRetentionDays: Int) -> [Date] {
        let today = Date()
        let startDate: Date

        if dataRetentionDays > 0 {
            startDate = calendar.date(byAdding: .day, value: -dataRetentionDays + 1, to: today) ?? today
        } else {
            // Daily normally reports retention in days. If it does not, keep this bounded.
            startDate = calendar.date(byAdding: .year, value: -1, to: today) ?? today
        }

        let firstMonth = calendar.monthInterval(containing: startDate).start
        let currentMonth = calendar.monthInterval(containing: today).start
        var months: [Date] = []
        var cursor = firstMonth

        while cursor <= currentMonth {
            months.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return months
    }

    private func mergeDailyTimesheet(_ days: [DailyTimesheetDay], replacing interval: DateInterval) {
        let imported = days.flatMap { day -> [WorksheetEntry] in
            guard let date = Formatters.apiDay.date(from: day.date) else {
                return []
            }

            return day.activities.map { activity in
                let project = displayProject(group: activity.group, activity: activity.activity)
                let key = externalKey(date: date, project: project, activity: activity.activity)
                return WorksheetEntry(
                    date: date,
                    project: project,
                    activity: activity.activity,
                    seconds: activity.duration,
                    originalSeconds: nil,
                    category: .creative,
                    source: .dailyAPI,
                    externalKey: key
                )
            }
        }

        let outsideSelectedMonth = entries.filter { interval.contains($0.date) == false }
        let manualAdminEntries = entries.filter { entry in
            interval.contains(entry.date) && entry.source == .manualAdmin
        }

        entries = outsideSelectedMonth + manualAdminEntries + imported
        persist()
    }

    private func displayProject(group: String?, activity: String) -> String {
        if let group = group, group.isEmpty == false {
            return group
        }
        return activity
    }

    private func externalKey(date: Date, project: String, activity: String) -> String {
        "\(Formatters.apiDay.string(from: date))|\(project)|\(activity)"
    }

    private func persist() {
        store.saveEntries(entries)
    }
}
