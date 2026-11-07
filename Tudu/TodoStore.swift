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
    @Published var filter: TodoFilter = .all
    @Published var sort: TodoSort = .created
    @Published var tagFilter: String?

    private init() {
        reload()
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

    /// Tasks matching the current filter + search + tag, pending first.
    var visibleTodos: [Todo] {
        var matches = searchedTodos

        switch filter {
        case .all: break
        case .active: matches = matches.filter { !$0.isCompleted }
        case .completed: matches = matches.filter(\.isCompleted)
        }

        if let tagFilter {
            matches = matches.filter { todo in
                todo.tags.contains { $0.caseInsensitiveCompare(tagFilter) == .orderedSame }
            }
        }

        let pending = sort.sorted(matches.filter { !$0.isCompleted })
        let completed = matches
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
        return pending + completed
    }

    var visiblePending: [Todo] { visibleTodos.filter { !$0.isCompleted } }
    var visibleCompleted: [Todo] { visibleTodos.filter(\.isCompleted) }
    var stats: TodoStats { TodoStats(todos: todos) }
    var hasCompleted: Bool { todos.contains(where: \.isCompleted) }

    func todo(withID id: UUID) -> Todo? {
        todos.first { $0.id == id }
    }

    // MARK: - Mutations

    @discardableResult
    func add(
        title: String,
        notes: String = "",
        priority: TodoPriority = .medium,
        dueDate: Date? = nil
    ) -> Todo? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let todo = Todo(title: trimmed, notes: notes, priority: priority, dueDate: dueDate)
        todos.insert(todo, at: 0)
        persist()
        return todo
    }

    /// Inserts an already-built task (used by the full "new task" editor).
    @discardableResult
    func add(_ todo: Todo) -> Todo? {
        var new = todo
        new.title = new.title.trimmingCharacters(in: .whitespacesAndNewlines)
        new.tags = Todo.normalize(tags: new.tags)
        guard !new.title.isEmpty else { return nil }
        todos.insert(new, at: 0)
        persist()
        return new
    }

    func update(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var updated = todo
        updated.updatedAt = Date()
        updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = Todo.normalize(tags: updated.tags)
        todos[index] = updated
        persist()
    }

    /// Merges imported tasks by id (existing tasks are updated, new ones are
    /// appended). Returns how many tasks were newly added.
    @discardableResult
    func importTodos(_ imported: [Todo]) -> Int {
        var added = 0
        for incoming in imported {
            if let index = todos.firstIndex(where: { $0.id == incoming.id }) {
                todos[index] = incoming
            } else {
                todos.append(incoming)
                added += 1
            }
        }
        persist()
        return added
    }

    func toggle(_ todo: Todo) {
        setCompleted(todo, isCompleted: !todo.isCompleted)
    }

    func setCompleted(_ todo: Todo, isCompleted: Bool) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        guard todos[index].isCompleted != isCompleted else { return }
        todos[index].isCompleted = isCompleted
        todos[index].completedAt = isCompleted ? Date() : nil
        todos[index].updatedAt = Date()
        persist()
    }

    func delete(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
        persist()
    }

    func delete(_ todos: [Todo]) {
        let ids = Set(todos.map(\.id))
        self.todos.removeAll { ids.contains($0.id) }
        persist()
    }

    func deleteCompleted() {
        todos.removeAll(where: \.isCompleted)
        persist()
    }

    func duplicate(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        let copy = Todo(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            dueDate: todo.dueDate,
            tags: todo.tags
        )
        todos.insert(copy, at: index)
        persist()
    }

    /// Re-reads from disk. Used after external changes (widget toggles, deep links).
    func reload() {
        todos = SharedTodoData.loadTodos()
        pruneTagFilter()
        NotificationManager.shared.sync(
            todos: todos,
            enabled: AppPreferences.shared.dueDateNotifications
        )
    }

    /// Drops the active tag filter when no task uses that tag any more.
    private func pruneTagFilter() {
        guard let tagFilter else { return }
        let stillExists = todos.contains { todo in
            todo.tags.contains { $0.caseInsensitiveCompare(tagFilter) == .orderedSame }
        }
        if !stillExists { self.tagFilter = nil }
    }

    private func persist() {
        SharedTodoData.saveTodos(todos)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationManager.shared.sync(
            todos: todos,
            enabled: AppPreferences.shared.dueDateNotifications
        )
        pruneTagFilter()
    }
}
