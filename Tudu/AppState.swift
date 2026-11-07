import Foundation
import SwiftUI
import Combine
import AppKit

/// Handles `tudu://` deep links coming from the widgets (for example the "+"
/// button) and holds the small pieces of cross-view app state.
struct PendingPairing: Identifiable {
    let id = UUID()
    let key: String
    let server: URL
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// Incremented whenever the app should focus the "add task" field.
    @Published var newTaskRequest = 0

    /// Incremented whenever the app should open the full "new task" editor.
    @Published var detailedNewTaskRequest = 0

    /// Incremented when the user asks to export / import the task list.
    @Published var exportRequest = 0
    @Published var importRequest = 0

    /// Set when a `tudu://sync?...` link arrives; the main window asks the
    /// user to confirm before joining the sync space.
    @Published var pendingPairing: PendingPairing?

    /// Installed by the main window so AppKit code (the menu bar item, the Dock
    /// icon) can reopen the window after the user closed it.
    var openMainWindow: (() -> Void)?

    private init() {}

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "tudu" else { return }

        switch url.host?.lowercased() {
        case "sync":
            if let pairing = SyncConfig.parsePairingURL(url) {
                pendingPairing = PendingPairing(key: pairing.key, server: pairing.server)
                showMainWindow()
            }
        case "add":
            requestNewTask()
        case "open", .none:
            showMainWindow()
        default:
            break
        }
    }

    /// Focuses the app and asks the main window to focus its "add task" field.
    func requestNewTask() {
        showMainWindow()
        newTaskRequest += 1
    }

    /// Focuses the app and opens the full editor for a brand-new task.
    func requestDetailedNewTask() {
        showMainWindow()
        detailedNewTaskRequest += 1
    }

    /// Asks the main window to present the export / import panels.
    func requestExport() { exportRequest += 1 }
    func requestImport() { importRequest += 1 }

    /// Brings the app to the front, reopening the main window when it was
    /// closed. Safe to call when a window is already visible.
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }
}
