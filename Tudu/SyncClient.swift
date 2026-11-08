import Foundation
import Security

// Shared by the app and the widget extension. Implements the client side of
// docs/SYNC_API.md.

// MARK: - Configuration

/// Sync settings, stored in the App Group so the widget can sync too.
public enum SyncConfig {
    public static let defaultServerURL = URL(string: "https://tudu-sync.aslamprpd.workers.dev")!

    private static let serverKey = "SyncServerURL"
    private static let syncKeyKey = "SyncKey"
    private static let cursorKey = "SyncCursor"
    private static let lastSyncKey = "SyncLastSuccess"
    private static let lastErrorKey = "SyncLastError"

    private static var defaults: UserDefaults { SharedTodoData.defaults }

    public static var serverURL: URL {
        get {
            defaults.string(forKey: serverKey).flatMap(URL.init(string:)) ?? defaultServerURL
        }
        set { defaults.set(newValue.absoluteString, forKey: serverKey) }
    }

    public static var syncKey: String? {
        get { defaults.string(forKey: syncKeyKey) }
        set { defaults.set(newValue, forKey: syncKeyKey) }
    }

    public static var isEnabled: Bool { syncKey.map(isValidKey) ?? false }

    static var cursor: Int64 {
        get { (defaults.object(forKey: cursorKey) as? NSNumber)?.int64Value ?? 0 }
        set { defaults.set(NSNumber(value: newValue), forKey: cursorKey) }
    }

    public static var lastSuccess: Date? {
        get { defaults.object(forKey: lastSyncKey) as? Date }
        set { defaults.set(newValue, forKey: lastSyncKey) }
    }

    public static var lastError: String? {
        get { defaults.string(forKey: lastErrorKey) }
        set { defaults.set(newValue, forKey: lastErrorKey) }
    }

    public static func isValidKey(_ key: String) -> Bool {
        key.range(of: "^[A-Za-z0-9_-]{32,128}$", options: .regularExpression) != nil
    }

    /// 32 random bytes, base64url without padding.
    public static func generateKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Connects to a space. Resets the cursor and queues every local task for
    /// upload so both sides end up with the union of their lists.
    public static func connect(key: String, serverURL: URL) {
        self.serverURL = serverURL
        syncKey = key
        cursor = 0
        lastError = nil
        SharedTodoData.markAllPending()
    }

    public static func disconnect() {
        syncKey = nil
        cursor = 0
        lastSuccess = nil
        lastError = nil
    }

    /// `tudu://sync?url=…&key=…`, used for the QR code and deep links.
    public static func pairingURL() -> URL? {
        guard let syncKey else { return nil }
        var components = URLComponents()
        components.scheme = "tudu"
        components.host = "sync"
        components.queryItems = [
            URLQueryItem(name: "url", value: serverURL.absoluteString),
            URLQueryItem(name: "key", value: syncKey),
        ]
        return components.url
    }

    public static func parsePairingURL(_ url: URL) -> (key: String, server: URL)? {
        guard url.scheme?.lowercased() == "tudu", url.host?.lowercased() == "sync",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let key = items.first(where: { $0.name == "key" })?.value, isValidKey(key)
        else { return nil }
        let server = items.first(where: { $0.name == "url" })?.value
            .flatMap(URL.init(string:)) ?? defaultServerURL
        return (key, server)
    }
}

// MARK: - Wire format

struct WireTodo: Codable, Equatable {
    var id: String
    var title: String
    var notes: String
    var isCompleted: Bool
    var priority: Int
    var dueDate: Int64?
    var tags: [String]
    var createdAt: Int64
    var updatedAt: Int64
    var completedAt: Int64?
    var deletedAt: Int64?

    init(_ todo: Todo) {
        id = todo.id.uuidString.lowercased()
        title = todo.title
        notes = todo.notes
        isCompleted = todo.isCompleted
        priority = todo.priority.rawValue
        dueDate = todo.dueDate?.unixMillis
        tags = todo.tags
        createdAt = todo.createdAt.unixMillis
        updatedAt = todo.updatedAt.unixMillis
        completedAt = todo.completedAt?.unixMillis
        deletedAt = todo.deletedAt?.unixMillis
    }

    var todo: Todo? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Todo(
            id: uuid,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            priority: TodoPriority(rawValue: priority) ?? .medium,
            dueDate: dueDate.map(Date.init(unixMillis:)),
            tags: tags,
            createdAt: Date(unixMillis: createdAt),
            updatedAt: Date(unixMillis: updatedAt),
            completedAt: completedAt.map(Date.init(unixMillis:)),
            deletedAt: deletedAt.map(Date.init(unixMillis:))
        )
    }

    // Encode optionals as explicit nulls, matching the API docs.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encode(priority, forKey: .priority)
        try c.encode(dueDate, forKey: .dueDate)
        try c.encode(tags, forKey: .tags)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

private struct SyncRequest: Encodable {
    let cursor: Int64
    let changes: [WireTodo]
}

private struct SyncResponse: Decodable {
    let cursor: Int64
    let changes: [WireTodo]
}

private struct ErrorResponse: Decodable {
    let error: String
}

// MARK: - Client

public struct SyncOutcome: Sendable {
    /// Number of local records that changed because of server data.
    public let applied: Int
    public let pushed: Int
}

public enum SyncError: LocalizedError {
    case notConfigured
    case server(status: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Sync is not set up."
        case .server(let status, let message):
            return status == 401 ? "The sync key was rejected." : "Server error (\(status)): \(message)"
        case .invalidResponse: return "The server sent an unexpected response."
        }
    }
}

public enum SyncClient {
    static let chunkSize = 500

    /// Pushes pending local changes, pulls remote ones, and merges them with
    /// last-write-wins. Safe to call from the app and the widget.
    @discardableResult
    public static func sync(timeout: TimeInterval = 20) async throws -> SyncOutcome {
        guard let key = SyncConfig.syncKey, SyncConfig.isValidKey(key) else {
            throw SyncError.notConfigured
        }

        do {
            var pushedTotal = 0
            var applied = 0
            var first = true

            // Each round pushes up to `chunkSize` pending records. The loop
            // ends once nothing is left to push (always at least one round,
            // so we also pull).
            while true {
                let records = SharedTodoData.loadRecords()
                let pending = SharedTodoData.pendingIDs()
                let batch = Array(records.filter { pending.contains($0.id) }.prefix(chunkSize))
                if !first && batch.isEmpty { break }
                first = false

                let response = try await send(
                    SyncRequest(cursor: SyncConfig.cursor, changes: batch.map(WireTodo.init)),
                    key: key,
                    timeout: timeout
                )
                applied += merge(response.changes, pushed: batch)
                SyncConfig.cursor = response.cursor
                pushedTotal += batch.count
                if batch.count < chunkSize { break }
            }

            SyncConfig.lastSuccess = Date()
            SyncConfig.lastError = nil
            return SyncOutcome(applied: applied, pushed: pushedTotal)
        } catch {
            SyncConfig.lastError = error.localizedDescription
            throw error
        }
    }

    private static func send(_ body: SyncRequest, key: String, timeout: TimeInterval) async throws -> SyncResponse {
        var request = URLRequest(url: SyncConfig.serverURL.appendingPathComponent("v1/sync"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error ?? "unknown"
            throw SyncError.server(status: http.statusCode, message: message)
        }
        guard let decoded = try? JSONDecoder().decode(SyncResponse.self, from: data) else {
            throw SyncError.invalidResponse
        }
        return decoded
    }

    /// Merges server records into a fresh copy of local storage. Returns how
    /// many local records changed.
    static func merge(_ remote: [WireTodo], pushed: [Todo]) -> Int {
        var applied = 0
        var replaced = Set<UUID>()
        var current: [UUID: Int64] = [:]

        SharedTodoData.updateRecords { records in
            var index = Dictionary(records.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
            for wire in remote {
                guard let incoming = wire.todo else { continue }
                if let i = index[incoming.id] {
                    if incoming.updatedAt.unixMillis > records[i].updatedAt.unixMillis {
                        records[i] = incoming
                        replaced.insert(incoming.id)
                        applied += 1
                    }
                } else {
                    index[incoming.id] = records.count
                    records.append(incoming)
                    applied += 1
                }
            }
            current = Dictionary(records.map { ($0.id, $0.updatedAt.unixMillis) }, uniquingKeysWith: { a, _ in a })
            return applied > 0
        }

        // Clear an id when the server now has exactly what we sent, or when a
        // newer server version replaced it. An id edited again while the
        // request was in flight stays pending.
        let done = pushed.filter { replaced.contains($0.id) || current[$0.id] == $0.updatedAt.unixMillis }
        SharedTodoData.clearPending(Set(done.map(\.id)))
        return applied
    }
}
