import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'payment_success_screen.dart';

class SepayPaymentScreen extends StatelessWidget {
  static const String routeName = '/sepay-payment';

  const SepayPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sepay Payment')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Scan QR or transfer with order code', style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 226,
                  height: 226,
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                  alignment: Alignment.center,
                  child: const Text('QR', style: TextStyle(color: AppColors.primary, fontSize: 56, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 18),
                const Text('Order code: ORD-24001', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(24)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount to pay', style: TextStyle(color: AppColors.subText, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('97,000đ', style: TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 14),
                Text('Waiting for Sepay confirmation...', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppButton(label: 'I have paid', onPressed: () => Navigator.pushReplacementNamed(context, PaymentSuccessScreen.routeName)),
        ],
      ),
    );
  }
}
