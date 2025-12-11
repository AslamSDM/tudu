import Foundation

// MARK: - Shared Data Model
public struct Todo: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public let createdAt: Date
    
    public init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
    
    // Convenience initializer for testing
    public init(id: UUID = UUID(), title: String, isCompleted: Bool, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

// MARK: - Shared Data Access
public class SharedTodoData {
    public static let suiteName = "group.com.example.todowidget"
    public static let saveKey = "SavedTodos"
    
    public static func loadTodos() -> [Todo] {
        let userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        
        if let data = userDefaults.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Todo].self, from: data) {
            return decoded
        }
        return []
    }
    
    public static func saveTodos(_ todos: [Todo]) {
        let userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(todos) {
            userDefaults.set(encoded, forKey: saveKey)
        }
    }
}