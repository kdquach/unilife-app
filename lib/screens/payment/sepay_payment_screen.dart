import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/order_service.dart';
import '../../states/cart_provider.dart';
import '../../states/sepay_payment_provider.dart';

import 'widgets/sepay_payment_view.dart';
import 'widgets/sepay_success_view.dart';

class SepayPaymentScreen extends ConsumerStatefulWidget {
  static const String routeName = '/sepay-payment';

  final Order order;

  const SepayPaymentScreen({super.key, required this.order});

  @override
  ConsumerState<SepayPaymentScreen> createState() => _SepayPaymentScreenState();
}

class _SepayPaymentScreenState extends ConsumerState<SepayPaymentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sepayPaymentProvider.notifier).init(widget.order);
    });
  }

  Future<void> _handleBackNavigation() async {
    final state = ref.read(sepayPaymentProvider);
    final currentOrder = state.orderState.value ?? widget.order;
    final isSuccess = currentOrder.status == 'CONFIRMED' || currentOrder.paymentStatus == 'PAID';
    
    if (isSuccess) {
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blue, size: 28),
                    SizedBox(width: 12),
                    Text('Payment Incomplete', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your order is waiting for payment. What would you like to do?',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'stay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Stay & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'later'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Pay Later (in My Orders)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel Order & Edit Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == 'later' && mounted) {
      final confirmLater = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Warning'),
          content: const Text('If you pay later, your current cart will be empty as items are moved to this order. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmLater == true && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      }
    } else if (result == 'cancel' && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      try {
        final token = await AuthStorage.getToken();
        await OrderService(ApiClient()).cancelOrder(widget.order.id, token: token);
        
        // Restore cart
        final cartNotifier = ref.read(cartProvider.notifier);
        for (final item in widget.order.items) {
           try {
             await cartNotifier.addItem(item.food, quantity: item.quantity);
           } catch (e) {
             // Ignore individual errors during restore
           }
        }
        await cartNotifier.refreshCart();

      } catch (e) {
        // Handle error if needed, but still navigate away
      }

      if (mounted) {
        Navigator.pop(context); // Pop loading
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sepayPaymentProvider);
    final currentOrder = state.orderState.value ?? widget.order;
    final isSuccess = currentOrder.status == 'CONFIRMED' || currentOrder.paymentStatus == 'PAID';
    final isBackendExpired = currentOrder.status == 'CANCELLED' || 
                             currentOrder.paymentStatus == 'EXPIRED' || 
                             (currentOrder.paymentInfo?.qrCodeUrl == null && !isSuccess);
    final isExpired = isBackendExpired || (state.remainingSeconds <= 0 && isBackendExpired); // Only hide if backend confirms
    final isPolling = !isSuccess && !isBackendExpired;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('SePay Payment', style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: isSuccess
            ? SepaySuccessView(
                order: currentOrder,
                warningMessage: state.warningMessage,
                errorMessage: state.errorMessage,
              )
            : SepayPaymentView(
                state: state,
                currentOrder: currentOrder,
                isExpired: isExpired,
                isPolling: isPolling,
              ),
      ),
    );
  }
}
