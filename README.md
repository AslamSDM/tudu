# Tudu - Beautiful Todo App with Widget for macOS

A native macOS todo application with widget support, featuring a clean interface, menu bar integration, and data persistence.

## Features

- ✅ **Native macOS App** - Built with SwiftUI
- 📱 **Widget Support** - Small, Medium, and Large widgets for Notification Center
- 🎯 **Menu Bar Integration** - Quick access from the menu bar
- 💾 **Data Persistence** - Your todos are saved using App Groups
- 🎨 **Beautiful UI** - Modern, clean interface with statistics
- 🔄 **Real-time Sync** - Widget updates automatically when you add/edit todos

## Screenshots

[Add screenshots of your app and widgets here]

## Installation

### Using Homebrew (Recommended)

```bash
brew tap YOUR_USERNAME/tudu
brew install --cask tudu
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/YOUR_USERNAME/tudu/releases)
2. Unzip the downloaded file
3. Move `Tudu.app` to your Applications folder
4. Open Tudu from Applications

## Widget Setup

1. Run the Tudu app and add some todos
2. Open **Notification Center** (click time in menu bar)
3. Scroll to bottom and click **Edit Widgets**
4. Search for "Tudu"
5. Drag the widget to your desired location
6. Choose your preferred size (Small, Medium, or Large)

## Building from Source

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Command Line Tools

### Build Steps

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/tudu.git
cd tudu

# Open in Xcode
open Tudu.xcodeproj

# Or build from command line
./build_release.sh 1.0.0
```

## Project Structure

```
Tudu/
├── Tudu/
│   ├── TuduApp.swift          # Main app entry point
│   ├── SharedModels.swift     # Shared data models
│   └── Assets.xcassets/       # App icons and assets
├── TuduWidget/
│   ├── TuduWidget.swift       # Widget implementation
│   └── TuduWidgetBundle.swift # Widget bundle
├── ICON_INTEGRATION.md        # Guide for adding custom icons
├── HOMEBREW_PUBLISHING.md     # Guide for publishing to Homebrew
├── SETUP_WIDGET.md           # Widget setup instructions
└── build_release.sh          # Release build script
```

## Documentation

- **[Icon Integration Guide](ICON_INTEGRATION.md)** - How to add your custom app icon
- **[Widget Setup Guide](SETUP_WIDGET.md)** - Setting up the widget extension
- **[Homebrew Publishing Guide](HOMEBREW_PUBLISHING.md)** - Publishing your app to Homebrew

## Development

### Widget Sizes

- **Small Widget**: Shows pending task count and next task
- **Medium Widget**: Displays up to 4 tasks with completion status
- **Large Widget**: Shows up to 9 tasks, separated by pending/completed

### App Groups

The app uses App Groups to share data between the main app and widget:
```
group.com.example.todowidget
```

Make sure to configure this in both targets (Tudu and TuduWidgetExtension).

## Requirements

- macOS 14.0+
- 10 MB disk space

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

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

- Open an issue on [GitHub Issues](https://github.com/YOUR_USERNAME/tudu/issues)
- Check the documentation guides in the repository

## Roadmap

- [ ] iCloud sync
- [ ] Categories and tags
- [ ] Reminders and notifications
- [ ] Dark mode support
- [ ] Keyboard shortcuts
- [ ] Export/Import todos

---

**Made with ❤️ for macOS**
