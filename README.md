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

> Lưu ý: khi chạy bằng `swift run`, ứng dụng vẫn là app macOS dùng SwiftUI. Bạn có thể mở package này bằng Xcode để build/sign đầy đủ như một desktop app.

## Build bản release để kéo-thả cài đặt

Script đã được thêm sẵn để tạo:

1. `ClipboardManager.app`
2. `ClipboardManager-<version>.dmg` (mở ra và kéo app vào `Applications` để cài)

### Lệnh build

```bash
./scripts/release-macos.sh <version> <build>
```

Ví dụ:

```bash
./scripts/release-macos.sh 1.0.0 1
```

Artifact nằm trong thư mục `dist/`.

### Đẩy lên GitHub Releases

- Upload file `.dmg` trong `dist/` vào phần **Releases**.
- Người dùng cuối chỉ cần tải `.dmg`, mở file và kéo-thả app vào `Applications`.

## Cấu trúc chính

- `Sources/ClipboardManagerApp/ClipboardManagerApp.swift`: UI chính, menu bar, danh sách clipboard.
- `Sources/ClipboardManagerApp/ClipboardStore.swift`: logic theo dõi pasteboard, lọc, ghim, lưu file.
- `Sources/ClipboardManagerApp/ClipboardItem.swift`: model dữ liệu clipboard.
- `scripts/release-macos.sh`: build app bundle + tạo DMG cài đặt kéo-thả.

## Dữ liệu lưu ở đâu?

Lịch sử clipboard được lưu tại:

`~/Library/Application Support/ClipboardManagerApp/history.json`
