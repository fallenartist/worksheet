import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WorksheetView()
                .tabItem {
                    Label("Worksheet", systemImage: "tablecells")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .padding()
    }
}

struct WorksheetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolbar
            summary
            projectTotals
            entryList
            statusBar
        }
    }

    private var toolbar: some View {
        HStack {
            Button(action: model.previousMonth) {
                Image(systemName: "chevron.left")
            }
            Text(model.monthTitle)
                .font(.title2)
                .frame(minWidth: 180)
            Button(action: model.nextMonth) {
                Image(systemName: "chevron.right")
            }

            Spacer()

            Button(action: model.addAdminEntry) {
                Label("Admin Entry", systemImage: "plus.circle")
            }

            Button(action: model.syncSelectedMonth) {
                Label(model.isSyncing ? "Syncing" : "Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(model.isSyncing)

            Button(action: model.syncAvailableHistory) {
                Label("Sync History", systemImage: "clock.arrow.circlepath")
            }
            .disabled(model.isSyncing)

            Button(action: exportPDF) {
                Label("PDF", systemImage: "doc.richtext")
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 18) {
            MetricView(title: "Total", value: "\(Formatters.hoursString(seconds: model.totals.totalSeconds)) h")
            MetricView(title: "Creative", value: "\(Formatters.hoursString(seconds: model.totals.creativeSeconds)) h", footnote: Formatters.percentString(model.totals.creativeRatio))
            MetricView(title: "Admin", value: "\(Formatters.hoursString(seconds: model.totals.adminSeconds)) h", footnote: Formatters.percentString(model.totals.adminRatio))
        }
    }

    private var projectTotals: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project Totals")
                .font(.headline)
            VStack(spacing: 6) {
                ProjectTotalRow(project: "Project", creative: "Creative", admin: "Admin", total: "Total", isHeader: true)
                ForEach(model.projectTotals) { total in
                    ProjectTotalRow(
                        project: total.project,
                        creative: "\(Formatters.hoursString(seconds: total.creativeSeconds)) h",
                        admin: "\(Formatters.hoursString(seconds: total.adminSeconds)) h",
                        total: "\(Formatters.hoursString(seconds: total.totalSeconds)) h"
                    )
                }
            }
        }
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Entries")
                .font(.headline)
            ScrollView {
                LazyVStack(spacing: 6) {
                    EntryHeaderRow()
                    ForEach(model.monthEntries.map(\.id), id: \.self) { id in
                        if let binding = model.binding(for: id) {
                            EntryRow(entry: binding) {
                                model.delete(entryID: id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(model.statusMessage)
            Spacer()
            if let error = model.lastHistorySyncError {
                Text(error)
            }
            Text("Daily last synced: \(model.lastDailySync)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf"]
        panel.nameFieldStringValue = "worksheet-\(Formatters.apiDay.string(from: model.selectedMonth)).pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try WorksheetPDFExporter.export(entries: model.monthEntries, projectTotals: model.projectTotals, totals: model.totals, month: model.selectedMonth, to: url)
                model.statusMessage = "PDF exported to \(url.lastPathComponent)"
            } catch {
                exportError = error.localizedDescription
                model.statusMessage = error.localizedDescription
            }
        }
    }
}

struct ProjectTotalRow: View {
    let project: String
    let creative: String
    let admin: String
    let total: String
    var isHeader = false

    var body: some View {
        HStack(spacing: 12) {
            Text(project)
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            Text(creative)
                .frame(width: 90, alignment: .trailing)
            Text(admin)
                .frame(width: 90, alignment: .trailing)
            Text(total)
                .frame(width: 90, alignment: .trailing)
        }
        .font(isHeader ? .caption : .body)
        .foregroundColor(isHeader ? .secondary : .primary)
    }
}

struct MetricView: View {
    let title: String
    let value: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.title3)
                if let footnote = footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct EntryHeaderRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("").frame(width: 24)
            Text("Date").frame(width: 90, alignment: .leading)
            Text("Project").frame(minWidth: 180, alignment: .leading)
            Text("Category").frame(width: 120, alignment: .leading)
            Text("Hours").frame(width: 110, alignment: .leading)
            Text("Activity").frame(minWidth: 160, alignment: .leading)
            Spacer()
            Text("").frame(width: 32)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
    }
}

struct EntryRow: View {
    @Binding var entry: WorksheetEntry
    let onDelete: () -> Void

    private var canEdit: Bool {
        entry.source == .manualAdmin
    }

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
                .frame(width: 24)

            if canEdit {
                editableDate
            } else {
                Text(Formatters.displayDay.string(from: entry.date))
                    .frame(width: 90, alignment: .leading)
            }

            Text(entry.project)
                .frame(minWidth: 180, alignment: .leading)

            Text(entry.category.rawValue)
                .frame(width: 120, alignment: .leading)

            if canEdit {
                editableHours
            } else {
                Text("\(Formatters.hoursString(seconds: entry.seconds)) h")
                    .frame(width: 110, alignment: .leading)
            }

            if canEdit {
                editableActivity
            } else {
                Text(entry.activity)
                    .frame(minWidth: 160, alignment: .leading)
            }

            Spacer()

            if canEdit {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .frame(width: 32)
            } else {
                Text("")
                    .frame(width: 32)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
    }

    private var editableDate: some View {
        DatePicker("", selection: Binding(get: {
            entry.date
        }, set: { value in
            entry.markUpdated()
            entry.date = value
        }), displayedComponents: .date)
        .labelsHidden()
        .frame(width: 90)
    }

    private var editableHours: some View {
        Stepper(value: Binding(get: {
            entry.hours
        }, set: { value in
            entry.setHours(value)
        }), in: 0...24, step: 0.25) {
            Text("\(Formatters.hoursString(seconds: entry.seconds)) h")
                .frame(width: 68, alignment: .trailing)
        }
        .frame(width: 110)
    }

    private var editableActivity: some View {
        TextField("Admin note", text: Binding(get: {
            entry.activity
        }, set: { value in
            entry.markUpdated()
            entry.activity = value
        }))
        .frame(minWidth: 160)
    }

    private var statusIcon: some View {
        Group {
            if entry.source == .dailyAPI {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                    .help("Synced from Daily")
            } else if entry.source == .manualAdmin {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .help("Manual admin entry, stored locally")
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily API")
                .font(.title2)
            Text("Enable the Web API in Daily, then paste the API key here. The key is stored in your macOS Keychain.")
                .foregroundColor(.secondary)

            SecureField("API Key", text: $model.apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Button("Save API Key", action: model.saveAPIKey)
                Button("Test Sync", action: model.syncSelectedMonth)
                    .disabled(model.isSyncing)
                Button("Sync History", action: model.syncAvailableHistory)
                    .disabled(model.isSyncing)
            }

            Divider()

            Text("Background Sync")
                .font(.headline)
            Text("This starter keeps syncing while the app is running. Launch-at-login packaging is the next step once the app bundle is created in Xcode.")
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}
