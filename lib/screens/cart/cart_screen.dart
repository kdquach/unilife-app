import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart.dart';
import '../../states/cart_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../cart/checkout_data_note_screen.dart';

class CartScreen extends ConsumerWidget {
  static const String routeName = '/cart';

  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: showBackButton ? AppBar(title: const Text('My Cart')) : null,
      body: SafeArea(
        child: cartAsync.when(
          data: (cart) {
            if (cart == null || cart.items.isEmpty) return const _EmptyCart();
            
            final validItems = cart.validItems;
            final invalidItems = cart.invalidItems;
            
            final total = cart.totalPrice;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!showBackButton) const Text('My Cart', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                if (!showBackButton) const SizedBox(height: 4),
                const Text('Review your selected items', style: TextStyle(color: AppColors.subText)),
                const SizedBox(height: 20),
                
                if (validItems.isNotEmpty) ...[
                  ...validItems.map((item) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _CartItemRow(item: item))),
                  const SizedBox(height: 10),
                ],

                if (invalidItems.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Unavailable Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                  ...invalidItems.map((item) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _CartItemRow(item: item, isInvalid: true))),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Order summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 18),
                      _SummaryRow('Total Items', cart.totalItems),
                      const Divider(height: 28),
                      _SummaryRow('Total', total, large: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Checkout', 
                  onPressed: validItems.isNotEmpty ? () => Navigator.pushNamed(context, CheckoutDataNoteScreen.routeName) : null,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load cart', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subText)),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.read(cartProvider.notifier).refreshCart(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItemDto item;
  final bool isInvalid;

  const _CartItemRow({required this.item, this.isInvalid = false});

  @override
  Widget build(BuildContext context) {
    final food = item.food;
    final String title = food?.name ?? 'Unknown Item';
    final String type = (food?.isMenuFood ?? false) ? 'Menu Food' : 'Always Available';
    
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (food?.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                food!.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isInvalid ? Colors.grey : AppColors.text, decoration: isInvalid ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 6),
                Text(
                  '$type · qty ${item.quantity}',
                  style: TextStyle(color: isInvalid ? Colors.redAccent : AppColors.subText, fontSize: 12),
                ),
                if (isInvalid && item.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.reason!,
                    style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          Text(CurrencyFormatter.vnd(item.subtotal), style: TextStyle(color: isInvalid ? Colors.grey : AppColors.primary, fontWeight: FontWeight.w900, decoration: isInvalid ? TextDecoration.lineThrough : null)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool large;

  const _SummaryRow(this.label, this.amount, {this.large = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: large ? 17 : 14, fontWeight: large ? FontWeight.w900 : FontWeight.w400, color: large ? AppColors.text : AppColors.subText))),
          Text(large ? CurrencyFormatter.vnd(amount) : amount.toString(), style: TextStyle(fontSize: large ? 18 : 14, fontWeight: FontWeight.w900, color: large ? AppColors.primary : AppColors.text)),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 88, color: AppColors.primary),
            const SizedBox(height: 18),
            const Text('Your cart is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Browse today menu and add your favorite meals.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 24),
            AppButton(label: 'Browse Menu', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
