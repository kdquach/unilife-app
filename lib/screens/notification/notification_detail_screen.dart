import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../order/order_detail_screen.dart';

class NotificationDetailScreen extends StatelessWidget {
  static const String routeName = '/notification-detail';

  const NotificationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order is ready', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Today, 11:42 AM', style: TextStyle(color: AppColors.subText)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Order update', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 24),
                const Text('Your order ORD-24001 is ready. Please go to the pickup counter and show queue number A12.', style: TextStyle(color: AppColors.subText, height: 1.5)),
                const SizedBox(height: 28),
                AppButton(label: 'View Order', onPressed: () => Navigator.pushNamed(context, OrderDetailScreen.routeName)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
