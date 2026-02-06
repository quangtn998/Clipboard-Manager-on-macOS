# Clipboard Manager on macOS

A lightweight clipboard history manager for macOS (SwiftUI).

## Download

Get the latest release here:

https://github.com/quangtn998/Clipboard-Manager-on-macOS/releases

Download the `.dmg` file (for example, `ClipboardManager-<version>.dmg`) and open it to install.

## Features

- Real-time clipboard monitoring.
- Multi-format history: text, URL, RTF, HTML, images (TIFF), file paths.
- Pin important items.
- Fast search across clipboard history.
- One-click re-copy to the clipboard.
- Main window + menu bar extra.

## Requirements

- macOS 13+
- Xcode 15+ or Swift 5.9+

## Run locally

```bash
swift run
```

> Note: Linux/CI environments will not build due to missing Apple `SwiftUI` frameworks.

---


## Supported clipboard formats

- **Text** (`public.utf8-plain-text`)
- **URL**
- **RTF**
- **HTML**
- **Image** (TIFF from the pasteboard)
- **Files** (list of file/folder paths)

When you re-copy an item from history, the app writes the correct corresponding format back to the clipboard.

---

## Build macOS release (Universal .app + drag-and-drop DMG)

The `scripts/release-macos.sh` script will:

1. Build `arm64` and `x86_64` binaries.
2. Use `lipo` to create a **universal binary** inside the `.app`.
3. Create `ClipboardManager.app`.
4. Create `ClipboardManager-<version>.dmg` with an `Applications` shortcut.

### Quick build (ad-hoc signing)

```bash
./scripts/release-macos.sh <version> <build>
```

Example:

```bash
./scripts/release-macos.sh 1.0.0 1
```

Artifacts are saved in `dist/`:

- `dist/ClipboardManager.app`
- `dist/ClipboardManager-1.0.0.dmg`

### Build with Developer ID signing

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/release-macos.sh 1.0.0 1
```

### Build + notarize

Prepare environment variables:

- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY` (base64 of the `.p8` file)

Then run:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
APPLE_API_KEY_ID="..." \
APPLE_API_ISSUER_ID="..." \
APPLE_API_PRIVATE_KEY="..." \
./scripts/release-macos.sh 1.0.0 1
```

---

## GitHub Actions build on tag release

Workflow: `.github/workflows/release-macos.yml`

When you push a `v*` tag (for example, `v1.0.0`), the workflow will:

- build a universal app,
- create a drag-and-drop DMG,
- upload the `.dmg` to GitHub Releases,
- notarize automatically if secrets are provided.

### Required secrets

Required (for ad-hoc build):
- None.

Optional for Developer ID signing:
- `MACOS_SIGN_IDENTITY`
- `MACOS_CERT_P12_BASE64`
- `MACOS_CERT_PASSWORD`
- `KEYCHAIN_PASSWORD`

Optional for notarization:
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY` (base64 `.p8`)

---

## Project structure

- `Sources/ClipboardManagerApp/ClipboardManagerApp.swift`: main UI, menu bar, clipboard list.
- `Sources/ClipboardManagerApp/ClipboardStore.swift`: pasteboard monitoring, filtering, pinning, persistence.
- `Sources/ClipboardManagerApp/ClipboardItem.swift`: clipboard data model.
- `scripts/release-macos.sh`: build universal app bundle + DMG.
- `.github/workflows/release-macos.yml`: CI release build on tag push.

## Where is data stored?

Clipboard history is stored at:

`~/Library/Application Support/ClipboardManagerApp/history.json`
