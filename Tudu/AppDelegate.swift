import AppKit
import Combine
import SwiftUI

/// Owns the menu bar status item and keeps it in sync with user preferences.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        observePreferences()
        syncMenuBarItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay alive in the menu bar, unless the user turned it off.
        !AppPreferences.shared.showMenuBarIcon
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    // MARK: - Preferences

    private func observePreferences() {
        let prefs = AppPreferences.shared

        prefs.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.syncMenuBarItem() }
            }
            .store(in: &cancellables)

        prefs.$menuBarWidth
            .combineLatest(prefs.$menuBarHeight)
            .receive(on: RunLoop.main)
            .sink { [weak self] width, height in
                MainActor.assumeIsolated {
                    self?.popover?.contentSize = NSSize(width: width, height: height)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu bar item

    private func syncMenuBarItem() {
        if AppPreferences.shared.showMenuBarIcon {
            setupMenuBar()
        } else {
            teardownMenuBar()
        }
    }

    private func setupMenuBar() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Tudu")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(
            width: AppPreferences.shared.menuBarWidth,
            height: AppPreferences.shared.menuBarHeight
        )
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(onOpenApp: { [weak self] in self?.showMainWindow() })
        )
        self.popover = popover
    }

    private func teardownMenuBar() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        popover = nil
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Main window

    func showMainWindow() {
        popover?.performClose(nil)
        AppState.shared.showMainWindow()
    }
}
