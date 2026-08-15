import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_service.dart';
import '../../states/cart_provider.dart';
import '../payment/sepay_payment_screen.dart';

// Import extracted widgets
import 'widgets/checkout_item_card.dart';
import 'widgets/checkout_payment_method_card.dart';
import 'widgets/checkout_order_summary_card.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  static const String routeName = '/checkout';

  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isCheckingOut = false;

  Future<void> _performCheckout() async {
    final cart = ref.read(cartProvider).value;
    if (cart == null || cart.validItems.isEmpty) return;

    // Prevent double-tap
    if (_isCheckingOut) return;

    setState(() => _isCheckingOut = true);

    try {
      final token = await AuthStorage.getToken();
      final response = await CartService(ApiClient()).checkout(cart.validItems, token: token);
      final orderJson = response['data'];
      final order = Order.fromJson(orderJson);

      await ref.read(cartProvider.notifier).refreshCart();

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        SepayPaymentScreen.routeName,
        arguments: order,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);

      final errorMessage = e.toString().replaceFirst('ApiException: ', '');
      
      // Check if it's a duplicate key error and handle it
      if (errorMessage.contains('duplicate key error') || errorMessage.contains('E11000')) {
        // Refresh cart and show retry message
        await ref.read(cartProvider.notifier).refreshCart();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order code conflict. Please try again.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $errorMessage'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return cartAsync.when(
      data: (cart) {
        if (cart == null || cart.validItems.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Checkout')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        final validItems = cart.validItems;
        final total = validItems.fold<int>(0, (sum, item) => sum + item.subtotal);

        return Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          bottomNavigationBar: _buildBottomBar(total),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionLabel('Order Items'),
              const SizedBox(height: 12),
              ...validItems.map((item) => CheckoutItemCard(item: item)),

              const SizedBox(height: 28),

              _buildSectionLabel('Payment Method'),
              const SizedBox(height: 12),
              const CheckoutPaymentMethodCard(),

              const SizedBox(height: 28),

              _buildSectionLabel('Order Summary'),
              const SizedBox(height: 12),
              CheckoutOrderSummaryCard(items: validItems, total: total),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Failed to load cart', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildBottomBar(int total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Payment', style: TextStyle(color: AppColors.subText, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.vnd(total),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 160,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCheckingOut ? null : _performCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCheckingOut
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Pay Now  →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
