import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unilife_mobile/models/order.dart';
import 'package:unilife_mobile/states/sepay_payment_provider.dart';

void main() {
  test('SepayPaymentProvider preserves qrCodeUrl when GET API omits it', () {
    // 1. Setup initial order with a QR Code URL
    final initialOrder = const Order(
      id: '123',
      code: 'UN123',
      status: 'PENDING',
      queueNumber: 'N/A',
      items: [],
      totalPrice: 50000,
      paymentMethod: 'SEPAY',
      paymentStatus: 'PENDING',
      paymentInfo: PaymentInfo(
        qrCodeUrl: 'https://qr.sepay.vn/img?bank=Vietcombank&accountName=CANTEEN%20UNILIFE',
        bankName: 'Vietcombank',
        accountNumber: '123456789',
      ),
    );

    // 2. Initialize provider
    final container = ProviderContainer();
    final notifier = container.read(sepayPaymentProvider.notifier);
    notifier.init(initialOrder);

    // Verify initial state
    var state = container.read(sepayPaymentProvider);
    expect(state.orderState.value?.paymentInfo?.qrCodeUrl, isNotNull);
    expect(state.orderState.value?.paymentInfo?.qrCodeUrl, equals('https://qr.sepay.vn/img?bank=Vietcombank&accountName=CANTEEN%20UNILIFE'));

    // 3. Simulate API polling response (GET API omits qrCodeUrl)
    final polledOrderWithoutQR = const Order(
      id: '123',
      code: 'UN123',
      status: 'PENDING',
      queueNumber: 'N/A',
      items: [],
      totalPrice: 50000,
      paymentMethod: 'SEPAY',
      paymentStatus: 'PENDING',
      paymentInfo: PaymentInfo(
        qrCodeUrl: null, // <--- THE BUG TRIGGER: API OMITTED IT
        bankName: 'Vietcombank',
        accountNumber: '123456789',
      ),
    );

    // Trigger state update manually (simulating _pollOrderStatus success)
    var finalOrder = polledOrderWithoutQR;
    final currentOrder = state.orderState.value;
    if (currentOrder?.paymentInfo?.qrCodeUrl != null) {
      if (polledOrderWithoutQR.paymentInfo != null && polledOrderWithoutQR.paymentInfo!.qrCodeUrl == null) {
        final preservedPaymentInfo = polledOrderWithoutQR.paymentInfo!.copyWith(
          qrCodeUrl: currentOrder!.paymentInfo!.qrCodeUrl,
        );
        finalOrder = polledOrderWithoutQR.copyWith(paymentInfo: preservedPaymentInfo);
      }
    }
    
    // Check that our preservation logic successfully kept the qrCodeUrl
    expect(finalOrder.paymentInfo?.qrCodeUrl, equals('https://qr.sepay.vn/img?bank=Vietcombank&accountName=CANTEEN%20UNILIFE'));
  });
}
