import InputMateCore
import SwiftUI

private enum ShortcutSidebarFilter: String, CaseIterable, Identifiable {
  case all = "All"
  case apps = "Apps"
  case shortcuts = "Shortcuts"
  case system = "System & Automation"
  case appSpecific = "App-Specific"

  var id: String { rawValue }

  var symbolName: String {
    switch self {
    case .all: "square.stack.3d.up"
    case .apps: "square.grid.2x2"
    case .shortcuts: "command"
    case .system: "gearshape.2"
    case .appSpecific: "macwindow.on.rectangle"
    }
  }

  var heading: String {
    switch self {
    case .all: "Global Keyboard Shortcuts"
    case .apps: "Application Shortcuts"
    case .shortcuts: "Shortcuts"
    case .system: "System & Automation"
    case .appSpecific: "App-Specific Shortcuts"
    }
  }

  var detail: String {
    switch self {
    case .all:
      "Every configured shortcut. Modifier sides remain distinct."
    case .apps:
      "Open installed applications with their real app icons."
    case .shortcuts:
      "Transform selected text, open URLs, run Apple Shortcuts, or send a keyboard shortcut."
    case .system:
      "Control notifications, windows, sleep, and other macOS actions."
    case .appSpecific:
      "Shortcuts limited to certain applications. They take priority over a global shortcut on the same keys."
    }
  }

  func includes(_ definition: KeyboardShortcutDefinition) -> Bool {
    switch self {
    case .all:
      return true
    case .apps:
      return definition.category == .applications
    case .shortcuts:
      return definition.category == .shortcuts
    case .system:
      return definition.category == .system
    case .appSpecific:
      return !(definition.appScope?.isGlobal ?? true)
    }
  }
}

struct ShortcutReferenceView: View {
  @ObservedObject var model: AppModel

  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @SceneStorage("shortcutSidebarFilter") private var selectedFilterRawValue =
    ShortcutSidebarFilter.all.rawValue
  @State private var selection = Set<String>()
  @State private var searchText = ""
  @State private var editorContext: ShortcutEditorContext?
  @State private var showsDeleteConfirmation = false
  @State private var showsResetConfirmation = false

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
    } detail: {
      shortcutList
    }
    .navigationSplitViewStyle(.prominentDetail)
    .frame(minWidth: 960, minHeight: 540)
    .searchable(text: $searchText, placement: .toolbar, prompt: "Search shortcuts")
    .onChange(of: selectedFilterRawValue) { _ in
      reconcileSelection()
    }
    .onChange(of: searchText) { _ in
      reconcileSelection()
    }
    .onDeleteCommand {
      if !selection.isEmpty {
        showsDeleteConfirmation = true
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button {
          addShortcut()
        } label: {
          Label("Add Shortcut", systemImage: "plus")
        }
        .keyboardShortcut("n", modifiers: .command)
        .help("Add Shortcut")

        Button {
          editSelectedShortcut()
        } label: {
          Label("Edit Shortcut", systemImage: "pencil")
        }
        .disabled(singleSelection == nil)
        .help("Edit Shortcut")

        Button {
          duplicateSelectedShortcut()
        } label: {
          Label("Duplicate Shortcut", systemImage: "plus.square.on.square")
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(singleSelection == nil)
        .help("Duplicate Shortcut")

        Button {
          showsDeleteConfirmation = true
        } label: {
          Label("Delete Shortcut", systemImage: "trash")
        }
        .disabled(selection.isEmpty)
        .help("Delete Shortcut")

        Menu {
          Button("Reset to Default Shortcuts…") {
            showsResetConfirmation = true
          }
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }
    }
    .sheet(item: $editorContext) { context in
      ShortcutEditorView(
        definition: context.definition,
        existingDefinitions: model.shortcutDefinitions,
        onSave: model.saveShortcut
      )
    }
    .alert("Delete selected shortcuts?", isPresented: $showsDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        model.deleteShortcuts(ids: selection)
        selection.removeAll()
      }
    } message: {
      Text("This cannot be undone.")
    }
    .alert("Reset all shortcuts?", isPresented: $showsResetConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        model.resetShortcuts()
        selection.removeAll()
      }
    } message: {
      Text("Your custom shortcuts will be replaced by the original InputMate shortcuts.")
    }
  }

  private var sidebar: some View {
    List(selection: $selectedFilterRawValue) {
      Section("Library") {
        ForEach(ShortcutSidebarFilter.allCases) { filter in
          Label(filter.rawValue, systemImage: filter.symbolName)
            .badge(count(for: filter))
            .tag(filter.rawValue)
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Shortcuts")
    .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 250)
  }

  private var shortcutList: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(activeFilter.heading)
          .font(.title2.weight(.semibold))

        Text(activeFilter.detail)
          .foregroundStyle(.secondary)
      }

      if filteredDefinitions.isEmpty {
        emptyState
      } else {
        Table(filteredDefinitions, selection: $selection) {
          TableColumn("On") { shortcut in
            Toggle(
              "Enabled",
              isOn: Binding(
                get: { shortcut.isEnabled },
                set: { model.setShortcutEnabled(id: shortcut.id, enabled: $0) }
              )
            )
            .labelsHidden()
            .help(shortcut.isEnabled ? "Disable shortcut" : "Enable shortcut")
          }
          .width(34)

          TableColumn("Shortcut") { shortcut in
            Button {
              editShortcut(shortcut)
            } label: {
              HStack(spacing: 7) {
                Text(shortcut.displayShortcut)
                  .font(.system(.body, design: .monospaced))
                Image(systemName: "pencil")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              .foregroundStyle(shortcut.isEnabled ? .primary : .secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Change shortcut")
          }
          .width(min: 170, ideal: 200)

          TableColumn("Action") { shortcut in
            HStack(spacing: 9) {
              ShortcutIconView(action: shortcut.action)
              Text(shortcut.actionTitle)
                .lineLimit(1)
            }
            .opacity(shortcut.isEnabled ? 1 : 0.55)
          }

          TableColumn("Applies To") { shortcut in
            ShortcutScopeSummaryView(scope: shortcut.appScope)
              .opacity(shortcut.isEnabled ? 1 : 0.55)
          }
          .width(min: 140, ideal: 170)

          TableColumn("Group") { shortcut in
            Text(shortcut.category.rawValue)
              .foregroundStyle(.secondary)
          }
          .width(min: 130, ideal: 150)
        }
      }

      HStack {
        if let statusMessage = model.statusMessage {
          Label(statusMessage, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
        } else {
          Text(
            "\(filteredDefinitions.count) shown · \(model.enabledShortcutCount) enabled · \(model.shortcutDefinitions.count) total"
          )
          .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .font(.caption)
    }
    .padding(20)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: searchText.isEmpty ? "command" : "magnifyingglass")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)

      Text(searchText.isEmpty ? "No Shortcuts Here" : "No Matches")
        .font(.title3.weight(.semibold))

      Text(
        searchText.isEmpty
          ? "Add a shortcut to see it in this list."
          : "No shortcut matches “\(searchText)”."
      )
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var activeFilter: ShortcutSidebarFilter {
    ShortcutSidebarFilter(rawValue: selectedFilterRawValue) ?? .all
  }

  private var filteredDefinitions: [KeyboardShortcutDefinition] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return model.shortcutDefinitions.filter {
      activeFilter.includes($0)
        && (query.isEmpty
          || $0.actionTitle.localizedCaseInsensitiveContains(query)
          || $0.displayShortcut.localizedCaseInsensitiveContains(query)
          || $0.category.rawValue.localizedCaseInsensitiveContains(query)
          || $0.action.kind.rawValue.localizedCaseInsensitiveContains(query)
          || matchesScope($0, query: query))
    }
  }

  private func matchesScope(_ definition: KeyboardShortcutDefinition, query: String) -> Bool {
    guard let identifiers = definition.appScope?.bundleIdentifiers else { return false }
    return identifiers.contains {
      $0.localizedCaseInsensitiveContains(query)
        || ScopedApplication.name(for: $0).localizedCaseInsensitiveContains(query)
    }
  }

  private var singleSelection: KeyboardShortcutDefinition? {
    guard selection.count == 1, let id = selection.first else { return nil }
    return model.shortcutDefinitions.first(where: { $0.id == id })
  }

  private func count(for filter: ShortcutSidebarFilter) -> Int {
    model.shortcutDefinitions.count(where: filter.includes)
  }

  private func reconcileSelection() {
    selection.formIntersection(Set(filteredDefinitions.map(\.id)))
  }

  private func addShortcut() {
    editorContext = ShortcutEditorContext(definition: KeyboardShortcutCatalog.blankDefinition)
  }

  private func editSelectedShortcut() {
    guard let shortcut = singleSelection else { return }
    editShortcut(shortcut)
  }

  private func editShortcut(_ shortcut: KeyboardShortcutDefinition) {
    editorContext = ShortcutEditorContext(definition: shortcut)
  }

  private func duplicateSelectedShortcut() {
    guard let shortcut = singleSelection,
      let copyID = model.duplicateShortcut(id: shortcut.id)
    else { return }
    selection = [copyID]
  }
}
