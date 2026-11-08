import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration

enum WidgetListOption: String, AppEnum {
    case all, today, highPriority

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "List"
    static var caseDisplayRepresentations: [WidgetListOption: DisplayRepresentation] = [
        .all: "All Tasks",
        .today: "Today",
        .highPriority: "High Priority",
    ]

    var title: String {
        switch self {
        case .all: return "Tudu"
        case .today: return "Today"
        case .highPriority: return "Priority"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "checklist"
        case .today: return "sun.max.fill"
        case .highPriority: return "flag.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return .blue
        case .today: return .orange
        case .highPriority: return .red
        }
    }

    func contains(_ todo: Todo) -> Bool {
        switch self {
        case .all: return true
        case .today: return SmartList.today.contains(todo)
        case .highPriority: return todo.priority == .high
        }
    }
}

struct TuduWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Tudu Widget"
    static var description = IntentDescription("Choose which tasks to show.")

    @Parameter(title: "List", default: .all)
    var list: WidgetListOption

    @Parameter(title: "Show Completed", default: false)
    var showCompleted: Bool
}

// MARK: - Timeline

struct TodoWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(date: Date(), todos: SampleData.todos, config: TuduWidgetConfigIntent(), syncFailed: false)
    }

    func snapshot(for configuration: TuduWidgetConfigIntent, in context: Context) async -> TodoWidgetEntry {
        let todos = context.isPreview ? SampleData.todos : SharedTodoData.loadTodos()
        return TodoWidgetEntry(date: Date(), todos: todos, config: configuration, syncFailed: false)
    }

    func timeline(for configuration: TuduWidgetConfigIntent, in context: Context) async -> Timeline<TodoWidgetEntry> {
        // Pull from the server so the widget stays fresh even when the app is
        // not running. Failures fall back to local data.
        var syncFailed = false
        if SyncConfig.isEnabled {
            do { try await SyncClient.sync(timeout: 8) } catch { syncFailed = true }
        }

        let now = Date()
        let entry = TodoWidgetEntry(date: now, todos: SharedTodoData.loadTodos(), config: configuration, syncFailed: syncFailed)
        let refresh = min(
            now.addingTimeInterval(15 * 60),
            Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 3600))
        )
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [Todo]
    let config: TuduWidgetConfigIntent
    let syncFailed: Bool

    var list: WidgetListOption { config.list }

    var scoped: [Todo] { todos.filter(list.contains) }

    /// Pending tasks: overdue first, then by due date, then priority, then newest.
    var pending: [Todo] {
        scoped.filter { !$0.isCompleted }.sorted { lhs, rhs in
            if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?) where l != r: return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: break
            }
            if lhs.priority != rhs.priority { return lhs.priority.rawValue > rhs.priority.rawValue }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var completed: [Todo] {
        scoped.filter(\.isCompleted).sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    /// Rows to show: pending, then (optionally) recently completed.
    func rows(limit: Int) -> [Todo] {
        let base = config.showCompleted ? pending + completed : pending
        return Array(base.prefix(limit))
    }

    var progress: Double {
        scoped.isEmpty ? 0 : Double(completed.count) / Double(scoped.count)
    }

    var overdueCount: Int { pending.filter(\.isOverdue).count }
}

// MARK: - Entry view

struct TodoWidgetEntryView: View {
    var entry: TodoWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            case .systemLarge: ListWidgetView(entry: entry, limit: 8)
            case .systemExtraLarge, .systemExtraLargePortrait: ListWidgetView(entry: entry, limit: 9, columns: 2)
            @unknown default: SmallWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "tudu://open"))
    }
}

// MARK: - Small

struct SmallWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    WidgetRing(progress: entry.progress, tint: entry.list.tint, lineWidth: 5)
                    Text("\(entry.pending.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .frame(width: 50, height: 50)

                Spacer()

                AddLink(tint: entry.list.tint)
            }

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: entry.list.symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(entry.list.tint)
                    .widgetAccentable()
                Text(entry.pending.isEmpty ? "All done" : "\(entry.list.title) · to do")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if entry.overdueCount > 0 {
                    Text("· \(entry.overdueCount) late")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .lineLimit(1)

            if let next = entry.pending.first {
                HStack(alignment: .top, spacing: 6) {
                    ToggleTodoButton(todo: next, size: 15)
                    Text(next.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                }
                .padding(.top, 4)
            } else {
                Text(entry.scoped.isEmpty ? "No tasks yet" : "Nothing left 🎉")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Medium

struct MediumWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetTitle(entry: entry)
                Spacer(minLength: 0)
                Text("\(entry.pending.count)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(entry.list.tint.gradient)
                    .widgetAccentable()
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.overdueCount > 0 ? .orange : .secondary)
                    .lineLimit(1)
                WidgetProgressBar(progress: entry.progress, tint: entry.list.tint)
            }
            .frame(width: 104)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Spacer()
                    AddLink(tint: entry.list.tint)
                }
                .frame(height: 16)

                let rows = entry.rows(limit: 4)
                if rows.isEmpty {
                    WidgetEmptyState(hasTasks: !entry.scoped.isEmpty)
                } else {
                    ForEach(rows) { TodoWidgetRow(todo: $0) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var subtitle: String {
        if entry.overdueCount > 0 { return "\(entry.overdueCount) overdue" }
        return entry.pending.count == 1 ? "task to do" : "tasks to do"
    }
}

// MARK: - Large / extra large

struct ListWidgetView: View {
    let entry: TodoWidgetEntry
    let limit: Int
    var columns = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                WidgetTitle(entry: entry)
                Spacer()
                if entry.syncFailed {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                AddLink(tint: entry.list.tint)
            }

            HStack(spacing: 8) {
                StatPill(value: entry.pending.count, title: "To do", color: entry.list.tint)
                StatPill(value: entry.overdueCount, title: "Overdue", color: .orange)
                StatPill(value: entry.completed.count, title: "Done", color: .green)
            }

            let rows = entry.rows(limit: limit * columns)
            if rows.isEmpty {
                WidgetEmptyState(hasTasks: !entry.scoped.isEmpty)
            } else {
                if columns > 1 {
                    let split = (rows.count + 1) / 2
                    HStack(alignment: .top, spacing: 16) {
                        rowStack(Array(rows.prefix(split)))
                        rowStack(Array(rows.dropFirst(split)))
                    }
                } else {
                    rowStack(rows)
                }
                Spacer(minLength: 0)
                let total = entry.config.showCompleted ? entry.pending.count + entry.completed.count : entry.pending.count
                if total > rows.count {
                    Text("+\(total - rows.count) more")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                }
            }
        }
    }

    private func rowStack(_ todos: [Todo]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(todos) { TodoWidgetRow(todo: $0, showsNotes: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Components

struct WidgetTitle: View {
    let entry: TodoWidgetEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.list.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(entry.list.tint.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .widgetAccentable()
            Text(entry.list.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
    }
}

struct AddLink: View {
    let tint: Color

    var body: some View {
        Link(destination: URL(string: "tudu://add")!) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.15), in: Circle())
                .widgetAccentable()
        }
    }
}

struct TodoWidgetRow: View {
    let todo: Todo
    var showsNotes = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ToggleTodoButton(todo: todo, size: 15)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if todo.priority == .high && !todo.isCompleted {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.red)
                    }
                    Text(todo.displayTitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }

                if let meta = metaText {
                    Text(meta)
                        .font(.system(size: 10.5))
                        .foregroundStyle(todo.isOverdue || todo.isDueToday ? .orange : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var metaText: String? {
        var parts: [String] = []
        if let due = todo.dueDate, !todo.isCompleted { parts.append(dueText(due)) }
        if showsNotes, !todo.tags.isEmpty { parts.append(todo.tags.map { "#\($0)" }.joined(separator: " ")) }
        if showsNotes, parts.isEmpty, !todo.notes.isEmpty { parts.append(todo.notes) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func dueText(_ date: Date) -> String {
        if todo.isOverdue { return "Overdue" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

struct ToggleTodoButton: View {
    let todo: Todo
    var size: CGFloat = 14

    var body: some View {
        Button(intent: ToggleTodoIntent(taskID: todo.id.uuidString)) {
            ZStack {
                Circle()
                    .strokeBorder(todo.isCompleted ? Color.green : ringColor, lineWidth: 1.4)
                if todo.isCompleted {
                    Circle().fill(Color.green)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
            .widgetAccentable()
        }
        .buttonStyle(.plain)
    }

    private var ringColor: Color {
        if todo.isOverdue { return .orange }
        return todo.priority == .high ? .red : .secondary
    }
}

struct WidgetRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(progress >= 1 ? Color.green : tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }
}

struct WidgetProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule()
                    .fill(progress >= 1 ? Color.green : tint)
                    .frame(width: max(4, proxy.size.width * progress))
                    .widgetAccentable()
            }
        }
        .frame(height: 5)
    }
}

struct StatPill: View {
    let value: Int
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value == 0 ? .secondary : color)
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(value == 0 ? 0.06 : 0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct WidgetEmptyState: View {
    let hasTasks: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: hasTasks ? "checkmark.seal.fill" : "sparkles")
                .font(.title2)
                .foregroundStyle(hasTasks ? .green : .secondary)
            Text(hasTasks ? "All done!" : "No tasks yet")
                .font(.caption.weight(.semibold))
            if !hasTasks {
                Text("Tap + to add one")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct TuduWidget: Widget {
    let kind: String = "TuduWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TuduWidgetConfigIntent.self, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tudu")
        .description("Your tasks at a glance. Tick them off right from the widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Preview data

private enum SampleData {
    static let todos: [Todo] = [
        Todo(title: "Buy groceries", priority: .high, dueDate: Date().addingTimeInterval(3600), tags: ["home"]),
        Todo(title: "Finish project report", priority: .high, dueDate: Date().addingTimeInterval(-3600)),
        Todo(title: "Review pull requests", priority: .low, tags: ["work"]),
        Todo(title: "Call mom", isCompleted: true, completedAt: Date()),
        Todo(title: "Plan sprint retrospective", dueDate: Date().addingTimeInterval(86400 * 2)),
    ]
}

#Preview("Small", as: .systemSmall) {
    TuduWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todos: SampleData.todos, config: TuduWidgetConfigIntent(), syncFailed: false)
}

#Preview("Medium", as: .systemMedium) {
    TuduWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todos: SampleData.todos, config: TuduWidgetConfigIntent(), syncFailed: false)
}

#Preview("Large", as: .systemLarge) {
    TuduWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todos: SampleData.todos, config: TuduWidgetConfigIntent(), syncFailed: false)
}
