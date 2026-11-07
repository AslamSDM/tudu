import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct TodoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(date: Date(), todos: SampleData.todos)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let todos = context.isPreview ? SampleData.todos : SharedTodoData.loadTodos()
        completion(TodoWidgetEntry(date: Date(), todos: todos))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let entry = TodoWidgetEntry(date: Date(), todos: SharedTodoData.loadTodos())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [Todo]
}

// MARK: - Entry view

struct TodoWidgetEntryView: View {
    var entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .systemExtraLarge, .systemExtraLargePortrait:
                LargeWidgetView(entry: entry)
            @unknown default:
                SmallWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "tudu://open"))
    }
}

// MARK: - Small

struct SmallWidgetView: View {
    let entry: TodoWidgetEntry

    private var pending: [Todo] { entry.todos.filter { !$0.isCompleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(pendingCount: pending.count, total: entry.todos.count)

            Divider()

            if entry.todos.isEmpty {
                WidgetEmptyState(message: "No tasks")
            } else if pending.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("All done!")
                        .font(.headline)
                    Text("\(entry.todos.count) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(pending.count)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let next = pending.first {
                    HStack(alignment: .top, spacing: 6) {
                        ToggleTodoButton(todo: next)
                        Text(next.displayTitle)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Medium

struct MediumWidgetView: View {
    let entry: TodoWidgetEntry

    private var pending: [Todo] { entry.todos.filter { !$0.isCompleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(pendingCount: pending.count, total: entry.todos.count)

            Divider()

            if entry.todos.isEmpty {
                WidgetEmptyState(message: "No tasks yet!")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.todos.prefix(4)) { todo in
                        TodoWidgetRow(todo: todo)
                    }

                    if entry.todos.count > 4 {
                        Text("+\(entry.todos.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 22)
                    }
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Large

struct LargeWidgetView: View {
    let entry: TodoWidgetEntry

    private var pending: [Todo] { entry.todos.filter { !$0.isCompleted } }
    private var completed: [Todo] { entry.todos.filter(\.isCompleted) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(pendingCount: pending.count, total: entry.todos.count)

            HStack(spacing: 8) {
                StatBadge(title: "Total", value: entry.todos.count, color: .blue)
                StatBadge(title: "Pending", value: pending.count, color: .orange)
                StatBadge(title: "Done", value: completed.count, color: .green)
            }

            Divider()

            if entry.todos.isEmpty {
                WidgetEmptyState(message: "No tasks yet!")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !pending.isEmpty {
                            SectionLabel(title: "Pending", color: .orange)
                            ForEach(pending.prefix(7)) { todo in
                                TodoWidgetRow(todo: todo)
                            }
                        }

                        if !completed.isEmpty {
                            SectionLabel(title: "Completed", color: .green)
                                .padding(.top, pending.isEmpty ? 0 : 4)
                            ForEach(completed.prefix(pending.isEmpty ? 8 : 3)) { todo in
                                TodoWidgetRow(todo: todo)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Components

struct WidgetHeader: View {
    let pendingCount: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .foregroundStyle(.blue)
            Text("Tudu")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Link(destination: URL(string: "tudu://add")!) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
            .help("Add a task")
        }
    }
}

struct TodoWidgetRow: View {
    let todo: Todo

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ToggleTodoButton(todo: todo)

            VStack(alignment: .leading, spacing: 1) {
                Text(todo.displayTitle)
                    .font(.caption)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                if let dueDate = todo.dueDate, !todo.isCompleted {
                    Text(dueText(dueDate))
                        .font(.caption2)
                        .foregroundStyle(todo.isOverdue ? .orange : .secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    private func dueText(_ date: Date) -> String {
        if todo.isOverdue { return "Overdue" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Due today" }
        if calendar.isDateInTomorrow(date) { return "Due tomorrow" }
        return "Due \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

struct ToggleTodoButton: View {
    let todo: Todo

    var body: some View {
        Button(intent: ToggleTodoIntent(taskID: todo.id.uuidString)) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(checkboxColor)
        }
        .buttonStyle(.plain)
    }

    private var checkboxColor: Color {
        if todo.isCompleted { return .green }
        return todo.isOverdue ? .orange : .blue
    }
}

struct StatBadge: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }
}

struct SectionLabel: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
    }
}

struct WidgetEmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundStyle(.green)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct TuduWidget: Widget {
    let kind: String = "TuduWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tudu")
        .description("Keep track of your tasks at a glance, and tick them off right from the widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview data

private enum SampleData {
    static let todos: [Todo] = [
        Todo(title: "Buy groceries", priority: .high, dueDate: Date().addingTimeInterval(3600)),
        Todo(title: "Finish project report", priority: .high),
        Todo(title: "Review pull requests", priority: .low),
        Todo(title: "Call mom", isCompleted: true, completedAt: Date()),
        Todo(title: "Plan sprint retrospective"),
    ]
}

#Preview("Small", as: .systemSmall) {
    TuduWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todos: SampleData.todos)
}

#Preview("Medium", as: .systemMedium) {
    TuduWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todos: SampleData.todos)
}

#Preview("Large", as: .systemLarge) {
    TuduWidget()
} timeline: {
    TodoWidgetEntry(date: .now, todos: SampleData.todos)
}
