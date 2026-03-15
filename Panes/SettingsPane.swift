import SwiftUI

struct SettingsPane: View {
    @EnvironmentObject private var store: BlinderStore
    @State private var prefixDraft = ""
    @State private var suffixDraft = ""

    var body: some View {
        Pane {
            Form {
                Section("Naming defaults") {
                    Picker("Default mode", selection: $store.mode) {
                        ForEach(BlinderRenameMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Default naming scheme", selection: $store.namingStrategy) {
                        ForEach(BlinderNamingStrategy.allCases) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.mode) { _ in
                        store.syncAutomaticMappingFolder()
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default prefix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Default prefix", text: $prefixDraft)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default suffix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Default suffix", text: $suffixDraft)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack(spacing: 12) {
                        if store.namingStrategy == .randomToken {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default character set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Default character set", selection: $store.randomCharset) {
                                    ForEach(BlinderRandomCharset.allCases) { charset in
                                        Text(charset.displayName).tag(charset)
                                    }
                                }
                                .labelsHidden()
                            }
                            Stepper("Default token length: \(store.randomLength)", value: $store.randomLength, in: 4...64)
                        }

                        if store.namingStrategy == .sequentialNumbered {
                            Stepper("Default start number: \(store.namingStartNumber)", value: $store.namingStartNumber, in: 1...999_999)
                        }
                    }
                }

                Section("Info") {
                    Text("These settings are saved automatically and restored on next launch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            prefixDraft = store.namingPrefix
            suffixDraft = store.namingSuffix
        }
        .onDisappear {
            store.namingPrefix = prefixDraft
            store.namingSuffix = suffixDraft
        }
    }
}

struct SettingsPane_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPane()
            .environmentObject(BlinderStore())
    }
}
