import SwiftUI
import UniformTypeIdentifiers

/// A `FileDocument` wrapper so the task list can be exported as pretty-printed
/// JSON and re-imported later.
struct TodoExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var todos: [Todo]

    init(todos: [Todo]) {
        self.todos = todos
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        todos = (try? JSONDecoder().decode([Todo].self, from: data)) ?? []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(todos)
        return FileWrapper(regularFileWithContents: data)
    }
}

/// A simple identifiable message used to drive an `Alert`.
struct InfoAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
