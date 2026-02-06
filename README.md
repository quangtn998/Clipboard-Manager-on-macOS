# Clipboard Manager on macOS

Ứng dụng quản lý lịch sử clipboard gọn nhẹ cho macOS (SwiftUI).

## Tính năng

- Theo dõi clipboard theo thời gian thực.
- Lưu lịch sử nhiều định dạng: text, URL, RTF, HTML, ảnh (TIFF), file path.
- Ghim (pin) nội dung quan trọng.
- Tìm kiếm nhanh trong lịch sử clipboard.
- Copy lại nội dung chỉ với một nút bấm.
- Hỗ trợ cả cửa sổ chính và menu bar extra.

## Yêu cầu

- macOS 13+
- Xcode 15+ hoặc Swift 5.9+

## Chạy ứng dụng (local)

```bash
swift run
```

> Lưu ý: trong môi trường Linux/CI sẽ không build được do thiếu framework Apple `SwiftUI`.

---


## Định dạng clipboard hỗ trợ

- **Text** (`public.utf8-plain-text`)
- **URL**
- **RTF**
- **HTML**
- **Image** (TIFF từ pasteboard)
- **Files** (danh sách file/folder path)

Khi bấm copy lại từ lịch sử, app sẽ ghi lại đúng định dạng tương ứng lên clipboard.

---

## Build release macOS (Universal .app + DMG kéo-thả)

Script `scripts/release-macos.sh` sẽ:

1. Build 2 binary `arm64` và `x86_64`.
2. Dùng `lipo` để tạo **universal binary** trong `.app`.
3. Tạo `ClipboardManager.app`.
4. Tạo `ClipboardManager-<version>.dmg` có shortcut `Applications`.

### Build nhanh (ad-hoc signing)

```bash
./scripts/release-macos.sh <version> <build>
```

Ví dụ:

```bash
./scripts/release-macos.sh 1.0.0 1
```

Artifact nằm ở thư mục `dist/`:

- `dist/ClipboardManager.app`
- `dist/ClipboardManager-1.0.0.dmg`

### Build với Developer ID signing

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/release-macos.sh 1.0.0 1
```

### Build + Notarize

Chuẩn bị biến môi trường:

- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY` (base64 của file `.p8`)

Rồi chạy:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
APPLE_API_KEY_ID="..." \
APPLE_API_ISSUER_ID="..." \
APPLE_API_PRIVATE_KEY="..." \
./scripts/release-macos.sh 1.0.0 1
```

---

## GitHub Actions tự build khi tạo tag release

Workflow: `.github/workflows/release-macos.yml`

Khi push tag `v*` (ví dụ `v1.0.0`), workflow sẽ:

- build universal app,
- tạo DMG drag-and-drop,
- upload `.dmg` vào GitHub Release,
- tự notarize nếu đủ secret.

### Secrets cần cấu hình

Bắt buộc (để build ad-hoc):
- Không cần secret.

Tuỳ chọn ký Developer ID:
- `MACOS_SIGN_IDENTITY`
- `MACOS_CERT_P12_BASE64`
- `MACOS_CERT_PASSWORD`
- `KEYCHAIN_PASSWORD`

Tuỳ chọn notarize:
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY` (base64 `.p8`)
### 2) Phát hành trên GitHub Releases

1. Tạo tag version (ví dụ `v1.0.0`).
2. Tạo Release tương ứng trên GitHub.
3. Upload file `.dmg` trong `dist/` vào phần Assets.

Người dùng cuối chỉ cần:

1. Tải file `.dmg`.
2. Mở file.
3. Kéo `ClipboardManager.app` vào `Applications`.

### 3) Lưu ý khi phát hành công khai

Hiện script dùng **ad-hoc signing** (`codesign --sign -`) để tiện test nội bộ.
Nếu muốn phân phối rộng rãi (ít cảnh báo bảo mật hơn), bạn nên:

- Ký bằng chứng chỉ **Developer ID Application**.
- Notarize với Apple trước khi upload release.

---

## Cấu trúc chính

- `Sources/ClipboardManagerApp/ClipboardManagerApp.swift`: UI chính, menu bar, danh sách clipboard.
- `Sources/ClipboardManagerApp/ClipboardStore.swift`: logic theo dõi pasteboard, lọc, ghim, lưu file.
- `Sources/ClipboardManagerApp/ClipboardItem.swift`: model dữ liệu clipboard.
- `scripts/release-macos.sh`: build universal app bundle + tạo DMG kéo-thả.
- `.github/workflows/release-macos.yml`: CI build release khi push tag.

## Dữ liệu lưu ở đâu?

Lịch sử clipboard được lưu tại:

`~/Library/Application Support/ClipboardManagerApp/history.json`
