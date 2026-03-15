import SwiftUI

struct RenamePane: View {
    @EnvironmentObject private var store: BlinderStore
    @State private var prefixDraft = ""
    @State private var suffixDraft = ""

    var body: some View {
        Pane {
            Form {
                Section("Welcome") {
                    Text("Blinder helps anonymize file names for blinded review. Run a test run first, verify the preview, then apply Blind! to create mapping files for a safe later restore.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Source") {
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Choose source folder") {
                            if let url = store.chooseFolderPanel(title: "Choose source folder") {
                                store.setSourceFolder(url)
                            }
                        }
                        Text(store.sourceFolderURL?.path ?? "No source folder selected")
                            .font(.caption)
                            .lineLimit(2)
                    }
                }

                Section("Files") {
                    HStack {
                        Button("Select all") { store.setAllFiles(selected: true) }
                        Button("Select none") { store.setAllFiles(selected: false) }
                        Spacer()
                        Toggle("Show original names", isOn: $store.showOriginalNames)
                            .toggleStyle(.switch)
                    }
                    Text("\(store.selectedCount) of \(store.files.count) files selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(store.files.enumerated()), id: \.element.id) { index, file in
                                Toggle(
                                    isOn: Binding(
                                        get: { file.selected },
                                        set: { isSelected in
                                            store.setFileSelection(fileID: file.id, isSelected: isSelected)
                                        }
                                    )
                                ) {
                                    Text(store.displayName(for: file, index: index + 1))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.visible)
                    .frame(minHeight: 160, maxHeight: 220)
                }

                Section("Rename options") {
                    Picker("Mode", selection: $store.mode) {
                        ForEach(BlinderRenameMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.mode) { _ in
                        store.syncAutomaticMappingFolder()
                    }

                    Picker("Naming scheme", selection: $store.namingStrategy) {
                        ForEach(BlinderNamingStrategy.allCases) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prefix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Prefix", text: $prefixDraft)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suffix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Suffix", text: $suffixDraft)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    HStack(spacing: 12) {
                        if store.namingStrategy == .randomToken {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Character set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Character set", selection: $store.randomCharset) {
                                    ForEach(BlinderRandomCharset.allCases) { charset in
                                        Text(charset.displayName).tag(charset)
                                    }
                                }
                                .labelsHidden()
                            }
                            Stepper("Token length: \(store.randomLength)", value: $store.randomLength, in: 4...64)
                        }

                        if store.namingStrategy == .sequentialNumbered {
                            Stepper("Start number: \(store.namingStartNumber)", value: $store.namingStartNumber, in: 1...999_999)
                        }

                        if store.mode == .copyThenRename {
                            VStack(alignment: .leading, spacing: 4) {
                                Button("Choose target folder") {
                                    if let url = store.chooseFolderPanel(title: "Choose target folder") {
                                        store.setDestinationFolder(url)
                                    }
                                }
                                Text(store.destinationFolderURL?.path ?? "No target folder selected")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Section("Run") {
                    HStack(spacing: 12) {
                        Button {
                            applyNamingDrafts()
                            store.createDryRun()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Test run")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            applyNamingDrafts()
                            store.executeRename()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "eye.slash.fill")
                                Text("Blind!")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }

                Section("Test run preview") {
                    if store.dryRunPreview.isEmpty {
                        Text("No test run available yet. Run a test run first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        let maxPreviewItems = 300
                        let previewItems = Array(store.dryRunPreview.prefix(maxPreviewItems))
                        if store.dryRunPreview.count > maxPreviewItems {
                            Text("Showing first \(maxPreviewItems) entries (\(store.dryRunPreview.count - maxPreviewItems) more hidden).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(previewItems) { item in
                                    HStack {
                                        Text(item.originalDisplayName)
                                            .lineLimit(1)
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.secondary)
                                        Text(item.newName)
                                            .lineLimit(1)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 140, maxHeight: 220)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .navigationSubtitle("Rename")
        .onAppear {
            prefixDraft = store.namingPrefix
            suffixDraft = store.namingSuffix
        }
        .onDisappear {
            applyNamingDrafts()
        }
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    applyNamingDrafts()
                    store.createDryRun()
                } label: {
                    Label("Test run", systemImage: "doc.text.magnifyingglass")
                }
                .help("Run test run and refresh preview")

                Button {
                    applyNamingDrafts()
                    store.executeRename()
                } label: {
                    Label("Blind!", systemImage: "eye.slash.fill")
                }
                .help("Apply final rename operation")
            }
        }
    }

    private func applyNamingDrafts() {
        store.namingPrefix = prefixDraft
        store.namingSuffix = suffixDraft
    }
}

struct RenamePane_Previews: PreviewProvider {
    static var previews: some View {
        RenamePane()
            .environmentObject(BlinderStore())
    }
}
