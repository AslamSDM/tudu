import SwiftUI

// MARK: - Store helpers

extension TodoStore {
    /// Adds a task from quick-add text, using the shorthand parser. Inherits
    /// context from the selected list (a tag list adds its tag; Today sets a
    /// due date of today) unless the text says otherwise.
    @discardableResult
    func addQuick(_ text: String, context: SmartList? = nil) -> Todo? {
        var parsed = QuickAddParser.parse(text)
        guard !parsed.title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        switch context ?? selection {
        case .tag(let tag):
            parsed.tags = Todo.normalize(tags: [tag] + parsed.tags)
        case .today where parsed.dueDate == nil:
            parsed.dueDate = QuickAddParser.parse("@today").dueDate
        default:
            break
        }
        return add(title: parsed.title, priority: parsed.priority, dueDate: parsed.dueDate, tags: parsed.tags)
    }
}

// MARK: - Colors

extension TodoPriority {
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .secondary
        case .high: return .red
        }
    }
}

extension SmartList {
    var tint: Color {
        switch self {
        case .today: return .orange
        case .upcoming: return .red
        case .all: return .blue
        case .completed: return .green
        case .tag(let tag): return .forTag(tag)
        }
    }
}

// MARK: - Check button

/// Round checkbox with a springy fill animation.
struct CheckButton: View {
    let isOn: Bool
    var tint: Color = .accentColor
    var size: CGFloat = 18
    let action: () -> Void

    @State private var bounce = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bounce = false }
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(isOn ? Color.green : tint.opacity(0.85), lineWidth: 1.6)
                if isOn {
                    Circle().fill(Color.green)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(bounce ? 1.18 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Mark as not done" : "Mark as done")
        .accessibilityLabel(isOn ? "Completed" : "Not completed")
    }
}

// MARK: - Quick add

/// Single-line capture field with live previews of parsed shorthand.
struct QuickAddField: View {
    @Binding var text: String
    var placeholder = "Add a task — try “Pay rent #home !high @fri”"
    var compact = false
    var focus: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    private var parsed: QuickAddParser.Result { QuickAddParser.parse(text) }
    private var canSubmit: Bool { !parsed.title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: compact ? 18 : 20)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(compact ? .callout : .body)
                    .focused(focus)
                    .onSubmit { if canSubmit { onSubmit() } }

                if canSubmit {
                    Button(action: onSubmit) {
                        Image(systemName: "return")
                            .font(.caption.weight(.bold))
                            .padding(5)
                            .background(.tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Add task (Return)")
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if parsed.hasMetadata {
                HStack(spacing: 5) {
                    if let due = parsed.dueDate {
                        DueDateBadge(date: due, isOverdue: false)
                    }
                    if parsed.priority != .medium {
                        PriorityBadge(priority: parsed.priority)
                    }
                    ForEach(parsed.tags, id: \.self) { TagChip(tag: $0) }
                }
                .padding(.leading, compact ? 28 : 30)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 11)
        .background(
            RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous)
                .fill(.background.opacity(0.7))
                .shadow(color: .black.opacity(focus.wrappedValue ? 0.10 : 0.04), radius: focus.wrappedValue ? 8 : 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous)
                .strokeBorder(focus.wrappedValue ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: parsed)
        .animation(.easeOut(duration: 0.15), value: focus.wrappedValue)
    }
}

// MARK: - Badges

struct DueDateBadge: View {
    let date: Date
    let isOverdue: Bool

    var body: some View {
        Label(text, systemImage: isOverdue ? "exclamationmark.circle.fill" : "calendar")
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        if isOverdue { return .orange }
        return Calendar.current.isDateInToday(date) ? .orange : .secondary
    }

    private var text: String { DueText.short(date, isOverdue: isOverdue) }
}

enum DueText {
    static func short(_ date: Date, isOverdue: Bool) -> String {
        let calendar = Calendar.current
        if isOverdue {
            return calendar.isDateInYesterday(date) ? "Yesterday" : "Overdue"
        }
        if calendar.isDateInToday(date) {
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            if comps.hour == 0 && comps.minute == 0 { return "Today" }
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if let days = calendar.dateComponents([.day], from: Date(), to: date).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct PriorityBadge: View {
    let priority: TodoPriority

    var body: some View {
        Label(priority.title, systemImage: priority == .high ? "flag.fill" : "flag")
            .font(.caption2.weight(.medium))
            .foregroundStyle(priority.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priority.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Progress

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 5
    var showsLabel = true
    var tint: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(
                    progress >= 1 ? Color.green : tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            if showsLabel {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Sync status

struct SyncStatusView: View {
    @ObservedObject private var sync = SyncEngine.shared
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(spacing: 6) {
                icon
                if !compact {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .help(helpText)
    }

    @ViewBuilder
    private var icon: some View {
        switch sync.status {
        case .off:
            Image(systemName: "icloud.slash").foregroundStyle(.secondary)
        case .idle:
            Image(systemName: "checkmark.icloud").foregroundStyle(.green)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .foregroundStyle(.tint)
                .symbolEffect(.rotate, isActive: true)
        case .failed:
            Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange)
        }
    }

    private var label: String {
        switch sync.status {
        case .off: return "Sync off"
        case .syncing: return "Syncing…"
        case .failed: return "Sync failed"
        case .idle:
            guard let last = sync.lastSuccess else { return "Synced" }
            if Date().timeIntervalSince(last) < 60 { return "Synced just now" }
            return "Synced \(last.formatted(.relative(presentation: .named)))"
        }
    }

    private var helpText: String {
        if case .failed(let message) = sync.status { return message }
        return label
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String
    var tint: Color = .secondary

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(tint.gradient)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
