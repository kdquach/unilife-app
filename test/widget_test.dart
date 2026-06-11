import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilife_mobile/app.dart';

void main() {
  testWidgets('UniLife app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const UniLifeApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
