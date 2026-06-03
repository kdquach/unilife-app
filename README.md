# UniLife Mobile Flutter

Flutter FE scaffold cho app mobile UniLife, dựng theo bộ màn hình tĩnh đã chốt:

- Menu Food: món theo thực đơn ngày, dùng `menuScheduleItemId`, có số suất còn lại.
- Always Available Food: nước, bánh, kem, snack bán hằng ngày, dùng `foodId`, có stock/in-stock.

## Cách chạy

```bash
flutter pub get
flutter run
```

## Kết nối backend

API base URL được cấu hình qua biến môi trường `API_BASE_URL` khi chạy app:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1
```

Gợi ý:

- Android emulator: `http://10.0.2.2:5000/api/v1`
- iOS simulator / web local: `http://localhost:5000/api/v1`
- Thiết bị thật: dùng IP LAN của máy chạy backend (VD `http://192.168.1.10:5000/api/v1`)

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
