import SwiftUI

/// Sheet for creating a task or editing an existing one's title, priority, due
/// date and notes.
struct TodoEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var tags: [String]

    private let original: Todo
    private let isNew: Bool
    private let onSave: (Todo) -> Void
    private let onDelete: (() -> Void)?

    init(todo: Todo, onSave: @escaping (Todo) -> Void, onDelete: (() -> Void)? = nil) {
        original = todo
        isNew = false
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
        _priority = State(initialValue: todo.priority)
        _hasDueDate = State(initialValue: todo.dueDate != nil)
        _dueDate = State(initialValue: todo.dueDate ?? Date())
        _tags = State(initialValue: todo.tags)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    /// Creates a brand-new task with full details.
    init(onSave: @escaping (Todo) -> Void) {
        original = Todo(title: "")
        isNew = true
        _title = State(initialValue: "")
        _notes = State(initialValue: "")
        _priority = State(initialValue: .medium)
        _hasDueDate = State(initialValue: false)
        _dueDate = State(initialValue: Date())
        _tags = State(initialValue: [])
        self.onSave = onSave
        self.onDelete = nil
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Task" : "Edit Task")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                TextField("Title", text: $title, prompt: Text("What needs to be done?"))

                Picker("Priority", selection: $priority) {
                    ForEach(TodoPriority.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Due date", isOn: $hasDueDate)

                if hasDueDate {
                    DatePicker(
                        "Due",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 90)
                }

                Section("Tags") {
                    TagEditor(tags: $tags)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isNew ? "Add" : "Save") {
                    onSave(editedTodo)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedTitle.isEmpty)
                .help(isNew ? "Add this task" : "Save changes")
            }
            .padding()
        }
        .frame(width: 440, height: 560)
    }

    private var editedTodo: Todo {
        var updated = original
        updated.title = trimmedTitle
        updated.notes = notes
        updated.priority = priority
        updated.dueDate = hasDueDate ? dueDate : nil
        updated.tags = Todo.normalize(tags: tags)
        return updated
    }
}
