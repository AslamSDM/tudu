//
//  TuduWidget.swift
//  TuduWidget
//
//  Created by Aslam on 11/12/25.
//

import WidgetKit
import SwiftUI

struct TodoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(date: Date(), todos: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let todos = SharedTodoData.loadTodos()
        let entry = TodoWidgetEntry(date: Date(), todos: todos)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let currentDate = Date()
        let todos = SharedTodoData.loadTodos()
        let entry = TodoWidgetEntry(date: currentDate, todos: todos)

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [Todo]
}

struct TodoWidgetEntryView: View {
    var entry: TodoWidgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// Small Widget View
struct SmallWidgetView: View {
    let entry: TodoWidgetEntry

    var pendingTodos: [Todo] {
        entry.todos.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Tudu")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Divider()

            if entry.todos.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("No tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Stats
                HStack(spacing: 4) {
                    Text("\(pendingTodos.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Next task
                if let nextTask = pendingTodos.first {
                    Text(nextTask.title)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                }

                Spacer()
            }
        }
        .padding()
    }
}

// Medium Widget View
struct MediumWidgetView: View {
    let entry: TodoWidgetEntry

    var pendingTodos: [Todo] {
        entry.todos.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Tudu")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()

                // Stats badge
                HStack(spacing: 4) {
                    Text("\(pendingTodos.count)")
                        .fontWeight(.semibold)
                    Text("/")
                        .foregroundColor(.secondary)
                    Text("\(entry.todos.count)")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            if entry.todos.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("No tasks yet!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.todos.prefix(4)) { todo in
                        HStack(spacing: 8) {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundColor(todo.isCompleted ? .green : .blue)

                            Text(todo.title)
                                .font(.caption)
                                .strikethrough(todo.isCompleted)
                                .foregroundColor(todo.isCompleted ? .secondary : .primary)
                                .lineLimit(1)

                            Spacer()
                        }
                    }

                    if entry.todos.count > 4 {
                        Text("+\(entry.todos.count - 4) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// Large Widget View
struct LargeWidgetView: View {
    let entry: TodoWidgetEntry

    var pendingTodos: [Todo] {
        entry.todos.filter { !$0.isCompleted }
    }

    var completedTodos: [Todo] {
        entry.todos.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Tudu")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Stats Row
            HStack(spacing: 12) {
                StatBadge(title: "Total", value: entry.todos.count, color: .blue)
                StatBadge(title: "Pending", value: pendingTodos.count, color: .orange)
                StatBadge(title: "Done", value: completedTodos.count, color: .green)
            }

            Divider()

            if entry.todos.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No tasks yet!")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Pending tasks
                        if !pendingTodos.isEmpty {
                            Text("Pending")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.top, 4)

                            ForEach(pendingTodos.prefix(6)) { todo in
                                TodoWidgetRow(todo: todo)
                            }
                        }

                        // Completed tasks
                        if !completedTodos.isEmpty && pendingTodos.count < 6 {
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.top, 8)

                            ForEach(completedTodos.prefix(3)) { todo in
                                TodoWidgetRow(todo: todo)
                            }
                        }

                        if entry.todos.count > 9 {
                            Text("+\(entry.todos.count - 9) more tasks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// Helper Views
struct StatBadge: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TodoWidgetRow: View {
    let todo: Todo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(todo.isCompleted ? .green : .blue)

            Text(todo.title)
                .font(.caption)
                .strikethrough(todo.isCompleted)
                .foregroundColor(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct TuduWidget: Widget {
    let kind: String = "TuduWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tudu")
        .description("Keep track of your tasks at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TuduWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Small Widget - Empty
            TodoWidgetEntryView(entry: TodoWidgetEntry(
                date: .now,
                todos: []
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Empty")

            // Small Widget - With tasks
            TodoWidgetEntryView(entry: TodoWidgetEntry(
                date: .now,
                todos: [
                    Todo(title: "Buy groceries", isCompleted: false),
                    Todo(title: "Finish project report", isCompleted: false),
                    Todo(title: "Call mom", isCompleted: true)
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - With Tasks")

            // Medium Widget
            TodoWidgetEntryView(entry: TodoWidgetEntry(
                date: .now,
                todos: [
                    Todo(title: "Buy groceries", isCompleted: false),
                    Todo(title: "Finish project report", isCompleted: false),
                    Todo(title: "Call mom", isCompleted: true),
                    Todo(title: "Review pull requests", isCompleted: false),
                    Todo(title: "Team meeting at 3 PM", isCompleted: false)
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium Widget")

            // Large Widget
            TodoWidgetEntryView(entry: TodoWidgetEntry(
                date: .now,
                todos: [
                    Todo(title: "Buy groceries", isCompleted: false),
                    Todo(title: "Finish project report", isCompleted: false),
                    Todo(title: "Call mom", isCompleted: true),
                    Todo(title: "Review pull requests", isCompleted: false),
                    Todo(title: "Team meeting at 3 PM", isCompleted: false),
                    Todo(title: "Update documentation", isCompleted: false),
                    Todo(title: "Fix bug in login flow", isCompleted: true),
                    Todo(title: "Plan sprint retrospective", isCompleted: false)
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large Widget")
        }
    }
}
