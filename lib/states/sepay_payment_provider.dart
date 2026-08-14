import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../services/order_service.dart';
import '../services/auth_storage.dart';

class SepayPaymentState {
  final AsyncValue<Order?> orderState;
  final int remainingSeconds;
  final String? errorMessage;
  final String? warningMessage;

  const SepayPaymentState({
    this.orderState = const AsyncData(null),
    this.remainingSeconds = 900,
    this.errorMessage,
    this.warningMessage,
  });

  SepayPaymentState copyWith({
    AsyncValue<Order?>? orderState,
    int? remainingSeconds,
    String? errorMessage,
    String? warningMessage,
    bool clearError = false,
    bool clearWarning = false,
  }) {
    return SepayPaymentState(
      orderState: orderState ?? this.orderState,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      warningMessage: clearWarning ? null : (warningMessage ?? this.warningMessage),
    );
  }
}

class SepayPaymentNotifier extends Notifier<SepayPaymentState> {
  final _orderService = OrderService(ApiClient());
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  String? _orderId;

  @override
  SepayPaymentState build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
      _countdownTimer?.cancel();
    });

    return const SepayPaymentState();
  }

  void init(Order order) {
    _orderId = order.id;

    int remaining = 900;
    if (order.expiresAt != null) {
      remaining = order.expiresAt!.difference(DateTime.now()).inSeconds;
      if (remaining < 0) remaining = 0;
    }
    
    state = SepayPaymentState(
      orderState: AsyncData(order),
      remainingSeconds: remaining,
    );

    _startCountdown();
    _startPolling();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        timer.cancel();
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _pollOrderStatus();
    });
  }

  Future<void> _pollOrderStatus() async {
    if (_orderId == null) return;
    try {
      final token = await AuthStorage.getToken();
      final updatedOrder = await _orderService.getOrderById(_orderId!, token: token);

      String? errorMessage;
      String? warningMessage;
      
      final isSuccess = updatedOrder.status == 'CONFIRMED' || updatedOrder.paymentStatus == 'PAID';

      final note = updatedOrder.note ?? "";
      if (!isSuccess) {
        if (note.contains("Error: Invalid payment amount")) {
          errorMessage = "You have transferred the incorrect amount. The order is not confirmed, please transfer the correct amount to confirm the order!";
        } else if (updatedOrder.paymentStatus == 'REFUND_PENDING') {
          errorMessage = "The system received a late payment after the order was cancelled. Please show this screen to the Admin to get your money back.";
        }
      }
      
      if (note.contains("[DUPLICATE_PAYMENT]") || note.contains("[EXTRA_PAYMENT]")) {
        warningMessage = "The system detected that you overpaid for this order. Please contact the Canteen Admin to get a refund for the excess amount!";
      }

      if (updatedOrder.status == 'CONFIRMED' || updatedOrder.status == 'CANCELLED' || updatedOrder.paymentStatus == 'EXPIRED') {
        _stopTimers();
      }

      var finalOrder = updatedOrder;
      // Preserve the qrCodeUrl because the GET API omits it (returns null)
      final currentOrder = state.orderState.value;
      if (currentOrder?.paymentInfo?.qrCodeUrl != null) {
        if (updatedOrder.paymentInfo != null && updatedOrder.paymentInfo!.qrCodeUrl == null) {
          final preservedPaymentInfo = updatedOrder.paymentInfo!.copyWith(
            qrCodeUrl: currentOrder!.paymentInfo!.qrCodeUrl,
          );
          finalOrder = updatedOrder.copyWith(paymentInfo: preservedPaymentInfo);
        } else if (updatedOrder.paymentInfo == null) {
          final preservedPaymentInfo = PaymentInfo(qrCodeUrl: currentOrder!.paymentInfo!.qrCodeUrl);
          finalOrder = updatedOrder.copyWith(paymentInfo: preservedPaymentInfo);
        }
      }

      state = state.copyWith(
        orderState: AsyncData(finalOrder),
        errorMessage: errorMessage,
        warningMessage: warningMessage,
        clearError: errorMessage == null,
        clearWarning: warningMessage == null,
      );
    } catch (e, st) {
      // Ignore
    }
  }

  void _stopTimers() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
  }
}

final sepayPaymentProvider = NotifierProvider<SepayPaymentNotifier, SepayPaymentState>(() {
  return SepayPaymentNotifier();
});
