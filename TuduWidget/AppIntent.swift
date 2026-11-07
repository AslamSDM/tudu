import AppIntents
import WidgetKit

/// Toggles a task's completion state directly from a widget.
struct ToggleTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    static var description = IntentDescription("Mark a task as done or not done.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID) {
            SharedTodoData.toggle(id: id)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
