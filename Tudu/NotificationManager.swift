import Foundation
import UserNotifications

/// Schedules local notifications for tasks that have a due date.
///
/// Every mutating change re-syncs the pending notifications, so the schedule
/// always matches the current task list. Permission is only requested the first
/// time notifications are actually needed.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private var authorizationRequested = false

    private init() {}

    /// Asks the system for permission the first time it is needed. Safe to call
    /// repeatedly; the prompt is only shown once.
    func requestAuthorization() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Replaces all pending due-date notifications with the current tasks.
    func sync(todos: [Todo], enabled: Bool) {
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        requestAuthorization()

        let now = Date()
        for todo in todos where !todo.isCompleted {
            guard let due = todo.dueDate, due > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Task due"
            content.body = todo.displayTitle
            if !todo.tags.isEmpty {
                content.subtitle = todo.tags.joined(separator: ", ")
            }
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: todo.id.uuidString,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
