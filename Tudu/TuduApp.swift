//
//  TuduApp.swift
//  Tudu
//
//  Created by Aslam on 11/12/25.
//

import SwiftUI
import Foundation
import Combine
import Cocoa
import WidgetKit

// MARK: - App Preferences
class AppPreferences: ObservableObject {
    static let shared = AppPreferences()
    
    @Published var showMenuBarIcon: Bool = true
    @Published var menuBarWidth: Double = 400
    @Published var menuBarHeight: Double = 500
    
    private let saveKey = "AppPreferences"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        load()
    }
    
    func save() {
        userDefaults.set(showMenuBarIcon, forKey: "showMenuBarIcon")
        userDefaults.set(menuBarWidth, forKey: "menuBarWidth")
        userDefaults.set(menuBarHeight, forKey: "menuBarHeight")
    }
    
    func load() {
        showMenuBarIcon = userDefaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        menuBarWidth = userDefaults.object(forKey: "menuBarWidth") as? Double ?? 400
        menuBarHeight = userDefaults.object(forKey: "menuBarHeight") as? Double ?? 500
    }
}

// MARK: - Todo Data Manager (Shared)
class TodoDataManager: ObservableObject {
    static let shared = TodoDataManager()
    
    @Published var todos: [Todo] = []
    @Published var newTodoText = ""
    
    private let userDefaults = UserDefaults(suiteName: SharedTodoData.suiteName) ?? UserDefaults.standard
    
    private init() {
        loadTodos()
    }
    
    func addTodo(title: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let todo = Todo(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        todos.insert(todo, at: 0)
        saveTodos()
    }
    
    func removeTodo(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
        saveTodos()
    }
    
    func toggleTodo(_ todo: Todo) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            saveTodos()
        }
    }
    
    private func saveTodos() {
        SharedTodoData.saveTodos(todos)
        
        // Refresh all widgets when data changes
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func loadTodos() {
        todos = SharedTodoData.loadTodos()
    }
}

// MARK: - UI Components
struct TodoRowView: View {
    let todo: Todo
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .blue)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(todo.isCompleted)
                    .foregroundColor(todo.isCompleted ? .gray : .primary)
                    .font(.body)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(todo.isCompleted ? Color.gray.opacity(0.1) : Color.clear)
        )
    }
}

struct StatsView: View {
    let todos: [Todo]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(todos.count)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
                .frame(height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(todos.filter { $0.isCompleted }.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
                .frame(height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(todos.filter { !$0.isCompleted }.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Menu Bar View
struct MenuBarView: View {
    @ObservedObject var dataManager = TodoDataManager.shared
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("My Todos")
                    .font(.headline)
                Spacer()
                Button(action: openPreferences) {
                    Image(systemName: "gear")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)
            
            Divider()
            
            // Stats
            HStack {
                Text("Total: \(dataManager.todos.count)")
                Spacer()
                Text("Completed: \(dataManager.todos.filter { $0.isCompleted }.count)")
            }
            .padding(.horizontal)
            .foregroundColor(.secondary)
            .font(.caption)
            
            // Todo list
            ScrollView {
                VStack(spacing: 8) {
                    if dataManager.todos.isEmpty {
                        Text("No todos yet!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(dataManager.todos.prefix(10)) { todo in
                            HStack {
                                Button(action: { dataManager.toggleTodo(todo) }) {
                                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                        .foregroundColor(todo.isCompleted ? .green : .blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text(todo.title)
                                    .font(.caption)
                                    .strikethrough(todo.isCompleted)
                                    .foregroundColor(todo.isCompleted ? .gray : .primary)
                                    .lineLimit(2)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(todo.isCompleted ? Color.gray.opacity(0.1) : Color.clear)
                            )
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            Divider()
            
            // Add new todo - Wider input bar
            HStack {
                TextField("New todo...", text: $dataManager.newTodoText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        dataManager.addTodo(title: dataManager.newTodoText)
                        dataManager.newTodoText = ""
                    }
                
                Button("Add") {
                    dataManager.addTodo(title: dataManager.newTodoText)
                    dataManager.newTodoText = ""
                }
                .disabled(dataManager.newTodoText.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: AppPreferences.shared.menuBarWidth, height: AppPreferences.shared.menuBarHeight)
    }
    
    private func openPreferences() {
        // This would open a preferences window in a full app
        print("Open preferences")
    }
}

// MARK: - Preferences View
struct PreferencesView: View {
    @State private var showMenuBarIcon: Bool = AppPreferences.shared.showMenuBarIcon
    @State private var menuBarWidth: Double = AppPreferences.shared.menuBarWidth
    @State private var menuBarHeight: Double = AppPreferences.shared.menuBarHeight
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Preferences")
                    .font(.title)
                    .bold()
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Menu Bar Settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                
                if showMenuBarIcon {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Menu Bar Size")
                            .font(.headline)
                        
                        HStack {
                            Text("Width: \(Int(menuBarWidth))px")
                            Slider(value: $menuBarWidth, in: 300...600, step: 10)
                        }
                        
                        HStack {
                            Text("Height: \(Int(menuBarHeight))px")
                            Slider(value: $menuBarHeight, in: 400...800, step: 10)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(8)
                
                Spacer()
                
                Button("Save") {
                    // Save preferences
                    let prefs = AppPreferences.shared
                    prefs.showMenuBarIcon = showMenuBarIcon
                    prefs.menuBarWidth = menuBarWidth
                    prefs.menuBarHeight = menuBarHeight
                    prefs.save()
                    
                    // Dismiss the sheet
                    presentationMode.wrappedValue.dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - Main View
struct ContentView: View {
    @ObservedObject var dataManager = TodoDataManager.shared
    @State private var showPreferences = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Full width input bar
            HStack {
                TextField("Add a new task...", text: $dataManager.newTodoText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        dataManager.addTodo(title: dataManager.newTodoText)
                        dataManager.newTodoText = ""
                    }
                
                Button(action: {
                    dataManager.addTodo(title: dataManager.newTodoText)
                    dataManager.newTodoText = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(dataManager.newTodoText.isEmpty)
                .keyboardShortcut(.defaultAction)
                
                // Preferences button
                Button(action: { showPreferences = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .sheet(isPresented: $showPreferences) {
                    PreferencesView()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            StatsView(todos: dataManager.todos)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            
            List {
                ForEach(dataManager.todos) { todo in
                    TodoRowView(
                        todo: todo,
                        onToggle: { dataManager.toggleTodo(todo) },
                        onDelete: { dataManager.removeTodo(todo) }
                    )
                }
                .onDelete(perform: deleteTodos)
            }
            .listStyle(PlainListStyle())
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Todo Widget")
    }
    
    private func deleteTodos(offsets: IndexSet) {
        let todosToDelete = offsets.map { dataManager.todos[$0] }
        for todo in todosToDelete {
            dataManager.removeTodo(todo)
        }
    }
}

// MARK: - App Delegate for Menu Bar
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        guard AppPreferences.shared.showMenuBarIcon else { return }
        guard statusItem == nil else { return }
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set menu bar icon
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Tudu")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        updatePopoverSize()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
    }
    
    private func updatePopoverSize() {
        let preferences = AppPreferences.shared
        popover?.contentSize = NSSize(width: preferences.menuBarWidth, height: preferences.menuBarHeight)
    }
    
    @objc private func togglePopover() {
        guard let popover = popover, let statusItem = statusItem else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

// MARK: - App Entry Point
@main
struct TuduApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
                       minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        }
    }
}