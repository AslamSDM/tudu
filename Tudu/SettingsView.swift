import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

/// The app's Settings window (⌘,). Values are persisted on change, so they
/// apply to the running app immediately.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            SyncSettingsView()
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath.icloud") }
        }
        .frame(width: 480)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show menu bar icon", isOn: $prefs.showMenuBarIcon)
                if prefs.showMenuBarIcon {
                    Toggle("Show task count next to the icon", isOn: $prefs.menuBarShowsCount)
                }
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Quickly add and complete tasks from anywhere.")
            }

            if prefs.showMenuBarIcon {
                Section {
                    LabeledSlider(title: "Width", value: $prefs.menuBarWidth, range: 320...600)
                    LabeledSlider(title: "Height", value: $prefs.menuBarHeight, range: 320...800)
                } header: {
                    Text("Popover Size")
                }
            }

            Section {
                Toggle("Confirm before clearing completed tasks", isOn: $prefs.confirmBeforeDeleting)
            } header: {
                Text("Tasks")
            } footer: {
                Text("Quick add shortcuts: #tag, !high / !low, @today, @tomorrow, @fri, @next week.")
            }

            Section {
                Toggle("Notify me about due dates", isOn: $prefs.dueDateNotifications)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Sends a notification when a task with a due date becomes due. macOS will ask for permission the first time.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 470)
        .onChange(of: prefs.dueDateNotifications) { _, enabled in
            if enabled { NotificationManager.shared.requestAuthorization() }
            NotificationManager.shared.sync(todos: TodoStore.shared.todos, enabled: enabled)
        }
    }
}

// MARK: - Sync

struct SyncSettingsView: View {
    @ObservedObject private var sync = SyncEngine.shared

    @State private var serverText = SyncConfig.serverURL.absoluteString
    @State private var joinKey = ""
    @State private var revealKey = false
    @State private var confirmDisconnect = false
    @State private var copied = false

    private var serverURL: URL? {
        guard let url = URL(string: serverText.trimmingCharacters(in: .whitespaces)),
              url.scheme == "https" || url.scheme == "http", url.host() != nil else { return nil }
        return url
    }

    var body: some View {
        Form {
            if sync.isConfigured {
                connectedSections
            } else {
                setupSections
            }
        }
        .formStyle(.grouped)
        .frame(height: 470)
        .confirmationDialog("Stop syncing this Mac?", isPresented: $confirmDisconnect) {
            Button("Disconnect", role: .destructive) { sync.disconnect() }
        } message: {
            Text("Your tasks stay on this Mac. Other devices keep syncing with each other.")
        }
    }

    // MARK: Not connected

    @ViewBuilder
    private var setupSections: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("Sync Tudu across your Mac and Android", systemImage: "arrow.triangle.2.circlepath.icloud.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text("Tasks sync through a Cloudflare Worker. A secret sync key links your devices — no account needed. Anyone with the key can read your tasks, so keep it private.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }

        Section("Start syncing") {
            Button {
                applyServer()
                sync.createSpace()
            } label: {
                Label("Create a new sync key", systemImage: "key.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(serverURL == nil)
        }

        Section("Or join an existing one") {
            HStack {
                SecureField("Paste a sync key", text: $joinKey)
                    .textFieldStyle(.roundedBorder)
                Button("Join") {
                    applyServer()
                    sync.connect(key: joinKey.trimmingCharacters(in: .whitespacesAndNewlines), serverURL: SyncConfig.serverURL)
                    joinKey = ""
                }
                .disabled(!SyncConfig.isValidKey(joinKey.trimmingCharacters(in: .whitespacesAndNewlines)) || serverURL == nil)
            }
        }

        serverSection
    }

    // MARK: Connected

    @ViewBuilder
    private var connectedSections: some View {
        Section {
            HStack {
                SyncStatusView()
                Spacer()
                Button("Sync Now") { sync.syncNow() }
                    .disabled(sync.status == .syncing)
            }
            if case .failed(let message) = sync.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Status")
        }

        Section {
            HStack(alignment: .top, spacing: 16) {
                if let url = SyncConfig.pairingURL(), let image = QRCode.image(for: url.absoluteString) {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 132, height: 132)
                        .padding(6)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10))
                        .blur(radius: revealKey ? 0 : 8)
                        .overlay {
                            if !revealKey {
                                Button("Show QR") { revealKey = true }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add another device")
                        .font(.headline)
                    Text("In Tudu for Android, open Settings → Sync and scan this code, or paste the key.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(revealKey ? (SyncConfig.syncKey ?? "") : String(repeating: "•", count: 24))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)

                    HStack {
                        Button(revealKey ? "Hide" : "Reveal") { revealKey.toggle() }
                        Button(copied ? "Copied" : "Copy Key") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SyncConfig.syncKey ?? "", forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                    }
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Pairing")
        }

        Section {
            LabeledContent("Server", value: SyncConfig.serverURL.host() ?? SyncConfig.serverURL.absoluteString)
            Button("Disconnect This Mac", role: .destructive) { confirmDisconnect = true }
        }
    }

    private var serverSection: some View {
        Section {
            TextField("Server URL", text: $serverText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            if serverURL == nil {
                Text("Enter a valid http(s) URL.").font(.caption).foregroundStyle(.orange)
            }
            Button("Use Default Server") { serverText = SyncConfig.defaultServerURL.absoluteString }
                .disabled(serverText == SyncConfig.defaultServerURL.absoluteString)
        } header: {
            Text("Server")
        } footer: {
            Text("Change this only if you deployed your own copy of the Tudu Worker.")
        }
    }

    private func applyServer() {
        if let serverURL { SyncConfig.serverURL = serverURL }
    }
}

// MARK: - Helpers

enum QRCode {
    static func image(for string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: 10)
            Text("\(Int(value))px")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}
