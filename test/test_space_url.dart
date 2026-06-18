import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test Image.network with space in URL', (WidgetTester tester) async {
    final url = "https://qr.sepay.vn/img?bank=Vietcombank&accountName=CANTEEN UNILIFE";

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Image.network(url),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
