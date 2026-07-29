# UniLife Mobile Flutter

Flutter FE scaffold for UniLife mobile app, built according to the approved static screens:

- Menu Food: daily menu items, uses `menuScheduleItemId`, with remaining stock count.
- Always Available Food: drinks, cakes, ice cream, snacks sold daily, uses `foodId`, with stock/in-stock status.

## How to run

```bash
flutter pub get
flutter run
```

## Connecting to backend

The API base URL is configured via the environment variable `API_BASE_URL` when running the app:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1
```

Suggestions:

- Android emulator: `http://10.0.2.2:5000/api/v1`
- iOS simulator / web local: `http://localhost:5000/api/v1`
- Real device: use the LAN IP of the machine running the backend (e.g. `http://192.168.1.10:5000/api/v1`)

If you extract this into a folder without native Android/iOS folders, run:

```bash
flutter create .
flutter pub get
flutter run
```

Later, simply replace the mock services in `lib/services` with real APIs from the NodeJS/Express backend.

## Main Structure

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
