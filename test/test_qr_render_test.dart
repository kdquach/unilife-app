import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilife_mobile/models/order.dart';
import 'package:unilife_mobile/screens/payment/widgets/sepay_payment_view.dart';
import 'package:unilife_mobile/states/sepay_payment_provider.dart';

void main() {
  testWidgets('Test rendering of QR Code URL', (WidgetTester tester) async {
    const jsonStr = '''
    {
      "success": true,
      "data": {
        "paymentInfo": {
          "qrCodeUrl": "https://qr.sepay.vn/img?bank=Vietcombank&acc=SBSEPAYJDSCCIHAPKZK&template=compact&amount=55000&des=UN234199&accountName=CANTEENUNILIFE",
          "bankName": "Vietcombank",
          "accountNumber": "SBSEPAYJDSCCIHAPKZK"
        },
        "_id": "667104b2e8a1f72b9c3e4a5d",
        "orderCode": "234199",
        "status": "PENDING",
        "paymentMethod": "SEPAY",
        "paymentStatus": "PENDING",
        "totalPrice": 55000,
        "transferContent": "UN234199",
        "createdAt": "2026-06-18T05:00:00.000Z",
        "expiresAt": "2026-06-18T05:15:00.000Z"
      }
    }
    ''';
    
    // Create an Order object manually to avoid json decoding issues if any
    final order = Order(
      id: "667104b2e8a1f72b9c3e4a5d",
      code: "234199",
      status: "PENDING",
      queueNumber: "A01",
      items: [],
      totalPrice: 55000,
      paymentMethod: "SEPAY",
      paymentStatus: "PENDING",
      paymentInfo: const PaymentInfo(
        qrCodeUrl: "https://qr.sepay.vn/img?bank=Vietcombank&acc=SBSEPAYJDSCCIHAPKZK&template=compact&amount=55000&des=UN234199&accountName=CANTEEN%20UNILIFE",
        bankName: "Vietcombank",
        accountNumber: "SBSEPAYJDSCCIHAPKZK",
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SepayPaymentView(
            state: const SepayPaymentState(),
            currentOrder: order,
            isExpired: false,
            isPolling: true,
          ),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final image = tester.widget<Image>(imageFinder);
    expect(image.image, isA<NetworkImage>());
    final networkImage = image.image as NetworkImage;
    expect(networkImage.url, equals('https://qr.sepay.vn/img?bank=Vietcombank&acc=SBSEPAYJDSCCIHAPKZK&template=compact&amount=55000&des=UN234199&accountName=CANTEEN%20UNILIFE'));
  });
}
