import SwiftUI
import AppKit

/// Compact task list shown in the menu bar popover.
struct MenuBarView: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var onOpenApp: () -> Void = {}

    enum Scope: String, CaseIterable, Identifiable {
        case today = "Today"
        case all = "All"
        var id: String { rawValue }
    }

    @AppStorage("menuBarScope") private var scope: Scope = .all
    @State private var newTitle = ""
    @State private var hovered: UUID?
    @FocusState private var addFocused: Bool

    private var pending: [Todo] {
        let base = store.todos.filter { !$0.isCompleted }
        let scoped = scope == .today ? base.filter { SmartList.today.contains($0) } : base
        return TodoSort.dueDate.sorted(scoped).sorted { lhs, rhs in
            // Overdue first, then high priority, keeping the due-date order.
            (lhs.isOverdue ? 1 : 0, lhs.priority.rawValue) > (rhs.isOverdue ? 1 : 0, rhs.priority.rawValue)
        }
    }

    private var recentlyCompleted: [Todo] {
        Array(
            store.todos.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
                .prefix(3)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            QuickAddField(
                text: $newTitle,
                placeholder: "Quick add…  #tag  !high  @tomorrow",
                compact: true,
                focus: $addFocused,
                onSubmit: addTask
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.6)

            list

            Divider().opacity(0.6)

            footer
        }
        .frame(width: prefs.menuBarWidth, height: prefs.menuBarHeight)
        .background(.ultraThinMaterial)
        .onAppear {
            store.reload()
            SyncEngine.shared.syncNow()
        }
    }

    // MARK: Header

    private var header: some View {
        let stats = store.stats
        return HStack(spacing: 12) {
            ProgressRing(progress: stats.progress, lineWidth: 3.5, showsLabel: false)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: stats.pending == 0 && stats.total > 0 ? "checkmark" : "checklist")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(stats.pending == 0 ? "All caught up" : "\(stats.pending) to do")
                    .font(.headline)
                HStack(spacing: 6) {
                    if stats.overdue > 0 {
                        Text("\(stats.overdue) overdue").foregroundStyle(.orange)
                    }
                    if stats.dueToday > 0 {
                        Text("\(stats.dueToday) today")
                    }
                    if stats.overdue == 0 && stats.dueToday == 0 {
                        Text("\(stats.completed) of \(stats.total) done")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 110)
        }
    }

    // MARK: List

    @ViewBuilder
    private var list: some View {
        if pending.isEmpty && recentlyCompleted.isEmpty {
            EmptyStateView(
                title: scope == .today ? "Nothing due today" : "All caught up",
                systemImage: scope == .today ? "sun.max" : "checkmark.seal",
                message: "Add a task above to get started.",
                tint: scope == .today ? .orange : .green
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if pending.isEmpty {
                        Text(scope == .today ? "Nothing due today 🎉" : "Nothing left to do 🎉")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    ForEach(pending) { taskRow($0) }

                    if !recentlyCompleted.isEmpty {
                        Text("Recently completed")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                        ForEach(recentlyCompleted) { taskRow($0) }
                    }
                }
                .padding(.vertical, 6)
                .animation(.snappy(duration: 0.22), value: store.todos)
            }
        }
    }

    private func taskRow(_ todo: Todo) -> some View {
        HStack(spacing: 10) {
            CheckButton(
                isOn: todo.isCompleted,
                tint: todo.isOverdue ? .orange : (todo.priority == .high ? .red : .secondary),
                size: 16
            ) {
                store.toggle(todo)
            }

            Text(todo.displayTitle)
                .font(.callout)
                .strikethrough(todo.isCompleted, color: .secondary)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let tag = todo.tags.first, !todo.isCompleted {
                Circle()
                    .fill(Color.forTag(tag))
                    .frame(width: 6, height: 6)
                    .help(todo.tags.joined(separator: ", "))
            }

            Spacer(minLength: 4)

            if hovered == todo.id {
                Button {
                    store.delete(todo)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete")
            } else if let due = todo.dueDate, !todo.isCompleted {
                Text(DueText.short(due, isOverdue: todo.isOverdue))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(todo.isOverdue || todo.isDueToday ? .orange : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(hovered == todo.id ? Color.primary.opacity(0.06) : .clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 ? todo.id : (hovered == todo.id ? nil : hovered) }
    }

    private func addTask() {
        store.addQuick(newTitle, context: scope == .today ? .today : .all)
        newTitle = ""
        addFocused = true
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            SyncStatusView()

            Spacer()

            footerButton("macwindow", help: "Open Tudu", action: onOpenApp)

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            footerButton("power", help: "Quit Tudu") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func footerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
