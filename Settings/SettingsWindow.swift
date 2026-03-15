import SwiftUI

struct SettingsWindow: View {
    @EnvironmentObject private var store: BlinderStore
    @State private var settingsWindow: NSWindow?
    @State private var selectedTab: Tabs = .naming

    private enum Tabs: Hashable {
        case naming
        case privacy
        case output
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsPane()
                .environmentObject(store)
                .tabItem {
                    Label("Naming", systemImage: "textformat.abc")
                }
                .tag(Tabs.naming)

            PrivacySettingsPane()
                .environmentObject(store)
                .tabItem {
                    Label("Privacy", systemImage: "eye.slash")
                }
                .tag(Tabs.privacy)

            OutputIntegritySettingsPane()
                .environmentObject(store)
                .tabItem {
                    Label("Output", systemImage: "doc.text")
                }
                .tag(Tabs.output)
        }
        .frame(minWidth: 760, minHeight: 420)
        .background(WindowReflection(window: $settingsWindow))
        .onAppear {
            enforceSettingsWindowTitle()
        }
        .onChange(of: selectedTab) { _ in
            enforceSettingsWindowTitle()
        }
    }
    
    /// Show settings programmatically
    static func show() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    private func enforceSettingsWindowTitle() {
        settingsWindow?.title = "Settings"
    }
}

private struct PrivacySettingsPane: View {
    @EnvironmentObject private var store: BlinderStore

    var body: some View {
        Pane {
            Form {
                Section("Display and privacy") {
                    Toggle("Show original file names by default", isOn: $store.showOriginalNames)
                        .toggleStyle(.switch)
                }
                Section("Info") {
                    Text("When disabled, file names are masked in the rename list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct OutputIntegritySettingsPane: View {
    @EnvironmentObject private var store: BlinderStore

    var body: some View {
        Pane {
            Form {
                Section("CSV export") {
                    Picker("CSV content", selection: $store.csvExportMode) {
                        ForEach(BlinderCSVExportMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Integrity") {
                    Toggle("Enable SHA-256 integrity check (before/after rename)", isOn: $store.integrityCheckEnabled)
                        .toggleStyle(.switch)
                }
                Section("Info") {
                    Text("Integrity check computes SHA-256 for each file before and after renaming and stores the result in mapping metadata.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct SettingsWindow_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWindow()
            .environmentObject(BlinderStore())
    }
}
