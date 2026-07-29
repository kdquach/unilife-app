import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../order/order_detail_screen.dart';

class PaymentSuccessScreen extends StatelessWidget {
  static const String routeName = '/payment-success';

  final String orderId;
  final String? orderCode;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
    this.orderCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(
                width: 300,
                height: 300,
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/Payment-success-logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.success,
                      alignment: Alignment.center,
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 92),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              const Text('Payment confirmed',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text(
                  'Your payment has been verified. The kitchen is preparing your order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subText, height: 1.4)),
              const SizedBox(height: 24),
              if (orderCode != null && orderCode!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Scan for Counter Staff',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: orderCode!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Order Code: $orderCode',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Spacer(),
              AppButton(
                label: 'Track Order',
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  OrderDetailScreen.routeName,
                  arguments: orderId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
