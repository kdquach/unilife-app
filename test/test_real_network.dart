import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = MyHttpOverrides();
  });

  testWidgets('Test real network image load', (WidgetTester tester) async {
    const url = "https://qr.sepay.vn/img?bank=Vietcombank&acc=SBSEPAYJDSCCIHAPKZK&template=compact&amount=55000&des=UN234199&accountName=CANTEENUNILIFE";

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Image(
            image: NetworkImage(url),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 5));

    final image = tester.widget<Image>(find.byType(Image));
    print("Network image widget found!");
  });
}
