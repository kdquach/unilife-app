import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order.dart';
import '../../../states/sepay_payment_provider.dart';
import '../../../widgets/app_card.dart';

class SepayPaymentView extends StatelessWidget {
  final SepayPaymentState state;
  final Order currentOrder;
  final bool isExpired;
  final bool isPolling;

  const SepayPaymentView({
    super.key,
    required this.state,
    required this.currentOrder,
    required this.isExpired,
    required this.isPolling,
  });

  void _copyToClipboard(BuildContext context, String title, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $title!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      children: [
        if (state.errorMessage != null)
          _buildAlertBox(state.errorMessage!, Colors.red),
        if (state.warningMessage != null)
          _buildAlertBox(state.warningMessage!, Colors.orange),

        // Clean Modern QR Card
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Bank Info Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      currentOrder.paymentInfo?.bankName ?? 'Vietcombank',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // QR Code Image
                Container(
                  width: 240,
                  height: 240,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Builder(
                      builder: (context) {
                        if (isExpired) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.timer_off, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Order Expired', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          );
                        }
                        
                        final paymentInfo = currentOrder.paymentInfo;
                        if (paymentInfo == null || paymentInfo.qrCodeUrl == null || paymentInfo.qrCodeUrl!.isEmpty) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No QR Code available', style: TextStyle(color: Colors.grey)),
                            ],
                          );
                        }

                        String safeUrl = paymentInfo.qrCodeUrl!.trim();
                        if (safeUrl.contains('&amp;')) {
                          safeUrl = safeUrl.replaceAll('&amp;', '&');
                        }

                        return Image.network(
                          safeUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Image load error for SePay QR: $error');
                            return const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Could not load QR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Total Amount
                const Text(
                  'Total Payment',
                  style: TextStyle(color: AppColors.subText, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.vnd(currentOrder.totalPrice),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Countdown Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isExpired || state.remainingSeconds < 300
                        ? Colors.red.withOpacity(0.1)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer,
                          size: 16,
                          color: isExpired || state.remainingSeconds < 300
                              ? Colors.red
                              : AppColors.primaryDark),
                      const SizedBox(width: 8),
                      Text(
                        isExpired ? 'Expired' : 'Expires in: ${_formatDuration(state.remainingSeconds)}',
                        style: TextStyle(
                          color: isExpired || state.remainingSeconds < 300
                              ? Colors.red
                              : AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Manual Transfer Section
        if (!isExpired) ...[
          const Text('Or transfer manually',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _buildCopyRow(
            context,
            'Account Number',
            currentOrder.paymentInfo?.accountNumber ?? 'N/A',
            icon: Icons.numbers,
          ),
          const SizedBox(height: 12),
          _buildCopyRow(
            context,
            'Amount',
            currentOrder.totalPrice.toString(),
            displayValue: CurrencyFormatter.vnd(currentOrder.totalPrice),
            icon: Icons.payments,
          ),
          const SizedBox(height: 12),
          _buildCopyRow(
            context,
            'Transfer Content',
            currentOrder.transferContent ?? currentOrder.code,
            icon: Icons.edit_document,
            isHighlight: false, // Turn off orange highlight by default
          ),
        ],

        const SizedBox(height: 32),
        if (isPolling)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
              SizedBox(width: 12),
              Text(
                'Waiting for payment confirmation...',
                style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildAlertBox(String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow(BuildContext context, String title, String value,
      {String? displayValue,
      required IconData icon,
      bool isHighlight = false}) {
    return _CopyRowWidget(
      title: title,
      value: value,
      displayValue: displayValue,
      icon: icon,
      isHighlight: isHighlight,
    );
  }
}

class _CopyRowWidget extends StatefulWidget {
  final String title;
  final String value;
  final String? displayValue;
  final IconData icon;
  final bool isHighlight;

  const _CopyRowWidget({
    required this.title,
    required this.value,
    this.displayValue,
    required this.icon,
    this.isHighlight = false,
  });

  @override
  State<_CopyRowWidget> createState() => _CopyRowWidgetState();
}

class _CopyRowWidgetState extends State<_CopyRowWidget> {
  bool _isCopied = false;

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${widget.title}!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {
      _isCopied = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isCopied ? Colors.green.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isCopied ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: AppColors.primaryDark, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        color: AppColors.subText, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  widget.displayValue ?? widget.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _isCopied ? Icons.check_circle : Icons.copy_rounded,
            size: 20,
            color: _isCopied ? Colors.green : Colors.grey[400],
          ),
        ],
      ),
      ),
    );
  }

}
