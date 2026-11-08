import AppIntents
import WidgetKit

/// Toggles a task's completion state directly from a widget, then pushes the
/// change to the sync server so other devices see it even when the app is
/// not running.
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
            if SyncConfig.isEnabled {
                _ = try? await SyncClient.sync(timeout: 8)
            }
        }
        return .result()
    }
}
