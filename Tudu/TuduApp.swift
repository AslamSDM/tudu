import SwiftUI

/// Stable identifier for the app's primary window so it can be reopened after
/// it has been closed while the app keeps running in the menu bar.
enum MainWindow {
    static let id = "main"
}

@main
struct TuduApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup(id: MainWindow.id) {
            ContentView()
                .frame(
                    minWidth: 640, idealWidth: 900,
                    minHeight: 460, idealHeight: 640
                )
        }
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    appState.requestNewTask()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Task with Details…") {
                    appState.requestDetailedNewTask()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Import Tasks…") {
                    appState.requestImport()
                }

                Button("Export Tasks…") {
                    appState.requestExport()
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
