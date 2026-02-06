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

## Chạy ứng dụng

```bash
swift run
```

> Lưu ý: khi chạy bằng `swift run`, ứng dụng vẫn là app macOS dùng SwiftUI. Bạn có thể mở package này bằng Xcode để build/sign đầy đủ như một desktop app.

## Cấu trúc chính

- `Sources/ClipboardManagerApp/ClipboardManagerApp.swift`: UI chính, menu bar, danh sách clipboard.
- `Sources/ClipboardManagerApp/ClipboardStore.swift`: logic theo dõi pasteboard, lọc, ghim, lưu file.
- `Sources/ClipboardManagerApp/ClipboardItem.swift`: model dữ liệu clipboard.

## Dữ liệu lưu ở đâu?

Lịch sử clipboard được lưu tại:

`~/Library/Application Support/ClipboardManagerApp/history.json`

