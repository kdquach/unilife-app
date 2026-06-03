import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart_item.dart';
import '../../services/app_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../cart/checkout_data_note_screen.dart';

class CartScreen extends StatelessWidget {
  static const String routeName = '/cart';

  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBackButton ? AppBar(title: const Text('My Cart')) : null,
      body: SafeArea(
        child: ValueListenableBuilder<List<CartItem>>(
          valueListenable: AppState.instance.cart,
          builder: (context, items, _) {
            if (items.isEmpty) return const _EmptyCart();
            final menuSubtotal = items.where((e) => e.food.isMenuFood).fold(0, (s, e) => s + e.subtotal);
            final regularSubtotal = items.where((e) => e.food.isAlwaysAvailable).fold(0, (s, e) => s + e.subtotal);
            final total = menuSubtotal + regularSubtotal;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!showBackButton) const Text('My Cart', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                if (!showBackButton) const SizedBox(height: 4),
                const Text('Menu food + always available items', style: TextStyle(color: AppColors.subText)),
                const SizedBox(height: 20),
                ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _CartItemRow(item: item))),
                const SizedBox(height: 20),
                AppCard(
                  child: Column(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Order summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 18),
                      _SummaryRow('Menu food subtotal', menuSubtotal),
                      _SummaryRow('Daily goods subtotal', regularSubtotal),
                      const Divider(height: 28),
                      _SummaryRow('Total', total, large: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(label: 'Checkout', onPressed: () => Navigator.pushNamed(context, CheckoutDataNoteScreen.routeName)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;

  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  item.food.isMenuFood ? 'Menu Food · ${item.food.menuDateLabel} ${item.food.mealType} · qty ${item.quantity}' : 'Always Available · ${item.food.category} · qty ${item.quantity}',
                  style: const TextStyle(color: AppColors.subText, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(CurrencyFormatter.vnd(item.subtotal), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
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
          Text(CurrencyFormatter.vnd(amount), style: TextStyle(fontSize: large ? 18 : 14, fontWeight: FontWeight.w900, color: large ? AppColors.primary : AppColors.text)),
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
