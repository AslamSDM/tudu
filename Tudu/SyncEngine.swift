import Foundation
import Combine
import AppKit
import WidgetKit

/// Drives `SyncClient` from the app: after local edits (debounced), on a
/// timer, and when the app becomes active. Publishes status for the UI.
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    enum Status: Equatable {
        case off
        case idle
        case syncing
        case failed(String)
    }

    @Published private(set) var status: Status = .off
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var isConfigured = false

    private var debounce: Task<Void, Never>?
    private var timer: Timer?
    private var inFlight = false
    private var rerunRequested = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        refreshConfiguration()

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.syncNow() } }
            .store(in: &cancellables)

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func start() {
        SharedTodoData.purgeTombstones()
        syncNow()
    }

    private func refreshConfiguration() {
        isConfigured = SyncConfig.isEnabled
        lastSuccess = SyncConfig.lastSuccess
        if !isConfigured {
            status = .off
        } else if let error = SyncConfig.lastError {
            status = .failed(error)
        } else if status == .off {
            status = .idle
        }
    }

    /// Coalesces bursts of edits into one request.
    func scheduleSync(after delay: TimeInterval = 1.0) {
        guard SyncConfig.isEnabled else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.syncNow()
        }
    }

    func syncNow() {
        guard SyncConfig.isEnabled else {
            refreshConfiguration()
            return
        }
        guard !inFlight else {
            rerunRequested = true
            return
        }
        inFlight = true
        status = .syncing

        Task {
            do {
                let outcome = try await SyncClient.sync()
                if outcome.applied > 0 {
                    TodoStore.shared.reload()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                status = .idle
            } catch {
                status = .failed(error.localizedDescription)
            }
            lastSuccess = SyncConfig.lastSuccess
            inFlight = false
            if rerunRequested {
                rerunRequested = false
                syncNow()
            }
        }
    }

    // MARK: Setup

    func createSpace() {
        connect(key: SyncConfig.generateKey(), serverURL: SyncConfig.serverURL)
    }

    func connect(key: String, serverURL: URL) {
        SyncConfig.connect(key: key, serverURL: serverURL)
        refreshConfiguration()
        status = .idle
        syncNow()
    }

    func disconnect() {
        debounce?.cancel()
        SyncConfig.disconnect()
        refreshConfiguration()
    }
}
