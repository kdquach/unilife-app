import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unilife_mobile/models/order.dart';
import 'package:unilife_mobile/screens/payment/sepay_payment_screen.dart';

void main() {
  testWidgets('SepayPaymentScreen renders QR code, amount, and countdown timer correctly', (WidgetTester tester) async {
    final mockOrder = Order(
      id: 'order_1',
      code: '234199',
      status: 'PENDING',
      queueNumber: 'A12',
      items: [],
      totalPrice: 55000,
      paymentMethod: 'SEPAY',
      paymentStatus: 'PENDING',
      paymentInfo: const PaymentInfo(
        qrCodeUrl: 'https://qr.sepay.vn/img?bank=Vietcombank&acc=SBSEPAYJDSCCIHAPKZK&amount=55000&des=UN234199',
        bankName: 'Vietcombank',
        accountNumber: 'SBSEPAYJDSCCIHAPKZK',
      ),
      transferContent: 'UN234199',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SepayPaymentScreen(order: mockOrder),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('SePay Payment'), findsOneWidget);
    expect(find.textContaining('55'), findsWidgets);
    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('SepayPaymentScreen shows cancel dialog when back button is pressed', (WidgetTester tester) async {
    final mockOrder = Order(
      id: 'order_1',
      code: '234199',
      status: 'PENDING',
      queueNumber: 'A12',
      items: [],
      totalPrice: 55000,
      paymentMethod: 'SEPAY',
      paymentStatus: 'PENDING',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SepayPaymentScreen(order: mockOrder),
        ),
      ),
    );

    await tester.pump(); // allow provider to init
    await tester.pump(const Duration(seconds: 1)); // allow timer to start

    // Tap the back button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 300)); // finish dialog animation

    // Verify dialog appears
    expect(find.text('Payment Incomplete'), findsOneWidget);
    expect(find.text('Pay Later (in My Orders)'), findsOneWidget);
    expect(find.text('Cancel Order & Edit Cart'), findsOneWidget);
  });

  testWidgets('SepayPaymentScreen shows success view when order is paid', (WidgetTester tester) async {
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
      ProviderScope(
        child: MaterialApp(
          home: SepayPaymentScreen(order: mockOrder),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Success View
    expect(find.text('Payment Successful!'), findsOneWidget);
    expect(find.text('Hooray! Your order has been placed successfully.'), findsOneWidget);
    expect(find.text('Track Order'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });
}
