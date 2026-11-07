import SwiftUI

/// The app's Settings window (⌘,). Values are persisted on change, so they
/// apply to the running app immediately.
struct SettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show menu bar icon", isOn: $prefs.showMenuBarIcon)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Quickly add and complete tasks from anywhere.")
            }

            if prefs.showMenuBarIcon {
                Section {
                    LabeledSlider(title: "Width", value: $prefs.menuBarWidth, range: 320...600)
                    LabeledSlider(title: "Height", value: $prefs.menuBarHeight, range: 320...800)
                } header: {
                    Text("Popover Size")
                } footer: {
                    Text("Changes apply immediately.")
                }
            }

            Section {
                Toggle("Confirm before clearing completed tasks", isOn: $prefs.confirmBeforeDeleting)
            } header: {
                Text("Tasks")
            }

            Section {
                Toggle("Notify me about due dates", isOn: $prefs.dueDateNotifications)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Sends a notification when a task with a due date becomes due. macOS will ask for permission the first time.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 460)
        .navigationTitle("Settings")
        .onChange(of: prefs.dueDateNotifications) { _, enabled in
            if enabled { NotificationManager.shared.requestAuthorization() }
            NotificationManager.shared.sync(
                todos: TodoStore.shared.todos,
                enabled: enabled
            )
        }
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: 10)
            Text("\(Int(value))px")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
