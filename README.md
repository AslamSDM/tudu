# Tudu — A Todo App with Widgets for macOS

A native macOS todo app built with SwiftUI, with a Home Screen / Notification
Center widget, a menu bar popover, and data shared between the app and the
widget through an App Group.

## Features

- **Native SwiftUI app** — sidebar-free, focused task list with a progress ring
  and at-a-glance stats.
- **Widgets** — small, medium, and large widgets that show your pending and
  completed tasks. Tap a checkbox right in the widget to complete a task
  (interactive App Intent).
- **Menu bar access** — a compact popover for quick capture without leaving
  whatever you are doing.
- **Rich tasks** — notes, priority (low / medium / high), due dates, and tags,
  with overdue and due-today highlighting.
- **Tags** — label tasks and filter the list by tag; tags are searchable too.
- **Search, filter, and sort** — search by title, notes, or tag; filter by
  All / Active / Completed; sort by newest, due date, priority, or A–Z.
- **Due-date notifications** — optional local notifications when a task with a
  due date becomes due.
- **Import / export** — back up your tasks to JSON and merge them back in.
- **Editing** — double-click a row (or use the context menu) to edit notes,
  priority, due date, and tags in a dedicated editor sheet.
- **Keyboard friendly** — `⌘N` for a new task, `⌘⇧N` for a new task with
  details, `⌘F` to search, plus standard menu commands.
- **Data persistence** — tasks are stored as JSON in an App Group so the app and
  widget stay in sync, with one-time migration from older storage locations.

## Sync (Mac ⇄ Android)

Tudu syncs through a small Cloudflare Worker (`worker/`), with one SQLite
Durable Object for each sync space. You do not need an account. A secret **sync
key** links your devices.

1. On the Mac, open **Settings → Sync** and click **Create a new sync key**.
2. In Tudu for Android (`android/`), open **Settings → Sync**. Scan the QR code
   shown on the Mac, or paste the key.
3. Changes sync after each edit, every minute while the app runs, and when the
   widget refreshes. Widget check-offs sync even when the app is closed.

Conflicts resolve per task: the most recent edit wins. Deleted tasks are kept
as tombstones, so the delete reaches every device. The API is documented in
[`docs/SYNC_API.md`](docs/SYNC_API.md).

**Keep the key private.** Anyone with the key can read and change your tasks.

### Deploying your own Worker

```bash
cd worker
npm install
npm test             # vitest + workerd
npx wrangler deploy  # prints https://tudu-sync.<you>.workers.dev
```

Then set the server URL in the Settings of each app.

### Quick add shortcuts

Type these in a quick-add field on the Mac (main window or menu bar):
`#tag`, `!high` / `!low`, `@today`, `@tomorrow`, `@fri`, `@next week`.
For example: `Pay rent #home !high @fri`.

## Screenshots

[Add screenshots of the app and widgets here]

## Installation

### Using Homebrew (Recommended)

```bash
brew tap AslamSDM/tudu
brew install --cask tudu
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/AslamSDM/tudu/releases)
2. Unzip the downloaded file
3. Move `Tudu.app` to your Applications folder
4. Open Tudu from Applications

## Widget Setup

1. Run the Tudu app and add some todos
2. Open **Notification Center** (click the time in the menu bar)
3. Scroll to the bottom and click **Edit Widgets**
4. Search for "Tudu"
5. Drag the widget to the position you want
6. Choose a size (Small, Medium, or Large)

## Building from Source

### Prerequisites

- macOS 26.1 or later
- Xcode 27.0 or later
- Command Line Tools

### Build Steps

```bash
# Clone the repository
git clone https://github.com/AslamSDM/tudu.git
cd tudu

# Open in Xcode
open Tudu.xcodeproj

# Or build from the command line
./build_release.sh 1.0.0
```

## Project Structure

```
Tudu/
├── Tudu/                          # Main app target
│   ├── TuduApp.swift              # App entry point and scenes
│   ├── AppDelegate.swift          # Menu bar status item + preferences
│   ├── AppState.swift             # Deep-link handling, window management
│   ├── AppPreferences.swift       # User preferences (UserDefaults)
│   ├── ContentView.swift          # Main window UI
│   ├── TodoEditorView.swift       # Add / edit task sheet
│   ├── TagViews.swift             # Tag chips, flow layout, tag editor
│   ├── ImportExport.swift         # JSON import / export document
│   ├── NotificationManager.swift  # Due-date local notifications
│   ├── SettingsView.swift         # Preferences window
│   ├── MenuBarView.swift          # Menu bar popover
│   ├── TodoStore.swift            # App state and CRUD
│   ├── SharedModels.swift         # Shared model, storage, migration
│   ├── Info.plist                 # App Info.plist (URL scheme)
│   └── Assets.xcassets/           # App icon and accent color
├── TuduWidget/                    # Widget extension target
│   ├── TuduWidget.swift           # Widget views and timeline
│   ├── AppIntent.swift            # Toggle-completion App Intent
│   └── TuduWidgetBundle.swift     # Widget bundle
├── Config/
│   ├── Tudu.entitlements          # App Group + sandbox (app)
│   └── TuduWidget.entitlements    # App Group + sandbox (widget)
├── ICON_INTEGRATION.md            # Guide for adding a custom app icon
├── HOMEBREW_PUBLISHING.md         # Guide for publishing to Homebrew
├── SETUP_WIDGET.md                # Widget setup instructions
└── build_release.sh               # Release build script
```

## Development

### Widget Sizes

- **Small widget** — pending task count and the next task
- **Medium widget** — up to 4 tasks with completion status
- **Large widget** — up to 9 tasks, grouped by pending/completed

Checkboxes in the medium and large widgets are interactive: tapping one
completes (or reopens) that task through an App Intent, and the app picks up the
change the next time it becomes active.

### App Groups

The app and widget share data through an App Group:

```
group.com.Tudu
```

The identifier is defined once in `Tudu/SharedModels.swift`
(`SharedTodoData.suiteName`) and must match the `application-groups`
entitlement in both `Config/Tudu.entitlements` and
`Config/TuduWidget.entitlements`. If you change the App Group, update all three
places.

On first launch the app migrates tasks from the previous App Group
(`group.com.example.todowidget`) and from standard `UserDefaults`, so upgrading
does not lose your list.

## Requirements

- macOS 26.1+
- ~10 MB disk space

## Contributing

Contributions are welcome. Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

[Choose your license - MIT, Apache 2.0, etc.]

## Acknowledgments

- Built with SwiftUI and WidgetKit
- Icons from SF Symbols

## Support

If you encounter any issues or have questions:

- Open an issue on [GitHub Issues](https://github.com/AslamSDM/tudu/issues)
- Check the documentation guides in the repository

## Roadmap

- [ ] iCloud sync
- [ ] Recurring tasks
- [ ] Notifications with custom lead times
- [ ] Per-task reminders

---

**Made with ❤️ for macOS**
