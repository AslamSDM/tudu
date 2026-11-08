import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Main window

struct ContentView: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var prefs = AppPreferences.shared

    @State private var editorTarget: Todo?
    @State private var isAddingTask = false
    @State private var showClearCompleted = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alert: InfoAlert?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } detail: {
            TaskListView(
                onEdit: { editorTarget = $0 },
                onClearCompleted: clearCompleted
            )
            .toolbar { toolbarContent }
            .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search tasks")
        }
        .frame(minWidth: 640, minHeight: 460)
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
                alert = InfoAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert(item: $alert) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")))
        }
        .alert(
            "Join sync space?",
            isPresented: Binding(
                get: { appState.pendingPairing != nil },
                set: { if !$0 { appState.pendingPairing = nil } }
            ),
            presenting: appState.pendingPairing
        ) { pairing in
            Button("Join") {
                SyncEngine.shared.connect(key: pairing.key, serverURL: pairing.server)
                appState.pendingPairing = nil
            }
            Button("Cancel", role: .cancel) { appState.pendingPairing = nil }
        } message: { pairing in
            Text("Tudu will merge your tasks with the sync space on \(pairing.server.host() ?? "the server"). Your tasks will sync across every device that uses this key.")
        }
        .confirmationDialog(
            "Delete all completed tasks?",
            isPresented: $showClearCompleted,
            titleVisibility: .visible
        ) {
            Button("Delete Completed", role: .destructive) { store.deleteCompleted() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every completed task on all synced devices.")
        }
        .onChange(of: appState.detailedNewTaskRequest) { _, _ in isAddingTask = true }
        .onChange(of: appState.exportRequest) { _, _ in isExporting = true }
        .onChange(of: appState.importRequest) { _, _ in isImporting = true }
        .onOpenURL { appState.handle($0) }
        .background(MainWindowBridge())
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.reload()
        }
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
                alert = InfoAlert(title: "Import Failed", message: "Could not read the selected file.")
                return
            }
            guard let imported = try? JSONDecoder().decode([Todo].self, from: data) else {
                alert = InfoAlert(title: "Import Failed", message: "That file does not contain a valid Tudu task list.")
                return
            }
            let added = store.importTodos(imported)
            alert = InfoAlert(
                title: "Import Complete",
                message: "Added \(added) new task\(added == 1 ? "" : "s") and updated existing ones."
            )
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                Picker("Sort By", selection: $store.sort) {
                    ForEach(TodoSort.allCases) { sort in
                        Label(sort.title, systemImage: sort.symbolName).tag(sort)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort tasks")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                appState.requestDetailedNewTask()
            } label: {
                Label("New Task", systemImage: "square.and.pencil")
            }
            .help("New task with details (⇧⌘N)")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
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
                    SyncEngine.shared.syncNow()
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!SyncEngine.shared.isConfigured)

                Divider()

                Button(role: .destructive) {
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

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var sync = SyncEngine.shared

    var body: some View {
        List(selection: Binding(
            get: { Optional(store.selection) },
            set: { if let value = $0 { store.selection = value } }
        )) {
            Section {
                ForEach(SmartList.fixed, id: \.self) { list in
                    SidebarRow(list: list, count: store.count(for: list))
                        .tag(list)
                }
            }

            if !store.allTags.isEmpty {
                Section("Tags") {
                    ForEach(store.allTags, id: \.self) { tag in
                        SidebarRow(list: .tag(tag), count: store.count(for: .tag(tag)))
                            .tag(SmartList.tag(tag))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                SyncStatusView()
                Spacer()
                if !sync.isConfigured {
                    SettingsLink {
                        Text("Set Up")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        sync.syncNow()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Sync now")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

private struct SidebarRow: View {
    let list: SmartList
    let count: Int

    var body: some View {
        Label {
            HStack {
                Text(list.title)
                    .lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            if case .tag = list {
                Circle()
                    .fill(list.tint)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: list.symbolName)
                    .foregroundStyle(list.tint)
            }
        }
    }
}

// MARK: - Task list (detail)

struct TaskListView: View {
    @ObservedObject private var store = TodoStore.shared
    @ObservedObject private var appState = AppState.shared

    let onEdit: (Todo) -> Void
    let onClearCompleted: () -> Void

    @State private var newTitle = ""
    @State private var showCompleted = true
    @FocusState private var addFocused: Bool

    private var list: SmartList { store.selection }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 14)

            QuickAddField(text: $newTitle, focus: $addFocused, onSubmit: addTask)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            content
        }
        .background(.background)
        .navigationTitle(list.title)
        .navigationSubtitle(subtitle)
        .onChange(of: appState.newTaskRequest) { _, _ in addFocused = true }
    }

    // MARK: Header

    private var listTodos: [Todo] { store.todos.filter { list.contains($0) } }

    private var header: some View {
        let total = listTodos.count
        let done = listTodos.filter(\.isCompleted).count
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        let overdue = listTodos.filter(\.isOverdue).count

        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: list.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(list.tint.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(list.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(headline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if overdue > 0 {
                Label("\(overdue) overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            if list.includesCompleted && total > 0 {
                ProgressRing(progress: progress, lineWidth: 4, tint: list.tint)
                    .frame(width: 42, height: 42)
                    .help("\(done) of \(total) done")
            }
        }
    }

    private var headline: String {
        let pending = listTodos.filter { !$0.isCompleted }.count
        if listTodos.isEmpty { return emptyHeadline }
        if pending == 0 { return "All done — nice work." }
        let base = "\(pending) to do"
        let today = listTodos.filter(\.isDueToday).count
        return today > 0 && list != .today ? "\(base) · \(today) due today" : base
    }

    private var emptyHeadline: String {
        switch list {
        case .today: return "Nothing due today."
        case .upcoming: return "No scheduled tasks."
        case .completed: return "Nothing completed yet."
        default: return "No tasks yet."
        }
    }

    private var subtitle: String {
        let pending = store.stats.pending
        return pending == 0 ? "All caught up" : "\(pending) open"
    }

    private func addTask() {
        guard store.addQuick(newTitle) != nil else { return }
        newTitle = ""
        addFocused = true
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        let pending = store.visiblePending
        let completed = store.visibleCompleted

        if pending.isEmpty && completed.isEmpty {
            if !store.searchText.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else {
                emptyState
            }
        } else {
            List {
                if !pending.isEmpty {
                    if list == .upcoming {
                        ForEach(groupedByDay(pending), id: \.day) { group in
                            Section {
                                ForEach(group.todos) { row(for: $0) }
                            } header: {
                                sectionHeader(dayTitle(group.day), count: group.todos.count)
                            }
                        }
                    } else {
                        Section {
                            ForEach(pending) { row(for: $0) }
                        }
                    }
                }

                if !completed.isEmpty {
                    Section(isExpanded: $showCompleted) {
                        ForEach(completed) { row(for: $0) }
                    } header: {
                        HStack {
                            Text("Completed")
                            Text("\(completed.count)").monospacedDigit().foregroundStyle(.tertiary)
                            Spacer()
                            Button("Clear", action: onClearCompleted)
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .animation(.snappy(duration: 0.25), value: store.visibleTodos)
        }
    }

    private var emptyState: some View {
        switch list {
        case .today:
            return EmptyStateView(title: "Free day", systemImage: "sun.max", message: "Nothing is due today. Add a task with @today to plan it in.", tint: .orange)
        case .upcoming:
            return EmptyStateView(title: "Nothing scheduled", systemImage: "calendar", message: "Tasks with a due date show up here, grouped by day.", tint: .red)
        case .completed:
            return EmptyStateView(title: "Nothing completed", systemImage: "checkmark.circle", message: "Completed tasks will show up here.", tint: .green)
        case .tag(let tag):
            return EmptyStateView(title: "No tasks in #\(tag)", systemImage: "number", message: "Add one above — it gets this tag automatically.", tint: .forTag(tag))
        case .all:
            return EmptyStateView(title: "No tasks yet", systemImage: "checklist", message: "Type above and press Return. Use #tags, !high and @tomorrow as shortcuts.", tint: .blue)
        }
    }

    private func row(for todo: Todo) -> some View {
        TodoRowView(
            todo: todo,
            onToggle: { store.toggle(todo) },
            onEdit: { onEdit(todo) },
            onDuplicate: { store.duplicate(todo) },
            onDelete: { store.delete(todo) },
            onSetPriority: { priority in
                var copy = todo
                copy.priority = priority
                store.update(copy)
            }
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Text("\(count)").monospacedDigit().foregroundStyle(.tertiary)
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .textCase(nil)
    }

    private struct DayGroup { let day: Date; let todos: [Todo] }

    private func groupedByDay(_ todos: [Todo]) -> [DayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: todos) { calendar.startOfDay(for: $0.dueDate ?? .distantFuture) }
        return groups.keys.sorted().map { day in
            DayGroup(day: day, todos: groups[day]!.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

// MARK: - Row

struct TodoRowView: View {
    let todo: Todo
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    var onSetPriority: ((TodoPriority) -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckButton(isOn: todo.isCompleted, tint: checkTint, action: onToggle)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if todo.priority == .high && !todo.isCompleted {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text(todo.displayTitle)
                        .font(.body)
                        .strikethrough(todo.isCompleted, color: .secondary)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                }

                if !todo.notes.isEmpty {
                    Text(todo.notes)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if hasMeta {
                    FlowLayout(spacing: 5, lineSpacing: 4) {
                        if let due = todo.dueDate, !todo.isCompleted {
                            DueDateBadge(date: due, isOverdue: todo.isOverdue)
                        }
                        if todo.priority == .low && !todo.isCompleted {
                            PriorityBadge(priority: .low)
                        }
                        ForEach(todo.tags, id: \.self) { TagChip(tag: $0) }
                    }
                    .opacity(todo.isCompleted ? 0.55 : 1)
                }
            }

            Spacer(minLength: 8)

            if isHovering {
                HStack(spacing: 2) {
                    rowButton("pencil", help: "Edit", action: onEdit)
                    rowButton("trash", help: "Delete", action: onDelete)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.045) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .contextMenu { contextMenu }
    }

    private var hasMeta: Bool {
        (!todo.isCompleted && (todo.dueDate != nil || todo.priority == .low)) || !todo.tags.isEmpty
    }

    private var checkTint: Color {
        if todo.isOverdue { return .orange }
        return todo.priority == .high ? .red : .secondary
    }

    private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button {
            onToggle()
        } label: {
            Label(todo.isCompleted ? "Mark Incomplete" : "Mark Complete",
                  systemImage: todo.isCompleted ? "circle" : "checkmark.circle")
        }
        Button { onEdit() } label: { Label("Edit…", systemImage: "pencil") }
        if let onSetPriority {
            Menu {
                ForEach(TodoPriority.allCases.reversed()) { priority in
                    Button {
                        onSetPriority(priority)
                    } label: {
                        if priority == todo.priority {
                            Label(priority.title, systemImage: "checkmark")
                        } else {
                            Text(priority.title)
                        }
                    }
                }
            } label: {
                Label("Priority", systemImage: "flag")
            }
        }
        Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
    }
}

// MARK: - Window bridge

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

#Preview {
    ContentView()
}
