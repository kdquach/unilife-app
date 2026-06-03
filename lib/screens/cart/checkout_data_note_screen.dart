import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../payment/sepay_payment_screen.dart';

class CheckoutDataNoteScreen extends StatelessWidget {
  static const String routeName = '/checkout-note';

  const CheckoutDataNoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Backend data mapping', style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 20),
          const _DataBlock(
            title: 'Menu Food cart item',
            body: 'itemType: MENU_ITEM\nmenuScheduleItemId: required\nfoodId: optional via relation\nquantity: 2\nunitPrice: from menu item',
          ),
          const SizedBox(height: 18),
          const _DataBlock(
            title: 'Always Available cart item',
            body: 'itemType: REGULAR_FOOD\nfoodId: required\nmenuScheduleItemId: null\nquantity: 1\nunitPrice: from food',
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('UI rule', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                Text('Menu food shows remaining servings. Daily goods show stock/in-stock status.', style: TextStyle(color: AppColors.subText, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppButton(label: 'Pay with Sepay', onPressed: () => Navigator.pushNamed(context, SepayPaymentScreen.routeName)),
        ],
      ),
    );
  }
}

class _DataBlock extends StatelessWidget {
  final String title;
  final String body;

  const _DataBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: AppColors.subText, height: 1.45)),
        ],
      ),
    );
  }
}
