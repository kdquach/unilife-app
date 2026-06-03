import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/sample_data.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../rating/create_rating_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  static const String routeName = '/order-detail';

  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final order = SampleData.sampleOrder();
    return Scaffold(
      appBar: AppBar(title: Text('Order ${order.code}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.status, style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('Your food is being prepared by kitchen staff.', style: TextStyle(color: AppColors.subText)),
                    ],
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(26)),
                  alignment: Alignment.center,
                  child: Text(order.queueNumber, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          const _ProgressStep(title: 'Order placed', done: true),
          const _ProgressStep(title: 'Paid', done: true),
          const _ProgressStep(title: 'Preparing', done: true),
          const _ProgressStep(title: 'Ready to pickup'),
          const SizedBox(height: 22),
          AppCard(
            child: Column(
              children: order.items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item.quantity}× ${item.food.name}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text(CurrencyFormatter.vnd(item.subtotal), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: AppButton(label: 'Cancel', danger: true, onPressed: () => _showCancelDialog(context))),
              const SizedBox(width: 12),
              Expanded(child: AppButton(label: 'Rate Meal', secondary: true, onPressed: () => Navigator.pushNamed(context, CreateRatingScreen.routeName))),
            ],
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cancel this order?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('You can cancel only before the kitchen starts final preparation.', style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: AppButton(label: 'Keep Order', secondary: true, onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 12),
                Expanded(child: AppButton(label: 'Cancel Order', danger: true, onPressed: () => Navigator.pop(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final String title;
  final bool done;

  const _ProgressStep({required this.title, this.done = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: done ? AppColors.primary : AppColors.border, shape: BoxShape.circle),
            child: done ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontWeight: done ? FontWeight.w800 : FontWeight.w500, color: done ? AppColors.text : AppColors.subText)),
        ],
      ),
    );
  }
}
