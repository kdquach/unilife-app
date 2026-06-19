import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilife_mobile/models/order.dart';
import 'package:unilife_mobile/screens/payment/widgets/sepay_success_view.dart';

void main() {
  testWidgets('SepaySuccessView renders success UI correctly without warnings', (WidgetTester tester) async {
    final mockOrder = Order(
      id: 'order_1',
      code: '234199',
      status: 'CONFIRMED',
      queueNumber: 'A12',
      items: [],
      totalPrice: 55000,
      paymentMethod: 'SEPAY',
      paymentStatus: 'PAID',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SepaySuccessView(order: mockOrder),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // finish animation

    expect(find.text('Payment Successful!'), findsOneWidget);
    expect(find.text('Hooray! Your order has been placed successfully.'), findsOneWidget);
    expect(find.text('Order Number'), findsOneWidget);
    expect(find.text('#234199'), findsOneWidget);
  });

  testWidgets('SepaySuccessView displays warning and error messages when provided', (WidgetTester tester) async {
    final mockOrder = Order(
      id: 'order_1',
      code: '234199',
      status: 'CONFIRMED',
      queueNumber: 'A12',
      items: [],
      totalPrice: 55000,
      paymentMethod: 'SEPAY',
      paymentStatus: 'PAID',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SepaySuccessView(
            order: mockOrder,
            warningMessage: 'The system detected that you overpaid for this order.',
            errorMessage: 'Test error message.',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // finish animation

    // Verify warning and error are visible
    expect(find.text('The system detected that you overpaid for this order.'), findsOneWidget);
    expect(find.text('Test error message.'), findsOneWidget);
    
    // Verify icons are present
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });
}
