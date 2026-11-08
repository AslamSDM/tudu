import Foundation
import SwiftUI
import Combine

/// User-facing preferences. Changes are persisted immediately so they apply
/// live (e.g. toggling the menu bar icon does not require a relaunch).
@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @Published var showMenuBarIcon: Bool {
        didSet { save() }
    }

    @Published var menuBarWidth: Double {
        didSet { save() }
    }

    @Published var menuBarHeight: Double {
        didSet { save() }
    }

    @Published var menuBarShowsCount: Bool {
        didSet { save() }
    }

    @Published var confirmBeforeDeleting: Bool {
        didSet { save() }
    }

    @Published var dueDateNotifications: Bool {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let menuBarWidth = "menuBarWidth"
        static let menuBarHeight = "menuBarHeight"
        static let confirmBeforeDeleting = "confirmBeforeDeleting"
        static let menuBarShowsCount = "menuBarShowsCount"
        static let dueDateNotifications = "dueDateNotifications"
    }

    private init() {
        // Property observers do not fire during initialization, so assigning
        // here loads the saved values without immediately re-saving them.
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        menuBarWidth = defaults.object(forKey: Key.menuBarWidth) as? Double ?? 360
        menuBarHeight = defaults.object(forKey: Key.menuBarHeight) as? Double ?? 520
        menuBarShowsCount = defaults.object(forKey: Key.menuBarShowsCount) as? Bool ?? true
        confirmBeforeDeleting = defaults.object(forKey: Key.confirmBeforeDeleting) as? Bool ?? true
        dueDateNotifications = defaults.object(forKey: Key.dueDateNotifications) as? Bool ?? false
    }

    private func save() {
        defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
        defaults.set(menuBarWidth, forKey: Key.menuBarWidth)
        defaults.set(menuBarHeight, forKey: Key.menuBarHeight)
        defaults.set(confirmBeforeDeleting, forKey: Key.confirmBeforeDeleting)
        defaults.set(menuBarShowsCount, forKey: Key.menuBarShowsCount)
        defaults.set(dueDateNotifications, forKey: Key.dueDateNotifications)
    }
}
