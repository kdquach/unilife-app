import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CheckoutPaymentMethodCard extends StatelessWidget {
  const CheckoutPaymentMethodCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primarySoft],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 26),
              ),
            ),
            const SizedBox(width: 14),

            // Label
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SePay',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Scan QR code via banking app',
                    style: TextStyle(color: AppColors.subText, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Check indicator
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
