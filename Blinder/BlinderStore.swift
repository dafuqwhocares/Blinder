import AppKit
import CryptoKit
import Foundation

struct BlinderSelectableFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var selected: Bool
}

enum BlinderRenameMode: String, Codable, CaseIterable, Identifiable {
    case inPlace = "in_place"
    case copyThenRename = "copy_then_rename"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inPlace:
            return "Rename in source folder"
        case .copyThenRename:
            return "Copy then rename"
        }
    }
}

enum BlinderNamingStrategy: String, Codable, CaseIterable, Identifiable {
    case sequentialNumbered = "sequential_numbered"
    case randomToken = "random_token"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sequentialNumbered:
            return "Sequential number"
        case .randomToken:
            return "Random token"
        }
    }
}

enum BlinderRandomCharset: String, Codable, CaseIterable, Identifiable {
    case lettersAndDigits = "letters_and_digits"
    case digitsOnly = "digits_only"
    case lettersOnly = "letters_only"
    case hexLower = "hex_lower"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lettersAndDigits:
            return "Letters + digits"
        case .digitsOnly:
            return "Digits only"
        case .lettersOnly:
            return "Letters only"
        case .hexLower:
            return "Hex (0-9, a-f)"
        }
    }

    var alphabet: [Character] {
        switch self {
        case .lettersAndDigits:
            return Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        case .digitsOnly:
            return Array("0123456789")
        case .lettersOnly:
            return Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        case .hexLower:
            return Array("0123456789abcdef")
        }
    }
}

enum BlinderCSVExportMode: String, Codable, CaseIterable, Identifiable {
    case namesOnly = "names_only"
    case full = "full"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .namesOnly:
            return "Only original and blinded names"
        case .full:
            return "Full audit columns"
        }
    }
}

struct BlinderMappingRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let originalPath: String
    let originalName: String
    let blindedName: String
    let finalPath: String
    let timestamp: Date
    let status: String
    let sha256Before: String?
    let sha256After: String?
    let integrityCheckPassed: Bool?
}

struct BlinderRunMetadata: Codable {
    let runID: String
    let mode: BlinderRenameMode
    let sourceFolder: String
    let destinationFolder: String?
    let createdAt: Date
    let fileCount: Int
    let namingStrategy: BlinderNamingStrategy?
    let namingPrefix: String?
    let namingSuffix: String?
    let namingStartNumber: Int?
    let randomCharset: BlinderRandomCharset?
    let randomLength: Int?
    let csvExportMode: BlinderCSVExportMode?
    let integrityCheckEnabled: Bool?
}

struct BlinderMappingBundle: Codable {
    let metadata: BlinderRunMetadata
    let records: [BlinderMappingRecord]
}

enum BlinderError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text):
            return text
        }
    }
}

struct BlinderRenamePlanItem: Identifiable {
    let id: UUID
    let sourceURL: URL
    let workingFolderURL: URL
    let tempURL: URL
    let finalURL: URL
}

struct BlinderRenamePlan {
    let mode: BlinderRenameMode
    let sourceFolderURL: URL
    let destinationFolderURL: URL?
    let namingStrategy: BlinderNamingStrategy
    let namingPrefix: String
    let namingSuffix: String
    let namingStartNumber: Int
    let randomCharset: BlinderRandomCharset
    let randomLength: Int
    let items: [BlinderRenamePlanItem]
}

private struct BlinderFileScanner {
    func listFiles(in folderURL: URL, imageOnly: Bool) throws -> [URL] {
        let values = try folderURL.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
        guard values.isDirectory == true, values.isReadable == true else {
            throw BlinderError.message("Folder cannot be read.")
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        let filtered = try urls.filter { url in
            let attrs = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard attrs.isRegularFile == true else { return false }
            guard imageOnly else { return true }
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "tif", "tiff", "png", "bmp", "gif", "webp", "heic"].contains(ext)
        }
        return filtered.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    func assertWritable(_ folderURL: URL) throws {
        let testURL = folderURL.appendingPathComponent(".blinder_write_test_\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: testURL.path, contents: Data(), attributes: nil) else {
            throw BlinderError.message("Folder is not writable: \(folderURL.path)")
        }
        try? FileManager.default.removeItem(at: testURL)
    }
}

private struct BlinderRenamePlanner {
    func createPlan(
        selectedFiles: [URL],
        sourceFolderURL: URL,
        destinationFolderURL: URL?,
        mode: BlinderRenameMode,
        namingStrategy: BlinderNamingStrategy,
        namingPrefix: String,
        namingSuffix: String,
        namingStartNumber: Int,
        randomCharset: BlinderRandomCharset,
        randomLength: Int
    ) throws -> BlinderRenamePlan {
        guard !selectedFiles.isEmpty else {
            throw BlinderError.message("No files selected.")
        }

        let workingFolder: URL
        switch mode {
        case .inPlace:
            workingFolder = sourceFolderURL
        case .copyThenRename:
            guard let destinationFolderURL else {
                throw BlinderError.message("Please choose a target folder.")
            }
            if destinationFolderURL.standardizedFileURL == sourceFolderURL.standardizedFileURL {
                throw BlinderError.message("Source and target folders must be different.")
            }
            workingFolder = destinationFolderURL
        }

        let safePrefix = sanitizedPrefix(for: namingStrategy, prefix: namingPrefix)
        let safeSuffix = namingSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        var sequence = max(1, namingStartNumber)
        let safeRandomLength = max(4, min(64, randomLength))
        var plannedNames = Set<String>()
        var items: [BlinderRenamePlanItem] = []
        var filesForPlanning = selectedFiles
        if namingStrategy == .sequentialNumbered {
            // Privacy: prevent predictable numbering by shuffling processing order.
            filesForPlanning.shuffle()
        }

        for fileURL in filesForPlanning {
            let ext = fileURL.pathExtension
            let base: String
            switch namingStrategy {
            case .randomToken:
                let token = randomToken(length: safeRandomLength, charset: randomCharset)
                base = "\(safePrefix)\(token)\(safeSuffix)"
            case .sequentialNumbered:
                base = "\(safePrefix)\(sequence)\(safeSuffix)"
                sequence += 1
            }
            let finalName = ext.isEmpty ? base : "\(base).\(ext)"
            let tempName = ".blinder_tmp_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"

            if plannedNames.contains(finalName) {
                throw BlinderError.message("Duplicate planned name: \(finalName)")
            }
            plannedNames.insert(finalName)

            let finalURL = workingFolder.appendingPathComponent(finalName)
            if FileManager.default.fileExists(atPath: finalURL.path) {
                throw BlinderError.message("Target file already exists: \(finalName)")
            }

            items.append(
                BlinderRenamePlanItem(
                    id: UUID(),
                    sourceURL: fileURL,
                    workingFolderURL: workingFolder,
                    tempURL: workingFolder.appendingPathComponent(tempName),
                    finalURL: finalURL
                )
            )
        }

        return BlinderRenamePlan(
            mode: mode,
            sourceFolderURL: sourceFolderURL,
            destinationFolderURL: destinationFolderURL,
            namingStrategy: namingStrategy,
            namingPrefix: safePrefix,
            namingSuffix: safeSuffix,
            namingStartNumber: max(1, namingStartNumber),
            randomCharset: randomCharset,
            randomLength: safeRandomLength,
            items: items
        )
    }

    private func sanitizedPrefix(for strategy: BlinderNamingStrategy, prefix: String) -> String {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch strategy {
        case .sequentialNumbered:
            return "IMG_"
        case .randomToken:
            return "BLIND_"
        }
    }

    private func randomToken(length: Int, charset: BlinderRandomCharset) -> String {
        let alphabet = charset.alphabet
        return String((0..<length).compactMap { _ in
            alphabet.randomElement()
        })
    }
}

private struct BlinderRenameExecutor {
    private struct OperationState {
        let planItem: BlinderRenamePlanItem
        let mode: BlinderRenameMode
        var tempCreated = false
        var finalCreated = false
    }

    func execute(plan: BlinderRenamePlan, integrityCheckEnabled: Bool) throws -> [BlinderMappingRecord] {
        var operations = plan.items.map { OperationState(planItem: $0, mode: plan.mode) }
        var hashesBefore: [UUID: String] = [:]
        var hashesAfter: [UUID: String] = [:]
        do {
            if integrityCheckEnabled {
                for item in plan.items {
                    hashesBefore[item.id] = try sha256(of: item.sourceURL)
                }
            }
            try phaseOne(&operations)
            try phaseTwo(&operations)
            if integrityCheckEnabled {
                for op in operations {
                    hashesAfter[op.planItem.id] = try sha256(of: op.planItem.finalURL)
                }
            }
        } catch {
            rollback(&operations)
            throw BlinderError.message(error.localizedDescription)
        }

        let records = operations.map { op in
            let restoreTargetPath: String
            switch op.mode {
            case .inPlace:
                restoreTargetPath = op.planItem.sourceURL.path
            case .copyThenRename:
                restoreTargetPath = op.planItem.workingFolderURL.appendingPathComponent(op.planItem.sourceURL.lastPathComponent).path
            }
            let before = hashesBefore[op.planItem.id]
            let after = hashesAfter[op.planItem.id]
            let passed = integrityCheckEnabled ? (before == after) : nil
            return BlinderMappingRecord(
                id: UUID(),
                originalPath: restoreTargetPath,
                originalName: op.planItem.sourceURL.lastPathComponent,
                blindedName: op.planItem.finalURL.lastPathComponent,
                finalPath: op.planItem.finalURL.path,
                timestamp: Date(),
                status: "renamed",
                sha256Before: before,
                sha256After: after,
                integrityCheckPassed: passed
            )
        }

        if integrityCheckEnabled, let failed = records.first(where: { $0.integrityCheckPassed == false }) {
            throw BlinderError.message("Integrity check failed for: \(failed.blindedName)")
        }

        return records
    }

    private func phaseOne(_ operations: inout [OperationState]) throws {
        for index in operations.indices {
            let op = operations[index]
            switch op.mode {
            case .inPlace:
                try FileManager.default.moveItem(at: op.planItem.sourceURL, to: op.planItem.tempURL)
            case .copyThenRename:
                try FileManager.default.copyItem(at: op.planItem.sourceURL, to: op.planItem.tempURL)
            }
            operations[index].tempCreated = true
        }
    }

    private func phaseTwo(_ operations: inout [OperationState]) throws {
        for index in operations.indices {
            let op = operations[index]
            try FileManager.default.moveItem(at: op.planItem.tempURL, to: op.planItem.finalURL)
            operations[index].finalCreated = true
        }
    }

    private func rollback(_ operations: inout [OperationState]) {
        for op in operations.reversed() {
            do {
                switch op.mode {
                case .inPlace:
                    if op.finalCreated {
                        try moveIfExists(from: op.planItem.finalURL, to: op.planItem.sourceURL)
                    } else if op.tempCreated {
                        try moveIfExists(from: op.planItem.tempURL, to: op.planItem.sourceURL)
                    }
                case .copyThenRename:
                    if op.finalCreated {
                        try removeIfExists(op.planItem.finalURL)
                    } else if op.tempCreated {
                        try removeIfExists(op.planItem.tempURL)
                    }
                }
            } catch { }
        }
    }

    private func moveIfExists(from: URL, to: URL) throws {
        guard FileManager.default.fileExists(atPath: from.path) else { return }
        if FileManager.default.fileExists(atPath: to.path) {
            try FileManager.default.removeItem(at: to)
        }
        try FileManager.default.moveItem(at: from, to: to)
    }

    private func removeIfExists(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func sha256(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private struct BlinderMappingPaths {
    let runFolder: URL
    let csvURL: URL
    let jsonURL: URL
    let metadataURL: URL
}

private struct BlinderMappingStore {
    func createRunFolder(in root: URL) throws -> BlinderMappingPaths {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let runFolder = root.appendingPathComponent("blinder-run-\(formatter.string(from: Date()))", isDirectory: true)
        try FileManager.default.createDirectory(at: runFolder, withIntermediateDirectories: true)
        return BlinderMappingPaths(
            runFolder: runFolder,
            csvURL: runFolder.appendingPathComponent("mapping.csv"),
            jsonURL: runFolder.appendingPathComponent("mapping.json"),
            metadataURL: runFolder.appendingPathComponent("run-metadata.json")
        )
    }

    func save(bundle: BlinderMappingBundle, at paths: BlinderMappingPaths, csvExportMode: BlinderCSVExportMode) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(bundle).write(to: paths.jsonURL, options: .atomic)
        try encoder.encode(bundle.metadata).write(to: paths.metadataURL, options: .atomic)
        try csv(from: bundle.records, mode: csvExportMode).write(to: paths.csvURL, atomically: true, encoding: .utf8)
    }

    func load(bundleFrom jsonURL: URL) throws -> BlinderMappingBundle {
        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BlinderMappingBundle.self, from: data)
    }

    private func csv(from records: [BlinderMappingRecord], mode: BlinderCSVExportMode) -> String {
        let header: String
        let lines: [String]
        switch mode {
        case .namesOnly:
            header = "originalName,blindedName"
            lines = records.map { record in
                [
                    esc(record.originalName),
                    esc(record.blindedName),
                ].joined(separator: ",")
            }
        case .full:
            header = "originalPath,originalName,blindedName,finalPath,timestamp,status,sha256Before,sha256After,integrityCheckPassed"
            let formatter = ISO8601DateFormatter()
            lines = records.map { record in
                [
                    esc(record.originalPath),
                    esc(record.originalName),
                    esc(record.blindedName),
                    esc(record.finalPath),
                    esc(formatter.string(from: record.timestamp)),
                    esc(record.status),
                    esc(record.sha256Before ?? ""),
                    esc(record.sha256After ?? ""),
                    esc(record.integrityCheckPassed.map { $0 ? "true" : "false" } ?? ""),
                ].joined(separator: ",")
            }
        }
        return ([header] + lines).joined(separator: "\n")
    }

    private func esc(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

struct BlinderRestorePreviewItem: Identifiable {
    let id = UUID()
    let blindedPath: String
    let originalPath: String
    let canRestore: Bool
    let reason: String?
}

struct BlinderDryRunPreviewItem: Identifiable {
    let id: String
    let originalDisplayName: String
    let newName: String
}

struct BlinderActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct BlinderRestoreService {
    func dryRun(bundle: BlinderMappingBundle) -> [BlinderRestorePreviewItem] {
        bundle.records.map { record in
            let blindURL = URL(fileURLWithPath: record.finalPath)
            let originalURL = URL(fileURLWithPath: record.originalPath)
            if !FileManager.default.fileExists(atPath: blindURL.path) {
                return BlinderRestorePreviewItem(
                    blindedPath: record.finalPath,
                    originalPath: record.originalPath,
                    canRestore: false,
                    reason: "Blinded file is missing"
                )
            }
            if FileManager.default.fileExists(atPath: originalURL.path) {
                return BlinderRestorePreviewItem(
                    blindedPath: record.finalPath,
                    originalPath: record.originalPath,
                    canRestore: false,
                    reason: "Original name already exists"
                )
            }
            return BlinderRestorePreviewItem(
                blindedPath: record.finalPath,
                originalPath: record.originalPath,
                canRestore: true,
                reason: nil
            )
        }
    }

    func executeRestore(bundle: BlinderMappingBundle) throws {
        let preview = dryRun(bundle: bundle)
        if let blocked = preview.first(where: { !$0.canRestore }) {
            if blocked.reason == "Original name already exists" {
                throw BlinderError.message("Original name already exists: \(blocked.originalPath)")
            }
            throw BlinderError.message("Blinded file not found: \(blocked.blindedPath)")
        }

        struct TempMove {
            let temp: URL
            let targetOriginal: URL
        }

        var tempMoves: [TempMove] = []
        do {
            for record in bundle.records {
                let blind = URL(fileURLWithPath: record.finalPath)
                let original = URL(fileURLWithPath: record.originalPath)
                let temp = blind.deletingLastPathComponent().appendingPathComponent(".restore_tmp_\(UUID().uuidString)")
                try FileManager.default.moveItem(at: blind, to: temp)
                tempMoves.append(TempMove(temp: temp, targetOriginal: original))
            }
            for move in tempMoves {
                try FileManager.default.moveItem(at: move.temp, to: move.targetOriginal)
            }
        } catch {
            for move in tempMoves.reversed() {
                if FileManager.default.fileExists(atPath: move.temp.path) { continue }
                if FileManager.default.fileExists(atPath: move.targetOriginal.path) {
                    try? FileManager.default.moveItem(at: move.targetOriginal, to: move.temp)
                }
            }
            throw BlinderError.message(error.localizedDescription)
        }
    }
}

@MainActor
final class BlinderStore: ObservableObject {
    private enum PersistKey {
        static let mode = "blinder.settings.mode"
        static let namingStrategy = "blinder.settings.namingStrategy"
        static let namingPrefix = "blinder.settings.namingPrefix"
        static let namingSuffix = "blinder.settings.namingSuffix"
        static let namingStartNumber = "blinder.settings.namingStartNumber"
        static let randomCharset = "blinder.settings.randomCharset"
        static let randomLength = "blinder.settings.randomLength"
        static let showOriginalNames = "blinder.settings.showOriginalNames"
        static let csvExportMode = "blinder.settings.csvExportMode"
        static let integrityCheckEnabled = "blinder.settings.integrityCheckEnabled"
    }

    private let defaults = UserDefaults.standard
    private let scanner = BlinderFileScanner()
    private let planner = BlinderRenamePlanner()
    private let executor = BlinderRenameExecutor()
    private let mappingStore = BlinderMappingStore()
    private let restoreService = BlinderRestoreService()

    @Published var sourceFolderURL: URL?
    @Published var destinationFolderURL: URL?
    @Published var mappingOutputURL: URL?
    @Published var mode: BlinderRenameMode = .inPlace {
        didSet { defaults.set(mode.rawValue, forKey: PersistKey.mode) }
    }
    @Published var namingStrategy: BlinderNamingStrategy = .randomToken {
        didSet { defaults.set(namingStrategy.rawValue, forKey: PersistKey.namingStrategy) }
    }
    @Published var namingPrefix = "" {
        didSet { defaults.set(namingPrefix, forKey: PersistKey.namingPrefix) }
    }
    @Published var namingSuffix = "" {
        didSet { defaults.set(namingSuffix, forKey: PersistKey.namingSuffix) }
    }
    @Published var namingStartNumber = 1 {
        didSet { defaults.set(namingStartNumber, forKey: PersistKey.namingStartNumber) }
    }
    @Published var randomCharset: BlinderRandomCharset = .lettersAndDigits {
        didSet { defaults.set(randomCharset.rawValue, forKey: PersistKey.randomCharset) }
    }
    @Published var randomLength = 10 {
        didSet { defaults.set(randomLength, forKey: PersistKey.randomLength) }
    }
    @Published var csvExportMode: BlinderCSVExportMode = .namesOnly {
        didSet { defaults.set(csvExportMode.rawValue, forKey: PersistKey.csvExportMode) }
    }
    @Published var integrityCheckEnabled = true {
        didSet { defaults.set(integrityCheckEnabled, forKey: PersistKey.integrityCheckEnabled) }
    }
    @Published var showOriginalNames = false {
        didSet { defaults.set(showOriginalNames, forKey: PersistKey.showOriginalNames) }
    }
    @Published var files: [BlinderSelectableFile] = []
    @Published var currentPlan: BlinderRenamePlan?
    @Published var restoreBundle: BlinderMappingBundle?
    @Published var restorePreview: [BlinderRestorePreviewItem] = []
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published var actionAlert: BlinderActionAlert?

    init() {
        if let raw = defaults.string(forKey: PersistKey.mode), let parsed = BlinderRenameMode(rawValue: raw) {
            mode = parsed
        }
        if let raw = defaults.string(forKey: PersistKey.namingStrategy), let parsed = BlinderNamingStrategy(rawValue: raw) {
            namingStrategy = parsed
        }
        namingPrefix = defaults.string(forKey: PersistKey.namingPrefix) ?? ""
        namingSuffix = defaults.string(forKey: PersistKey.namingSuffix) ?? ""
        let storedStart = defaults.integer(forKey: PersistKey.namingStartNumber)
        namingStartNumber = max(1, storedStart == 0 ? 1 : storedStart)
        if let raw = defaults.string(forKey: PersistKey.randomCharset), let parsed = BlinderRandomCharset(rawValue: raw) {
            randomCharset = parsed
        }
        let storedRandomLength = defaults.integer(forKey: PersistKey.randomLength)
        randomLength = max(4, storedRandomLength == 0 ? 10 : storedRandomLength)
        if let raw = defaults.string(forKey: PersistKey.csvExportMode), let parsed = BlinderCSVExportMode(rawValue: raw) {
            csvExportMode = parsed
        }
        integrityCheckEnabled = defaults.object(forKey: PersistKey.integrityCheckEnabled) as? Bool ?? true
        showOriginalNames = defaults.object(forKey: PersistKey.showOriginalNames) as? Bool ?? false
    }

    var selectedCount: Int {
        files.filter(\.selected).count
    }

    var outputLines: [String] {
        var lines: [String] = []
        lines.append("Status: \(statusMessage)")
        if let errorMessage { lines.append("Error: \(errorMessage)") }
        if let currentPlan {
            lines.append("Dry run: \(currentPlan.items.count) files planned")
            for item in currentPlan.items.prefix(30) {
                lines.append("Rename: \(item.sourceURL.lastPathComponent) -> \(item.finalURL.lastPathComponent)")
            }
            if currentPlan.items.count > 30 {
                lines.append("... \(currentPlan.items.count - 30) more entries")
            }
        } else {
            lines.append("Dry run: none")
        }
        if restorePreview.isEmpty {
            lines.append("Restore preview: none")
        } else {
            let okCount = restorePreview.filter { $0.canRestore }.count
            lines.append("Restore preview: \(okCount) OK, \(restorePreview.count - okCount) blocked")
        }
        return lines
    }

    var dryRunPreview: [BlinderDryRunPreviewItem] {
        guard let currentPlan else { return [] }
        return currentPlan.items.enumerated().map { index, item in
            let original = displayOriginalFileName(item.sourceURL.lastPathComponent, index: index + 1)
            let target = item.finalURL.lastPathComponent
            return BlinderDryRunPreviewItem(
                id: "\(index)-\(target)",
                originalDisplayName: original,
                newName: target
            )
        }
    }

    func setSourceFolder(_ url: URL) {
        sourceFolderURL = url
        if mappingOutputURL == nil {
            mappingOutputURL = url
        }
        if mode == .inPlace {
            mappingOutputURL = url
        }
        reloadFiles()
    }

    func setDestinationFolder(_ url: URL) {
        destinationFolderURL = url
        if mode == .copyThenRename {
            mappingOutputURL = url
        }
        statusMessage = "Target folder selected."
        errorMessage = nil
    }

    func syncAutomaticMappingFolder() {
        switch mode {
        case .inPlace:
            mappingOutputURL = sourceFolderURL
        case .copyThenRename:
            mappingOutputURL = destinationFolderURL
        }
    }

    func reloadFiles() {
        guard let sourceFolderURL else {
            fail("Please choose a source folder first.")
            return
        }
        do {
            let urls = try scanner.listFiles(in: sourceFolderURL, imageOnly: true)
            files = urls.map { BlinderSelectableFile(url: $0, selected: true) }
            statusMessage = "\(files.count) files loaded."
            errorMessage = nil
        } catch {
            fail(error.localizedDescription)
        }
    }

    func setAllFiles(selected: Bool) {
        files = files.map { BlinderSelectableFile(url: $0.url, selected: selected) }
    }

    func setFileSelection(fileID: UUID, isSelected: Bool) {
        files = files.map { file in
            guard file.id == fileID else { return file }
            return BlinderSelectableFile(url: file.url, selected: isSelected)
        }
    }

    func displayName(for file: BlinderSelectableFile, index: Int) -> String {
        displayOriginalFileName(file.url.lastPathComponent, index: index)
    }

    private func displayOriginalFileName(_ originalName: String, index: Int) -> String {
        if showOriginalNames {
            return originalName
        }
        return "File \(index) ••••••••"
    }

    func createDryRun() {
        guard let sourceFolderURL else {
            fail("Please choose a source folder first.")
            return
        }
        do {
            try scanner.assertWritable(sourceFolderURL)
            if mode == .copyThenRename, let destinationFolderURL {
                try scanner.assertWritable(destinationFolderURL)
            }
            syncAutomaticMappingFolder()
            currentPlan = try planner.createPlan(
                selectedFiles: files.filter(\.selected).map(\.url),
                sourceFolderURL: sourceFolderURL,
                destinationFolderURL: destinationFolderURL,
                mode: mode,
                namingStrategy: namingStrategy,
                namingPrefix: namingPrefix,
                namingSuffix: namingSuffix,
                namingStartNumber: namingStartNumber,
                randomCharset: randomCharset,
                randomLength: randomLength
            )
            statusMessage = "Dry run successful."
            errorMessage = nil
            showSuccessAlert(title: "Dry run complete", message: "Preview updated successfully.")
        } catch {
            fail(error.localizedDescription)
        }
    }

    func executeRename() {
        guard let plan = currentPlan else {
            fail("Please run a dry run first.")
            return
        }
        guard let mappingRoot = mappingOutputURL ?? sourceFolderURL else {
            fail("No mapping folder available.")
            return
        }
        do {
            let records = try executor.execute(plan: plan, integrityCheckEnabled: integrityCheckEnabled)
            let mappingPaths = try mappingStore.createRunFolder(in: mappingRoot)
            let metadata = BlinderRunMetadata(
                runID: mappingPaths.runFolder.lastPathComponent,
                mode: plan.mode,
                sourceFolder: plan.sourceFolderURL.path,
                destinationFolder: plan.destinationFolderURL?.path,
                createdAt: Date(),
                fileCount: records.count,
                namingStrategy: plan.namingStrategy,
                namingPrefix: plan.namingPrefix,
                namingSuffix: plan.namingSuffix,
                namingStartNumber: plan.namingStartNumber,
                randomCharset: plan.randomCharset,
                randomLength: plan.randomLength,
                csvExportMode: csvExportMode,
                integrityCheckEnabled: integrityCheckEnabled
            )
            try mappingStore.save(
                bundle: BlinderMappingBundle(metadata: metadata, records: records),
                at: mappingPaths,
                csvExportMode: csvExportMode
            )
            if integrityCheckEnabled {
                let passedCount = records.filter { $0.integrityCheckPassed == true }.count
                statusMessage = "Rename completed. Integrity: \(passedCount)/\(records.count) passed. Mapping: \(mappingPaths.runFolder.path)"
            } else {
                statusMessage = "Rename completed. Mapping: \(mappingPaths.runFolder.path)"
            }
            errorMessage = nil
            currentPlan = nil
            reloadFiles()
            if integrityCheckEnabled {
                let passedCount = records.filter { $0.integrityCheckPassed == true }.count
                showSuccessAlert(
                    title: "Rename complete",
                    message: "Files were renamed successfully. SHA-256 integrity check passed for \(passedCount)/\(records.count) files."
                )
            } else {
                showSuccessAlert(title: "Rename complete", message: "Files were renamed successfully.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func loadMappingBundle(from jsonURL: URL) {
        do {
            restoreBundle = try mappingStore.load(bundleFrom: jsonURL)
            statusMessage = "Mapping loaded."
            errorMessage = nil
            showSuccessAlert(title: "Mapping loaded", message: "mapping.json was loaded successfully.")
        } catch {
            fail(error.localizedDescription)
        }
    }

    func dryRunRestore() {
        guard let restoreBundle else {
            fail("Please load mapping.json first.")
            return
        }
        restorePreview = restoreService.dryRun(bundle: restoreBundle)
        statusMessage = "Restore dry run generated."
        errorMessage = nil
        showSuccessAlert(title: "Restore dry run complete", message: "Restore preview was generated successfully.")
    }

    func executeRestore() {
        guard let restoreBundle else {
            fail("Please load mapping.json first.")
            return
        }
        do {
            try restoreService.executeRestore(bundle: restoreBundle)
            statusMessage = "Restore completed."
            errorMessage = nil
            restorePreview = []
            if sourceFolderURL != nil {
                reloadFiles()
            }
            showSuccessAlert(title: "Restore complete", message: "Original file names were restored successfully.")
        } catch {
            fail(error.localizedDescription)
        }
    }

    func chooseFolderPanel(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseJSONPanel(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func fail(_ message: String) {
        errorMessage = message
        statusMessage = "Error"
        actionAlert = BlinderActionAlert(
            title: "Action failed",
            message: message
        )
    }

    private func showSuccessAlert(title: String, message: String) {
        actionAlert = BlinderActionAlert(
            title: title,
            message: message
        )
    }
}
