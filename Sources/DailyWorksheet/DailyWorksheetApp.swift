import AppKit
import SwiftUI

@main
struct DailyWorksheetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Daily Worksheet") {
            ContentView()
                .environmentObject(AppModel.shared)
                .frame(minWidth: 920, minHeight: 640)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        AppModel.shared.startBackgroundSync()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Daily Worksheet")
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Worksheet", action: #selector(openWorksheet), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Sync Current Month", action: #selector(syncCurrentMonth), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    @objc private func openWorksheet() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func syncCurrentMonth() {
        AppModel.shared.syncSelectedMonth()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
