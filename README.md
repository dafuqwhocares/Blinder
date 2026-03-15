# Blinder App

Blinder App is a native macOS tool for **safe file-name anonymization** in blinded review workflows.
It renames files to non-identifiable names, creates a mapping for later restoration, and provides integrity options to increase trust and traceability.

## Why This App

In research and review processes, file names can unintentionally reveal identity or sequence context.
Blinder App helps teams run blinded evaluations while preserving a controlled path back to original file names.

## Core Features

- **Blind / Unblind workflow**
  - Blind: anonymize selected files
  - Unblind: restore original names from `mapping.json`
- **Two rename modes**
  - Rename in source folder
  - Copy then rename into target folder
- **Test run preview**
  - Preview planned rename results before applying changes
- **Selectable naming schemes**
  - Random token
  - Sequential numbers (with randomized file processing order to avoid predictable mapping from list order)
- **Custom naming options**
  - Prefix / suffix
  - Start number (sequential mode)
  - Character set and token length (random mode)
- **Mapping output**
  - JSON mapping for restore
  - CSV export modes:
    - names only (`originalName`, `blindedName`)
    - full audit columns
- **SHA-256 integrity check (optional)**
  - Computes hashes before and after rename
  - Stores integrity values in mapping metadata
  - Provides result feedback after run
- **Persistent settings**
  - Naming defaults, privacy, output/integrity preferences
- **Native macOS UI**
  - Sidebar navigation, toolbar actions, status bar menu, About dialog

## Safety & Data Handling

- Uses a careful rename/restore flow designed to reduce risk.
- Supports dry/test runs before final actions.
- Stores mapping data for reliable restore.
- Optional hash verification improves confidence that file contents are unchanged.

> Note: Always validate on test data first, especially on network-mounted folders and large batches.

## Requirements

- macOS 13+
- Swift 6 toolchain / Xcode Command Line Tools

## Run in Development

```bash
swift run
```

## Build (Release)

```bash
swift build -c release
```

Output binary:

- `.build/release/BlinderApp`

## Build Signed arm64 Binary

```bash
./build-arm64-signed.sh
```

Output:

- `dist/BlinderApp-arm64`

## Package as `.app` (arm64, signed)

```bash
./package-app-arm64.sh
```

Output:

- `dist/Blinder App.app`

## Typical Workflow

1. Open **Blind** tab
2. Choose source folder
3. Select files
4. Configure naming and mode
5. Run **Test run**
6. Review preview
7. Run **Blind!**
8. Keep generated mapping files for future **Unblind!**
