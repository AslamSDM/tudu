import Foundation
import Combine
import WidgetKit

/// Aggregate numbers shown in the header and the widgets.
struct TodoStats {
    let total: Int
    let completed: Int
    let pending: Int
    let overdue: Int
    let dueToday: Int

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    init(todos: [Todo]) {
        total = todos.count
        completed = todos.filter(\.isCompleted).count
        pending = total - completed
        overdue = todos.filter(\.isOverdue).count
        dueToday = todos.filter(\.isDueToday).count
    }
}

/// Single source of truth for the app. Persists through `SharedTodoData` and
/// refreshes the widgets on every change.
@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var todos: [Todo] = []

    // Presentation state (not persisted).
    @Published var searchText = ""
    @Published var selection: SmartList = .all
    @Published var sort: TodoSort = .created

    private init() {
        reload()
        observeOtherProcesses()
    }

    /// The widget posts a Darwin notification after it writes; reload so the
    /// menu bar and main window update immediately.
    private func observeOtherProcesses() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, _, _, _, _ in
                Task { @MainActor in TodoStore.shared.reload() }
            },
            SharedTodoData.didChangeNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    // MARK: - Derived collections

    private var searchedTodos: [Todo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return todos }
        return todos.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.notes.localizedCaseInsensitiveContains(query)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// Every tag currently in use, sorted alphabetically.
    var allTags: [String] {
        Todo.normalize(tags: todos.flatMap(\.tags)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    /// Tasks in the selected list that match the search, pending first.
    var visibleTodos: [Todo] {
        let matches = searchedTodos.filter { selection.contains($0) }
        let pending = sort.sorted(matches.filter { !$0.isCompleted })
        let completed = matches
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
        return pending + completed
    }

    /// Badge count for a sidebar row: pending tasks (or completed for the
    /// Completed list).
    func count(for list: SmartList) -> Int {
        todos.filter { list.contains($0) && (list == .completed || !$0.isCompleted) }.count
    }

    var visiblePending: [Todo] { visibleTodos.filter { !$0.isCompleted } }
    var visibleCompleted: [Todo] { visibleTodos.filter(\.isCompleted) }
    var stats: TodoStats { TodoStats(todos: todos) }
    var hasCompleted: Bool { todos.contains(where: \.isCompleted) }

    func todo(withID id: UUID) -> Todo? {
        todos.first { $0.id == id }
    }

    // MARK: - Mutations

    /// Every write goes through `SharedTodoData.mutate`, which reloads from
    /// disk first. That way a change made from the widget is never
    /// overwritten by this process's in-memory copy.
    private func mutate(_ change: (inout [Todo]) -> Set<UUID>) {
        let records = SharedTodoData.mutate(change)
        apply(records)
        didChangeLocally()
    }

    @discardableResult
    func add(
        title: String,
        notes: String = "",
        priority: TodoPriority = .medium,
        dueDate: Date? = nil,
        tags: [String] = []
    ) -> Todo? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let now = Date.nowMillis
        let todo = Todo(
            title: trimmed, notes: notes, priority: priority, dueDate: dueDate,
            tags: Todo.normalize(tags: tags), createdAt: now, updatedAt: now
        )
        mutate { records in
            records.insert(todo, at: 0)
            return [todo.id]
        }
        return todo
    }

    /// Inserts an already-built task (used by the full "new task" editor).
    @discardableResult
    func add(_ todo: Todo) -> Todo? {
        add(title: todo.title, notes: todo.notes, priority: todo.priority, dueDate: todo.dueDate, tags: todo.tags)
    }

    func update(_ todo: Todo) {
        mutate { records in
            guard let index = records.firstIndex(where: { $0.id == todo.id }) else { return [] }
            var updated = todo
            updated.updatedAt = Date.nowMillis
            updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.tags = Todo.normalize(tags: updated.tags)
            records[index] = updated
            return [todo.id]
        }
    }

    /// Merges imported tasks by id (existing tasks are updated, new ones are
    /// appended). Returns how many tasks were newly added.
    @discardableResult
    func importTodos(_ imported: [Todo]) -> Int {
        var added = 0
        mutate { records in
            let now = Date.nowMillis
            var changed = Set<UUID>()
            for var incoming in imported {
                incoming.updatedAt = now
                incoming.deletedAt = nil
                if let index = records.firstIndex(where: { $0.id == incoming.id }) {
                    records[index] = incoming
                } else {
                    records.append(incoming)
                    added += 1
                }
                changed.insert(incoming.id)
            }
            return changed
        }
        return added
    }

    func toggle(_ todo: Todo) {
        setCompleted(todo, isCompleted: !todo.isCompleted)
    }

    func setCompleted(_ todo: Todo, isCompleted: Bool) {
        mutate { records in
            guard let index = records.firstIndex(where: { $0.id == todo.id }),
                  records[index].isCompleted != isCompleted else { return [] }
            let now = Date.nowMillis
            records[index].isCompleted = isCompleted
            records[index].completedAt = isCompleted ? now : nil
            records[index].updatedAt = now
            return [todo.id]
        }
    }

    func delete(_ todo: Todo) {
        delete([todo])
    }

    /// Deletes by turning tasks into tombstones, so the deletion syncs.
    func delete(_ todos: [Todo]) {
        let ids = Set(todos.map(\.id))
        mutate { records in
            let now = Date.nowMillis
            var changed = Set<UUID>()
            for index in records.indices where ids.contains(records[index].id) && !records[index].isDeleted {
                records[index].deletedAt = now
                records[index].updatedAt = now
                changed.insert(records[index].id)
            }
            return changed
        }
    }

    func deleteCompleted() {
        delete(todos.filter(\.isCompleted))
    }

    func duplicate(_ todo: Todo) {
        let now = Date.nowMillis
        let copy = Todo(
            title: todo.title, notes: todo.notes, priority: todo.priority,
            dueDate: todo.dueDate, tags: todo.tags, createdAt: now, updatedAt: now
        )
        mutate { records in
            let index = records.firstIndex(where: { $0.id == todo.id }) ?? 0
            records.insert(copy, at: index)
            return [copy.id]
        }
    }

    /// Re-reads from disk. Used after external changes (widget toggles, sync).
    func reload() {
        apply(SharedTodoData.loadRecords())
    }

    private func apply(_ records: [Todo]) {
        let live = records.filter { !$0.isDeleted }
        if live != todos { todos = live }
        pruneTagFilter()
        NotificationManager.shared.sync(
            todos: todos,
            enabled: AppPreferences.shared.dueDateNotifications
        )
    }

    private func didChangeLocally() {
        WidgetCenter.shared.reloadAllTimelines()
        SyncEngine.shared.scheduleSync()
    }

    /// Falls back to All when the selected tag is no longer used.
    private func pruneTagFilter() {
        guard case .tag = selection else { return }
        if !todos.contains(where: { selection.contains($0) }) { selection = .all }
    }
}
