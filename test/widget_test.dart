import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilife_mobile/app.dart';

void main() {
  testWidgets('App starts and displays splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UniLifeApp());

    // Verify that MaterialApp is mounted successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
