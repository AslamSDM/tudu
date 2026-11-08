# Tudu — A Todo App for Mac and Android

A native macOS todo app built with SwiftUI, with desktop and Notification Center
widgets and a menu bar popover, plus a native Android app. Your tasks sync
between devices through a small Cloudflare Worker.

## Features

### macOS

- **Sidebar lists** — Today, Upcoming (grouped by day), All Tasks, Completed, and
  one list for each tag, with counts and sync status.
- **Quick add shortcuts** — type `Pay rent #home !high @fri` and Tudu sets the
  tag, priority, and deadline. Chips show what was recognized before you press
  Return. See [Quick add shortcuts](#quick-add-shortcuts).
- **Widgets** — small, medium, large, and extra-large. Edit a widget to choose
  All Tasks, Today, or High Priority, and whether completed tasks appear. Tick a
  task right in the widget. Widgets sync even when the app is closed.
- **Menu bar** — a popover with Today and All tabs, quick add, overdue tasks
  first, and recently completed tasks. It can show the pending count next to
  the icon.
- **Rich tasks** — notes, priority (low / medium / high), due dates, and tags,
  with overdue and due-today highlighting.
- **Search and sort** — search by title, notes, or tag; sort by newest, due date,
  priority, or A–Z.
- **Due-date notifications** — optional local notifications when a task becomes
  due.
- **Import / export** — back up your tasks to JSON and merge them back in.
- **Editing** — double-click a row (or use the context menu) to edit notes,
  priority, due date, and tags.
- **Keyboard friendly** — `⌘N` for a new task, `⌘⇧N` for a new task with
  details, `⌘F` to search, plus standard menu commands.
- **Local storage** — tasks are stored as JSON in an App Group shared by the app
  and the widget, with one-time migration from older storage locations.

### Android

- **Task list** — All / Active / Completed filters, tag filters, search, sort, and
  pull to refresh.
- **Quick add with visual cues** — shortcuts are highlighted as you type, preview
  chips show the result, and suggestion chips add a date, priority, or tag with
  one tap.
- **Gestures** — swipe to complete or delete, with undo.
- **Priority cues** — a colored edge on high and low priority tasks, and orange
  labels for tasks that are overdue or due today.
- **Home-screen widget** — pending tasks, tick to complete, and a **+** button that
  opens quick add.

See [`android/README.md`](android/README.md) for details.

## Sync (Mac ⇄ Android)

Tudu syncs through a small Cloudflare Worker (`worker/`), with one SQLite
Durable Object for each sync space. You do not need an account. A secret **sync
key** links your devices.

1. On the Mac, open **Settings → Sync** and click **Create a new sync key**, then
   **Show QR**.
2. In Tudu for Android, open **⋮ → Settings & sync**. Scan the QR code shown on
   the Mac, or paste the key.
3. The Mac syncs after each edit, every minute while the app runs, and when a
   widget refreshes. Widget check-offs sync even when the app is closed. Android
   syncs after each edit, when the app opens, and about every 15 minutes in the
   background.

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

Type these anywhere in a quick-add field (main window, menu bar, or Android).
They are not case-sensitive.

| Want | Type |
| --- | --- |
| High priority | `!high`, `!h`, `!!`, `!3`, `!urgent` |
| Low priority | `!low`, `!l`, `!1` |
| Medium priority (default) | `!med`, `!medium`, `!2` |
| Due today | `@today`, `@tod` |
| Due tomorrow | `@tomorrow`, `@tom`, `@tmr` |
| Due on a weekday | `@mon` … `@sun`, or the full day name |
| Due in 7 days | `@next week` |
| Tag | `#home` |

- Deadlines are set to 5 PM. If 5 PM has already passed today, `@today` means
  11:59 PM.
- A weekday means its next occurrence, so `@fri` typed on a Friday is next Friday.
- Exact dates and times such as `@dec12` or `@3pm` are not supported. They stay in
  the title. Use the task editor instead.
- With a tag list or tag filter selected, new tasks get that tag. On the Mac, new
  tasks in Today are due today unless you type another date.

## Screenshots

[Add screenshots of the app and widgets here]

## Installation

> Sync, the redesigned UI, and the Android app are newer than every published
> release. To get them now, [build from source](#building-from-source).

### Using Homebrew

```bash
brew tap AslamSDM/tudu
brew install --cask tudu
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/AslamSDM/tudu/releases)
2. Unzip the downloaded file
3. Move `Tudu.app` to your Applications folder
4. Open Tudu from Applications

### Android

No APK is published yet. Build it and install it with `adb`, as described in
[`android/README.md`](android/README.md).

## Widget Setup

1. Run the Tudu app and add some todos
2. Right-click the desktop and choose **Edit Widgets**, or open **Notification
   Center** and click **Edit Widgets**
3. Search for "Tudu"
4. Drag the widget to the position you want and choose a size
5. To choose which tasks it shows, right-click the widget and choose **Edit "Tudu"**

If you used a widget from an older build, remove it and add it again.

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

The app and widget share an App Group, so sign both with an Apple Development
certificate from the team in the group name (see [App Groups](#app-groups)). An
ad-hoc build runs, but macOS blocks its widget from reading your tasks, so the
widget stays empty.

The other two parts build on their own:

- Android: [`android/README.md`](android/README.md) (JDK 17+ and Android SDK 36)
- Worker: [Deploying your own Worker](#deploying-your-own-worker) (Node.js)

## Project Structure

```
Tudu/
├── Tudu/                          # Main app target
│   ├── TuduApp.swift              # App entry point and scenes
│   ├── AppDelegate.swift          # Menu bar status item + preferences
│   ├── AppState.swift             # Deep-link handling, window management
│   ├── AppPreferences.swift       # User preferences (UserDefaults)
│   ├── ContentView.swift          # Main window: sidebar, list, rows
│   ├── Components.swift           # Quick add field, badges, sync status
│   ├── TodoEditorView.swift       # Add / edit task sheet
│   ├── TagViews.swift             # Tag chips, flow layout, tag editor
│   ├── ImportExport.swift         # JSON import / export document
│   ├── NotificationManager.swift  # Due-date local notifications
│   ├── SettingsView.swift         # Preferences and sync pairing
│   ├── MenuBarView.swift          # Menu bar popover
│   ├── TodoStore.swift            # App state and CRUD
│   ├── SyncEngine.swift           # When to sync, status for the UI
│   ├── SyncClient.swift           # Sync protocol (shared with the widget)
│   ├── SharedModels.swift         # Model, storage, quick add parser (shared)
│   ├── Info.plist                 # App Info.plist (URL scheme)
│   └── Assets.xcassets/           # App icon and accent color
├── TuduWidget/                    # Widget extension target
│   ├── TuduWidget.swift           # Widget views and timeline
│   ├── AppIntent.swift            # Toggle-completion App Intent
│   └── TuduWidgetBundle.swift     # Widget bundle
├── Config/
│   ├── Tudu.entitlements          # App Group + sandbox (app)
│   └── TuduWidget.entitlements    # App Group + sandbox (widget)
├── worker/                        # Cloudflare Worker sync backend
├── android/                       # Android app and widget
├── docs/
│   ├── SYNC_API.md                # Sync protocol
│   └── index.html                 # Landing page
├── ICON_INTEGRATION.md            # Guide for adding a custom app icon
├── HOMEBREW_PUBLISHING.md         # Guide for publishing to Homebrew
├── SETUP_WIDGET.md                # Widget setup instructions
└── build_release.sh               # Release build script
```

## Development

### Widget Sizes

- **Small** — pending count, progress ring, and the next task
- **Medium** — pending count and up to 4 tasks
- **Large** — task stats and up to 8 tasks
- **Extra large** — task stats and up to 18 tasks in two columns

Checkboxes are interactive in every size: tapping one completes (or reopens) that
task through an App Intent. A running app picks up the change immediately through
a Darwin notification.

### Shared code

`Tudu/SharedModels.swift` and `Tudu/SyncClient.swift` belong to both the app and
widget targets. The quick add rules exist twice, in `SharedModels.swift` and
`android/.../domain/QuickAddParser.kt`, so change them together.

### App Groups

The app and widget share data through an App Group:

```
545VUAAWM7.group.com.Tudu
```

The Team ID prefix lets macOS verify the group from the code signature alone, with
no provisioning profile. **If you build under another team, replace `545VUAAWM7`
with your Team ID.**

The identifier is defined once in `Tudu/SharedModels.swift`
(`SharedTodoData.suiteName`) and must match the `application-groups`
entitlement in both `Config/Tudu.entitlements` and
`Config/TuduWidget.entitlements`. If you change the App Group, update all three
places.

On first launch the app migrates tasks from the previous App Group
(`group.com.example.todowidget`) and from standard `UserDefaults`, so upgrading
does not lose your list. It also copies tasks and sync settings from the older
unprefixed `group.com.Tudu`. Only the app's entitlements still list that group,
and only for this copy.

## Requirements

- macOS 26.1+
- ~10 MB disk space
- Android 8.0+ (API 26) for the Android app

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

- [x] Sync between devices (Cloudflare Worker)
- [ ] Recurring tasks
- [ ] Notifications with custom lead times
- [ ] Per-task reminders

---

**Made with ❤️ for Mac and Android**
