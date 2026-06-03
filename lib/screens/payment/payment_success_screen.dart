import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../order/order_detail_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  static const String routeName = '/payment-success';

  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 174,
                height: 174,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 92),
              ),
              const SizedBox(height: 34),
              const Text('Payment confirmed', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Your Sepay payment has been verified. The kitchen is preparing your order.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.subText, height: 1.4)),
              const Spacer(),
              AppButton(label: 'Track Order', onPressed: () => Navigator.pushReplacementNamed(context, OrderDetailScreen.routeName)),
            ],
          ),
        ),
      ),
    );
  }
}
