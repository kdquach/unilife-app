import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cart.dart';

class CheckoutOrderSummaryCard extends StatelessWidget {
  final List<CartItemDto> items;
  final int total;

  const CheckoutOrderSummaryCard({
    super.key,
    required this.items,
    required this.total,
  });

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.subText, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor ?? AppColors.text,
          ),
        ),
      ],
    );
  }

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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Subtotal', CurrencyFormatter.vnd(total)),
            const SizedBox(height: 12),
            _buildSummaryRow('Items', '${items.length}'),
            const SizedBox(height: 12),
            _buildSummaryRow('Payment Fee', 'Free', valueColor: AppColors.success),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(height: 1, color: AppColors.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                Text(
                  CurrencyFormatter.vnd(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
