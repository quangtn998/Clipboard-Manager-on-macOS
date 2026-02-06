# Clipboard Manager on macOS

Ứng dụng quản lý lịch sử clipboard gọn nhẹ cho macOS (SwiftUI).

## Tính năng

- Theo dõi clipboard theo thời gian thực.
- Lưu lịch sử nội dung text (mặc định tối đa 120 mục).
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

## Build bản release để kéo-thả cài đặt

Repository đã có sẵn script tạo installer drag-and-drop:

- `ClipboardManager.app`
- `ClipboardManager-<version>.dmg` (mở DMG rồi kéo app vào `Applications`)

### 1) Tạo artifact release

```bash
./scripts/release-macos.sh <version> <build>
```

Ví dụ:

```bash
./scripts/release-macos.sh 1.0.0 1
```

Artifact được tạo trong thư mục `dist/`:

- `dist/ClipboardManager.app`
- `dist/ClipboardManager-1.0.0.dmg`

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
- `scripts/release-macos.sh`: build app bundle + tạo DMG cài đặt kéo-thả.

## Dữ liệu lưu ở đâu?

Lịch sử clipboard được lưu tại:

`~/Library/Application Support/ClipboardManagerApp/history.json`
