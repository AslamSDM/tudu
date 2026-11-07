import SwiftUI
import AppKit

/// Compact task list shown in the menu bar popover.
struct MenuBarView: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var onOpenApp: () -> Void = {}

    @State private var newTitle = ""
    @FocusState private var addFocused: Bool

    private var trimmedNewTitle: String {
        newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var menuItems: [Todo] {
        let pending = store.todos.filter { !$0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
        let completed = store.todos.filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
        return Array((pending + completed).prefix(12))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            addBar
            Divider()
            footer
        }
        .frame(width: prefs.menuBarWidth, height: prefs.menuBarHeight)
        .onAppear { store.reload() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .foregroundStyle(.tint)
            Text("Tudu")
                .font(.headline)
            Spacer()
            Text("\(store.stats.pending) left")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        if menuItems.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.title)
                    .foregroundStyle(.green)
                Text("All caught up!")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(menuItems) { todo in
                        taskRow(todo)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func taskRow(_ todo: Todo) -> some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(todo.isCompleted ? .green : (todo.isOverdue ? .orange : .accentColor))
            }
            .buttonStyle(.plain)

            Text(todo.displayTitle)
                .font(.callout)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if let dueDate = todo.dueDate, !todo.isCompleted {
                Text(dueLabel(dueDate))
                    .font(.caption2)
                    .foregroundStyle(todo.isOverdue ? .orange : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func dueLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Add bar

    private var addBar: some View {
        HStack(spacing: 8) {
            TextField("Quick add…", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .focused($addFocused)
                .onSubmit(addTask)

            Button {
                addTask()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(trimmedNewTitle.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func addTask() {
        store.add(title: newTitle)
        newTitle = ""
        addFocused = true
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            Button {
                onOpenApp()
            } label: {
                Label("Open Tudu", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .help("Open the main window")

            Divider().frame(height: 16)

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .help("Open settings")

            Divider().frame(height: 16)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .help("Quit Tudu")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }
}
