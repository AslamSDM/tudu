import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Main window

struct ContentView: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var prefs = AppPreferences.shared

    @State private var newTitle = ""
    @State private var editorTarget: Todo?
    @State private var isAddingTask = false
    @State private var showClearCompleted = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alert: InfoAlert?
    @FocusState private var newTitleFocused: Bool

    private var trimmedNewTitle: String {
        newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                addBar
                Divider()
                content
            }
            .navigationTitle("Tudu")
            .toolbar { toolbarContent }
            .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search tasks")
        }
        .frame(minWidth: 520, minHeight: 460)
        .sheet(item: $editorTarget) { todo in
            TodoEditorView(
                todo: todo,
                onSave: { store.update($0) },
                onDelete: { store.delete(todo) }
            )
        }
        .sheet(isPresented: $isAddingTask) {
            TodoEditorView(onSave: { store.add($0) })
        }
        .fileExporter(
            isPresented: $isExporting,
            document: TodoExportDocument(todos: store.todos),
            contentType: .json,
            defaultFilename: "Tudu Tasks"
        ) { result in
            if case .failure(let error) = result {
                alert = InfoAlert(
                    title: "Export Failed",
                    message: error.localizedDescription
                )
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
        .alert(item: $alert) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Delete all completed tasks?",
            isPresented: $showClearCompleted,
            titleVisibility: .visible
        ) {
            Button("Delete Completed", role: .destructive) { store.deleteCompleted() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every completed task.")
        }
        .onChange(of: appState.newTaskRequest) { _, _ in
            newTitleFocused = true
        }
        .onChange(of: appState.detailedNewTaskRequest) { _, _ in
            isAddingTask = true
        }
        .onChange(of: appState.exportRequest) { _, _ in
            isExporting = true
        }
        .onChange(of: appState.importRequest) { _, _ in
            isImporting = true
        }
        .onOpenURL { url in
            appState.handle(url)
        }
        .background(MainWindowBridge())
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Pick up changes made from the widget while the app was in the background.
            store.reload()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            ProgressRing(progress: store.stats.progress)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.title3.weight(.semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.stats.overdue > 0 {
                Label("\(store.stats.overdue) overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var headerTitle: String {
        let pending = store.stats.pending
        if store.stats.total == 0 { return "No tasks yet" }
        if pending == 0 { return "All done!" }
        return "\(pending) task\(pending == 1 ? "" : "s") left"
    }

    private var headerSubtitle: String {
        var parts = ["\(store.stats.completed) of \(store.stats.total) complete"]
        if store.stats.dueToday > 0 { parts.append("\(store.stats.dueToday) due today") }
        return parts.joined(separator: " • ")
    }

    // MARK: Add bar

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            TextField("Add a task…", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($newTitleFocused)
                .onSubmit(addTask)

            if !trimmedNewTitle.isEmpty {
                Button("Add", action: addTask)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func addTask() {
        guard let todo = store.add(title: newTitle) else { return }
        newTitle = ""
        newTitleFocused = true
        _ = todo
    }

    private func clearCompleted() {
        if prefs.confirmBeforeDeleting {
            showClearCompleted = true
        } else {
            store.deleteCompleted()
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            alert = InfoAlert(title: "Import Failed", message: error.localizedDescription)

        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                alert = InfoAlert(
                    title: "Import Failed",
                    message: "Could not read the selected file."
                )
                return
            }

            guard let imported = try? JSONDecoder().decode([Todo].self, from: data) else {
                alert = InfoAlert(
                    title: "Import Failed",
                    message: "That file does not contain a valid Tudu task list."
                )
                return
            }

            let added = store.importTodos(imported)
            alert = InfoAlert(
                title: "Import Complete",
                message: "Added \(added) new task\(added == 1 ? "" : "s") and updated existing ones."
            )
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if store.todos.isEmpty {
            EmptyStateView(
                title: "No Tasks Yet",
                systemImage: "checklist",
                message: "Add your first task above to get started."
            )
        } else if store.visibleTodos.isEmpty {
            if !store.searchText.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else if store.filter == .completed {
                EmptyStateView(
                    title: "Nothing Completed",
                    systemImage: "checkmark.circle",
                    message: "Completed tasks will show up here."
                )
            } else {
                EmptyStateView(
                    title: "All Caught Up",
                    systemImage: "checkmark.seal",
                    message: "You have no active tasks right now."
                )
            }
        } else {
            List {
                if !store.visiblePending.isEmpty {
                    Section {
                        ForEach(store.visiblePending) { row(for: $0) }
                    } header: {
                        sectionHeader("To Do", count: store.visiblePending.count, color: .secondary)
                    }
                }

                if !store.visibleCompleted.isEmpty {
                    Section {
                        ForEach(store.visibleCompleted) { row(for: $0) }
                    } header: {
                        sectionHeader("Completed", count: store.visibleCompleted.count, color: .green)
                    }
                }
            }
            .listStyle(.inset)
            .animation(.default, value: store.visibleTodos)
        }
    }

    private func row(for todo: Todo) -> some View {
        TodoRowView(
            todo: todo,
            onToggle: { store.toggle(todo) },
            onEdit: { editorTarget = todo },
            onDuplicate: { store.duplicate(todo) },
            onDelete: { store.delete(todo) }
        )
    }

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .textCase(nil)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Picker("Filter", selection: $store.filter) {
                ForEach(TodoFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
            .help("Filter tasks")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Picker("Sort By", selection: $store.sort) {
                    ForEach(TodoSort.allCases) { sort in
                        Label(sort.title, systemImage: sort.symbolName).tag(sort)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort tasks")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Picker("Tag", selection: $store.tagFilter) {
                    Text("All Tags").tag(String?.none)
                    Divider()
                    ForEach(store.allTags, id: \.self) { tag in
                        Text(tag).tag(String?.some(tag))
                    }
                }
            } label: {
                Label(store.tagFilter ?? "Tags", systemImage: "tag")
            }
            .disabled(store.allTags.isEmpty)
            .help("Filter by tag")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    appState.requestNewTask()
                } label: {
                    Label("New Task", systemImage: "plus")
                }

                Button {
                    appState.requestDetailedNewTask()
                } label: {
                    Label("New Task with Details…", systemImage: "square.and.pencil")
                }

                Divider()

                Button {
                    appState.requestImport()
                } label: {
                    Label("Import Tasks…", systemImage: "square.and.arrow.down")
                }

                Button {
                    appState.requestExport()
                } label: {
                    Label("Export Tasks…", systemImage: "square.and.arrow.up")
                }
                .disabled(store.todos.isEmpty)

                Divider()

                Button {
                    clearCompleted()
                } label: {
                    Label("Clear Completed", systemImage: "checkmark.circle.trianglebadge.exclamationmark")
                }
                .disabled(!store.hasCompleted)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Row

struct TodoRowView: View {
    let todo: Todo
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(checkboxColor)
            }
            .buttonStyle(.plain)
            .help(todo.isCompleted ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.displayTitle)
                    .font(.body)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                if !todo.notes.isEmpty {
                    Text(todo.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !todo.isCompleted, todo.dueDate != nil || todo.priority != .medium {
                    HStack(spacing: 6) {
                        if let dueDate = todo.dueDate {
                            DueDateBadge(date: dueDate, isOverdue: todo.isOverdue)
                        }
                        if todo.priority != .medium {
                            PriorityBadge(priority: todo.priority)
                        }
                    }
                }

                if !todo.tags.isEmpty {
                    FlowLayout(spacing: 4, lineSpacing: 4) {
                        ForEach(todo.tags, id: \.self) { tag in
                            TagChip(tag: tag)
                        }
                    }
                    .opacity(todo.isCompleted ? 0.5 : 1)
                }
            }

            Spacer(minLength: 8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.25)
            .help("Delete")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(
                    todo.isCompleted ? "Mark Incomplete" : "Mark Complete",
                    systemImage: todo.isCompleted ? "circle" : "checkmark.circle"
                )
            }
            Button { onEdit() } label: {
                Label("Edit…", systemImage: "pencil")
            }
            Button { onDuplicate() } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var checkboxColor: Color {
        if todo.isCompleted { return .green }
        return todo.isOverdue ? .orange : .accentColor
    }
}

// MARK: - Small components

/// Captures SwiftUI's `openWindow` action so the AppKit menu bar item can
/// reopen the main window after the user has closed it.
private struct MainWindowBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppState.shared.openMainWindow = { openWindow(id: MainWindow.id) }
            }
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct DueDateBadge: View {
    let date: Date
    let isOverdue: Bool

    var body: some View {
        Label(text, systemImage: "calendar")
            .font(.caption2.weight(.medium))
            .foregroundStyle(isOverdue ? .orange : Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((isOverdue ? Color.orange : Color.secondary).opacity(0.12), in: Capsule())
    }

    private var text: String {
        if isOverdue { return "Overdue" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct PriorityBadge: View {
    let priority: TodoPriority

    var body: some View {
        Label(priority.title, systemImage: priority.symbolName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        priority == .high ? .red : .blue
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
