import Foundation

// MARK: - Priority

/// How urgent a task is.
public enum TodoPriority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    public var symbolName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "exclamationmark.circle"
        }
    }

    /// Higher priority sorts first.
    public var sortWeight: Int { rawValue }
}

// MARK: - Todo

/// A single task. Shared between the app and the widget extension.
public struct Todo: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var priority: TodoPriority
    public var dueDate: Date?
    public var tags: [String]
    public let createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isCompleted: Bool = false,
        priority: TodoPriority = .medium,
        dueDate: Date? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    /// Backwards-compatible decoding. Older versions only stored
    /// `id`, `title`, `isCompleted` and `createdAt`, so every newer field
    /// falls back to a sensible default instead of failing the whole load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        priority = try container.decodeIfPresent(TodoPriority.self, forKey: .priority) ?? .medium
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

// MARK: - Todo helpers

public extension Todo {
    /// A display-safe title that is never empty.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Task" : trimmed
    }

    /// Trims, drops blanks, and removes case-insensitive duplicates while
    /// preserving the order the user entered them in.
    static func normalize(tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { raw in
            let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { return nil }
            return tag
        }
    }

    var isOverdue: Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }

    var isDueToday: Bool {
        guard !isCompleted, let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
}

// MARK: - Filtering & sorting

public enum TodoFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case active
    case completed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }

    public var symbolName: String {
        switch self {
        case .all: return "tray.full"
        case .active: return "circle"
        case .completed: return "checkmark.circle"
        }
    }
}

public enum TodoSort: String, CaseIterable, Identifiable, Sendable {
    case created
    case dueDate
    case priority
    case alphabetical

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .created: return "Newest"
        case .dueDate: return "Due Date"
        case .priority: return "Priority"
        case .alphabetical: return "A–Z"
        }
    }

    public var symbolName: String {
        switch self {
        case .created: return "clock"
        case .dueDate: return "calendar"
        case .priority: return "flag"
        case .alphabetical: return "textformat"
        }
    }

    /// Sorts a list of *pending* tasks. Completed tasks are handled separately.
    public func sorted(_ todos: [Todo]) -> [Todo] {
        switch self {
        case .created:
            return todos.sorted { $0.createdAt > $1.createdAt }

        case .dueDate:
            return todos.sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (left?, right?):
                    return left == right ? lhs.createdAt > rhs.createdAt : left < right
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (nil, nil):
                    return lhs.createdAt > rhs.createdAt
                }
            }

        case .priority:
            return todos.sorted { lhs, rhs in
                lhs.priority.sortWeight == rhs.priority.sortWeight
                    ? lhs.createdAt > rhs.createdAt
                    : lhs.priority.sortWeight > rhs.priority.sortWeight
            }

        case .alphabetical:
            return todos.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
}

// MARK: - Shared Data Access

/// Persists todos in an App Group so the app and the widget extension see the
/// same data. Keep `suiteName` in sync with the `application-groups`
/// entitlement used by both targets (`Config/*.entitlements`).
public enum SharedTodoData {
    public static let suiteName = "group.com.Tudu"

    /// App Group identifiers used by earlier builds. Used once to migrate
    /// existing tasks so nobody loses their list.
    private static let legacySuiteNames = ["group.com.example.todowidget"]

    public static let saveKey = "SavedTodos"
    private static let migrationKey = "DidMigrateToSharedSuite_v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: Loading

    public static func loadTodos() -> [Todo] {
        migrateIfNeeded()

        guard let data = defaults.data(forKey: saveKey) else { return [] }
        return decode(data)
    }

    // MARK: Saving

    public static func saveTodos(_ todos: [Todo]) {
        guard let data = try? JSONEncoder().encode(todos) else { return }
        defaults.set(data, forKey: saveKey)
    }

    // MARK: Convenience mutations (used by the widget's App Intents)

    @discardableResult
    public static func add(title: String) -> Todo? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var todos = loadTodos()
        let todo = Todo(title: trimmed)
        todos.insert(todo, at: 0)
        saveTodos(todos)
        return todo
    }

    /// Flips the completion state of the task with the given id.
    /// - Returns: the new completion state, or `nil` when no task matched.
    @discardableResult
    public static func toggle(id: UUID) -> Bool? {
        setCompleted(id: id, isCompleted: nil)
    }

    /// Sets (or, when `isCompleted` is nil, flips) the completion state.
    @discardableResult
    public static func setCompleted(id: UUID, isCompleted: Bool?) -> Bool? {
        var todos = loadTodos()
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return nil }

        let newValue = isCompleted ?? !todos[index].isCompleted
        todos[index].isCompleted = newValue
        todos[index].completedAt = newValue ? Date() : nil
        todos[index].updatedAt = Date()
        saveTodos(todos)
        return newValue
    }

    // MARK: Migration

    private static func migrateIfNeeded() {
        let current = defaults
        guard current.data(forKey: saveKey) == nil,
              current.bool(forKey: migrationKey) == false else { return }

        current.set(true, forKey: migrationKey)

        for legacyName in legacySuiteNames {
            guard let legacy = UserDefaults(suiteName: legacyName),
                  let data = legacy.data(forKey: saveKey),
                  let todos = decodeIfPossible(data), !todos.isEmpty else { continue }
            saveTodos(todos)
            return
        }

        // Last resort: data that predates App Groups lived in standard defaults.
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let todos = decodeIfPossible(data), !todos.isEmpty {
            saveTodos(todos)
        }
    }

    private static func decode(_ data: Data) -> [Todo] {
        decodeIfPossible(data) ?? []
    }

    private static func decodeIfPossible(_ data: Data) -> [Todo]? {
        try? JSONDecoder().decode([Todo].self, from: data)
    }
}
