# UniLife Mobile Flutter

Flutter FE scaffold cho app mobile UniLife, dựng theo bộ màn hình tĩnh đã chốt:

- Menu Food: món theo thực đơn ngày, dùng `menuScheduleItemId`, có số suất còn lại.
- Always Available Food: nước, bánh, kem, snack bán hằng ngày, dùng `foodId`, có stock/in-stock.

## Cách chạy

```bash
flutter pub get
flutter run
```

Nếu bạn giải nén vào một thư mục chưa có native folders Android/iOS, chạy:

```bash
flutter create .
flutter pub get
flutter run
```

Sau này chỉ cần thay service mock trong `lib/services` bằng API thật từ NodeJS/Express backend.

## Cấu trúc chính

```txt
lib/
├── main.dart
├── app.dart
├── core/
├── models/
├── data/
├── routes/
├── services/
├── widgets/
└── screens/
```
