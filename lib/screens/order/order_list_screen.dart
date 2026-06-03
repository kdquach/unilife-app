import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/sample_data.dart';
import '../../widgets/app_card.dart';
import '../order/order_detail_screen.dart';

class OrderListScreen extends StatelessWidget {
  static const String routeName = '/orders';

  final bool showBackButton;

  const OrderListScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final order = SampleData.sampleOrder();
    return Scaffold(
      appBar: showBackButton ? AppBar(title: const Text('My Orders')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!showBackButton) const Text('My Orders', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Track all active and past orders', style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 20),
            const Row(children: [_OrderChip('Active', selected: true), SizedBox(width: 10), _OrderChip('Completed'), SizedBox(width: 10), _OrderChip('Cancelled')]),
            const SizedBox(height: 22),
            _OrderCard(code: order.code, status: order.status, amount: order.totalPrice, queue: order.queueNumber),
            const SizedBox(height: 16),
            const _OrderCard(code: 'ORD-23998', status: 'Ready', amount: 55000, queue: 'A09', success: true),
          ],
        ),
      ),
    );
  }
}

class _OrderChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _OrderChip(this.label, {this.selected = false});

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label),
        backgroundColor: selected ? AppColors.primary : Colors.white,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text, fontWeight: FontWeight.w800),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      );
}

class _OrderCard extends StatelessWidget {
  final String code;
  final String status;
  final int amount;
  final String queue;
  final bool success;

  const _OrderCard({required this.code, required this.status, required this.amount, required this.queue, this.success = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.pushNamed(context, OrderDetailScreen.routeName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(code, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: success ? AppColors.success : AppColors.primary, borderRadius: BorderRadius.circular(999)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('3 items · ${CurrencyFormatter.vnd(amount)}', style: const TextStyle(color: AppColors.subText)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Queue $queue', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Text('View detail', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
