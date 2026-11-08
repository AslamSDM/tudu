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
    /// Set when the task is deleted. Deleted tasks are kept as tombstones so
    /// the deletion can sync to other devices; the UI never shows them.
    public var deletedAt: Date?

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
        completedAt: Date? = nil,
        deletedAt: Date? = nil
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
        self.deletedAt = deletedAt
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
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - Todo helpers

public extension Todo {
    var isDeleted: Bool { deletedAt != nil }

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


// MARK: - Smart lists

/// The lists shown in the sidebar (and used by the widgets).
public enum SmartList: Hashable, Sendable {
    case today
    case upcoming
    case all
    case completed
    case tag(String)

    public static let fixed: [SmartList] = [.today, .upcoming, .all, .completed]

    public var title: String {
        switch self {
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .all: return "All Tasks"
        case .completed: return "Completed"
        case .tag(let tag): return tag
        }
    }

    public var symbolName: String {
        switch self {
        case .today: return "sun.max.fill"
        case .upcoming: return "calendar"
        case .all: return "tray.full.fill"
        case .completed: return "checkmark.circle.fill"
        case .tag: return "number"
        }
    }

    /// Whether completed tasks belong in this list.
    public var includesCompleted: Bool {
        switch self {
        case .completed, .all, .tag: return true
        case .today, .upcoming: return false
        }
    }

    public func contains(_ todo: Todo) -> Bool {
        guard !todo.isDeleted else { return false }
        switch self {
        case .today:
            return !todo.isCompleted && (todo.isOverdue || todo.isDueToday)
        case .upcoming:
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= Calendar.current.startOfDay(for: Date())
        case .all:
            return true
        case .completed:
            return todo.isCompleted
        case .tag(let tag):
            return todo.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }
    }
}

// MARK: - Quick add parsing

/// Parses shorthand typed into a quick-add field:
/// `#tag`, `!high` / `!low` (or `!!`, `!3`, `!1`), and `@today`, `@tomorrow`,
/// `@mon`…`@sun`, `@next week`. Unrecognised tokens stay in the title.
public struct QuickAddParser {
    public struct Result: Equatable {
        public var title: String
        public var tags: [String] = []
        public var priority: TodoPriority = .medium
        public var dueDate: Date?

        public var hasMetadata: Bool { !tags.isEmpty || priority != .medium || dueDate != nil }
    }

    public static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Result {
        var result = Result(title: "")
        var words: [String] = []
        let tokens = input.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var i = 0

        while i < tokens.count {
            let token = tokens[i]
            let lower = token.lowercased()

            if token.count > 1, token.hasPrefix("#") {
                result.tags.append(String(token.dropFirst()))
            } else if let priority = priority(from: lower) {
                result.priority = priority
            } else if lower == "@next", i + 1 < tokens.count, tokens[i + 1].lowercased() == "week" {
                result.dueDate = dueOn(calendar.date(byAdding: .day, value: 7, to: now) ?? now, now: now, calendar)
                i += 1
            } else if lower.hasPrefix("@"), let date = date(from: String(lower.dropFirst()), now: now, calendar: calendar) {
                result.dueDate = date
            } else {
                words.append(token)
            }
            i += 1
        }

        result.title = words.joined(separator: " ")
        result.tags = Todo.normalize(tags: result.tags)
        return result
    }

    private static func priority(from token: String) -> TodoPriority? {
        switch token {
        case "!high", "!h", "!!", "!3", "!urgent": return .high
        case "!low", "!l", "!1": return .low
        case "!med", "!medium", "!2": return .medium
        default: return nil
        }
    }

    /// 5 PM on `date`, or 11:59 PM when 5 PM has already passed, so a new
    /// task is never born overdue.
    private static func dueOn(_ date: Date, now: Date, _ calendar: Calendar) -> Date {
        let fivePM = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date) ?? date
        if fivePM > now { return fivePM }
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date) ?? date
    }

    /// Calendar weekday (1 = Sunday) for each accepted spelling. Exact matches
    /// only, so a word like `@monica` stays in the title.
    private static let weekdays: [String: Int] = [
        "sun": 1, "sunday": 1,
        "mon": 2, "monday": 2,
        "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "weds": 4, "wednesday": 4,
        "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6,
        "sat": 7, "saturday": 7,
    ]

    private static func date(from word: String, now: Date, calendar: Calendar) -> Date? {
        switch word {
        case "today", "tod": return dueOn(now, now: now, calendar)
        case "tomorrow", "tom", "tmr": return dueOn(calendar.date(byAdding: .day, value: 1, to: now) ?? now, now: now, calendar)
        default: break
        }
        guard let target = weekdays[word] else { return nil }
        let today = calendar.component(.weekday, from: now)
        var delta = (target - today + 7) % 7
        if delta == 0 { delta = 7 }
        return dueOn(calendar.date(byAdding: .day, value: delta, to: now) ?? now, now: now, calendar)
    }
}

// MARK: - Time helpers

public extension Date {
    /// Milliseconds since the Unix epoch (the sync wire format).
    var unixMillis: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(unixMillis: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(unixMillis) / 1000)
    }

    /// "Now", truncated to whole milliseconds so local timestamps compare
    /// exactly with the ones that come back from the server.
    static var nowMillis: Date { Date(unixMillis: Date().unixMillis) }
}

// MARK: - Shared Data Access

/// Persists todos in an App Group so the app and the widget extension see the
/// same data. Keep `suiteName` in sync with the `application-groups`
/// entitlement used by both targets (`Config/*.entitlements`).
///
/// Storage holds every record, including deletion tombstones, plus the set of
/// ids changed locally since the last successful sync push.
public enum SharedTodoData {
    public static let suiteName = "group.com.Tudu"

    /// Darwin notification posted after any process writes the task list, so
    /// the app picks up changes made from the widget immediately.
    public static let didChangeNotification = "group.com.Tudu.todosChanged"

    /// App Group identifiers used by earlier builds. Used once to migrate
    /// existing tasks so nobody loses their list.
    private static let legacySuiteNames = ["group.com.example.todowidget"]

    public static let saveKey = "SavedTodos"
    private static let pendingKey = "SyncPendingIDs"
    private static let migrationKey = "DidMigrateToSharedSuite_v1"

    /// Serializes read-modify-write cycles inside one process.
    private static let lock = NSRecursiveLock()

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: Loading

    /// Live (not deleted) tasks.
    public static func loadTodos() -> [Todo] {
        loadRecords().filter { !$0.isDeleted }
    }

    /// Every stored record, including tombstones.
    public static func loadRecords() -> [Todo] {
        lock.lock(); defer { lock.unlock() }
        migrateIfNeeded()
        guard let data = defaults.data(forKey: saveKey) else { return [] }
        return decodeIfPossible(data) ?? []
    }

    // MARK: Saving

    /// Applies `change` to a fresh copy of the stored records, saves the
    /// result, and marks the ids it returns as pending sync. Always reload
    /// first, so a write from the widget is never lost to a stale copy.
    @discardableResult
    public static func mutate(_ change: (inout [Todo]) -> Set<UUID>) -> [Todo] {
        lock.lock(); defer { lock.unlock() }
        var records = loadRecords()
        let changed = change(&records)
        guard !changed.isEmpty else { return records }
        write(records)
        markPending(changed)
        postDidChange()
        return records
    }

    /// Read-modify-write without marking anything pending. Used by the sync
    /// engine to merge server changes. `change` returns whether it modified
    /// the records.
    public static func updateRecords(_ change: (inout [Todo]) -> Bool) {
        lock.lock(); defer { lock.unlock() }
        var records = loadRecords()
        guard change(&records) else { return }
        write(records)
        postDidChange()
    }

    /// Drops tombstones that are already synced (or that never need to be)
    /// and are older than `age`.
    public static func purgeTombstones(olderThan age: TimeInterval = 30 * 24 * 3600) {
        let cutoff = Date().addingTimeInterval(-age)
        let pending = pendingIDs()
        updateRecords { records in
            let before = records.count
            records.removeAll { todo in
                guard let deleted = todo.deletedAt else { return false }
                return deleted < cutoff && !pending.contains(todo.id)
            }
            return records.count != before
        }
    }

    private static func write(_ records: [Todo]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: saveKey)
    }

    // MARK: Pending sync state

    public static func pendingIDs() -> Set<UUID> {
        let raw = defaults.stringArray(forKey: pendingKey) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    public static func markPending(_ ids: Set<UUID>) {
        lock.lock(); defer { lock.unlock() }
        let merged = pendingIDs().union(ids)
        defaults.set(merged.map(\.uuidString), forKey: pendingKey)
    }

    public static func clearPending(_ ids: Set<UUID>) {
        lock.lock(); defer { lock.unlock() }
        let remaining = pendingIDs().subtracting(ids)
        defaults.set(remaining.map(\.uuidString), forKey: pendingKey)
    }

    /// Marks every stored record as pending (used when joining a sync space,
    /// so existing local tasks upload).
    public static func markAllPending() {
        markPending(Set(loadRecords().map(\.id)))
    }

    // MARK: Cross-process change notification

    public static func postDidChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(didChangeNotification as CFString),
            nil, nil, true
        )
    }

    // MARK: Convenience mutations (used by the widget's App Intents)

    @discardableResult
    public static func add(title: String) -> Todo? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let now = Date.nowMillis
        let todo = Todo(title: trimmed, createdAt: now, updatedAt: now)
        mutate { records in
            records.insert(todo, at: 0)
            return [todo.id]
        }
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
        var result: Bool?
        mutate { records in
            guard let index = records.firstIndex(where: { $0.id == id && !$0.isDeleted }) else { return [] }
            let newValue = isCompleted ?? !records[index].isCompleted
            let now = Date.nowMillis
            records[index].isCompleted = newValue
            records[index].completedAt = newValue ? now : nil
            records[index].updatedAt = now
            result = newValue
            return [id]
        }
        return result
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
            write(todos)
            return
        }

        // Last resort: data that predates App Groups lived in standard defaults.
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let todos = decodeIfPossible(data), !todos.isEmpty {
            write(todos)
        }
    }

    private static func decodeIfPossible(_ data: Data) -> [Todo]? {
        try? JSONDecoder().decode([Todo].self, from: data)
    }
}
