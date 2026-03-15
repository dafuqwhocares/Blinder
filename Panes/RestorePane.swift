import SwiftUI

struct RestorePane: View {
    @EnvironmentObject private var store: BlinderStore

    var body: some View {
        Pane {
            Form {
                Section("Mapping") {
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Load mapping.json") {
                            if let url = store.chooseJSONPanel(title: "Select mapping.json") {
                                store.loadMappingBundle(from: url)
                            }
                        }
                        Text(store.restoreBundle?.metadata.runID ?? "No mapping loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Restore actions") {
                    HStack {
                        Button {
                            store.dryRunRestore()
                        } label: {
                            Label("Test run", systemImage: "doc.text.magnifyingglass")
                        }
                        Button {
                            store.executeRestore()
                        } label: {
                            Label("Unblind!", systemImage: "eye.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Section("Restore preview") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(store.restorePreview) { item in
                                if item.canRestore {
                                    Label(URL(fileURLWithPath: item.blindedPath).lastPathComponent, systemImage: "checkmark.circle")
                                        .foregroundStyle(.green)
                                } else {
                                    Label("\(URL(fileURLWithPath: item.blindedPath).lastPathComponent) - \(item.reason ?? "Unknown")", systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 140, maxHeight: 240)
                }
            }
            .formStyle(.grouped)
        }
        .navigationSubtitle("Restore")
        .sheet(item: $store.actionAlert) { alert in
            VStack(spacing: 14) {
                Text(alert.title)
                    .font(.headline)
                Text(alert.message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("OK") {
                    store.actionAlert = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(20)
            .frame(minWidth: 340)
        }
    }
}

struct RestorePane_Previews: PreviewProvider {
    static var previews: some View {
        RestorePane()
            .environmentObject(BlinderStore())
    }
}
