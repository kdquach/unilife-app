import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../models/cart_item.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/order_service.dart';
import '../../widgets/app_button.dart';
import '../rating/create_rating_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  static const String routeName = '/order-detail';

  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with TickerProviderStateMixin {
  final OrderService _orderService = OrderService(ApiClient());

  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _pollingTimer;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _fetchOrderDetail();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderDetail({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await AuthStorage.getToken();
      final order =
          await _orderService.getOrderById(widget.orderId, token: token);

      if (!mounted) return;
      setState(() {
        _order = order;
        if (!quiet) _isLoading = false;
      });
      if (!quiet) _slideController.forward(from: 0);
      _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (!quiet) {
          _errorMessage =
              error.toString().replaceFirst('ApiException: ', '');
          _isLoading = false;
        }
      });
    }
  }

  bool _isTerminalStatus(String status) {
    final s = status.toUpperCase();
    return s == 'COMPLETED' || s == 'CANCELLED' || s == 'EXPIRED';
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (_order == null || _isTerminalStatus(_order!.status)) return;
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _fetchOrderDetail(quiet: true);
    });
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    Navigator.pop(context);
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await AuthStorage.getToken();
      await _orderService.cancelOrder(widget.orderId, token: token);
      await _fetchOrderDetail();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final cleanMessage = error is ApiException
          ? error.message
          : error
              .toString()
              .replaceFirst('ApiException: ', '')
              .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFCA5A5), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cancellation Failed',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(cleanMessage,
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ─── Backend Status Flow ──────────────────────────────────────────────────
  // PENDING_PAYMENT → (sepay confirmed) → CONFIRMED
  // PAID (cash)     → (QR scan)         → CONFIRMED
  //                                      → (callNextNumber) → COMPLETED
  bool _isStepDone(String status, String step) {
    final s = status.toUpperCase();
    if (s == 'CANCELLED' || s == 'EXPIRED') return false;
    switch (step) {
      case 'placed':
        return true;
      case 'paid':
        return s == 'PAID' || s == 'CONFIRMED' || s == 'COMPLETED';
      case 'confirmed':
        return s == 'CONFIRMED' || s == 'COMPLETED';
      case 'ready':
        return s == 'COMPLETED';
      default:
        return false;
    }
  }

  bool _isStepActive(String status, String step) {
    final s = status.toUpperCase();
    if (s == 'CANCELLED' || s == 'EXPIRED') return false;
    switch (step) {
      case 'placed':
        return false;
      case 'paid':
        return s == 'PENDING_PAYMENT';
      case 'confirmed':
        return s == 'PAID';
      case 'ready':
        return s == 'CONFIRMED';
      default:
        return false;
    }
  }

  _StatusMeta _statusMeta(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_PAYMENT':
        return _StatusMeta(
          label: 'Pending Payment',
          message: 'Awaiting your payment. Please complete the transfer.',
          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          icon: Icons.schedule_rounded,
        );
      case 'PAID':
        return _StatusMeta(
          label: 'Paid',
          message: 'Payment verified. Please scan your QR code at the counter.',
          gradientColors: [const Color(0xFF0284C7), const Color(0xFF0369A1)],
          icon: Icons.qr_code_scanner_rounded,
        );
      case 'CONFIRMED':
        return _StatusMeta(
          label: 'In Kitchen',
          message: 'Order confirmed. Kitchen staff is preparing your meal.',
          gradientColors: [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
          icon: Icons.restaurant_rounded,
        );
      case 'COMPLETED':
        return _StatusMeta(
          label: 'Completed',
          message: 'Your food is ready! Thank you for dining with UniLife!',
          gradientColors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
          icon: Icons.check_circle_rounded,
        );
      case 'CANCELLED':
        return _StatusMeta(
          label: 'Cancelled',
          message: 'This order has been cancelled.',
          gradientColors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
          icon: Icons.cancel_rounded,
        );
      case 'EXPIRED':
        return _StatusMeta(
          label: 'Expired',
          message: 'This order has expired due to payment timeout.',
          gradientColors: [const Color(0xFF6B7280), const Color(0xFF4B5563)],
          icon: Icons.timer_off_rounded,
        );
      default:
        return _StatusMeta(
          label: status,
          message: 'Processing your order.',
          gradientColors: [AppColors.primary, AppColors.primaryDark],
          icon: Icons.receipt_long_rounded,
        );
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
  }

  String? _resolvedImageUrl(Food food) {
    final imageUrl = food.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    final apiRoot = Uri.parse(ApiClient.baseUrl);
    final origin = '${apiRoot.scheme}://${apiRoot.authority}';
    final normalizedPath =
        imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    return '$origin$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Loading order details...',
                  style: TextStyle(color: AppColors.subText, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Order Details'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: AppColors.error, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  _errorMessage ?? 'Failed to load order details.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.subText, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _fetchOrderDetail,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final s = order.status.toUpperCase();
    final canCancel = s == 'PENDING_PAYMENT' || s == 'PAID';
    final isCompleted = s == 'COMPLETED';
    final meta = _statusMeta(order.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchOrderDetail,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Hero Header ────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: meta.gradientColors.first,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: meta.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 52, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(meta.icon,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meta.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      meta.message,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                              // Queue badge
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  border: Border.all(
                                      color: Colors.white30, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'QUEUE',
                                      style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order.queueNumber,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                collapseMode: CollapseMode.parallax,
              ),
              title: Text(
                order.code,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),

            // ─── Body content ────────────────────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Order Code Banner ─────────────────────
                        _buildCodeBanner(order),
                        const SizedBox(height: 24),
                        // ── Timeline ──────────────────────────────
                        _buildSectionTitle(
                          'Order Timeline',
                          trailing: !_isTerminalStatus(order.status)
                              ? const _LiveChip()
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTimeline(order),
                        const SizedBox(height: 24),
                        // ── Order Info ───────────────────────────
                        _buildSectionTitle('Order Info'),
                        const SizedBox(height: 12),
                        _buildInfoCard(order),
                        const SizedBox(height: 24),
                        // ── Order Items ──────────────────────────
                        _buildSectionTitle('Order Items'),
                        const SizedBox(height: 12),
                        _buildItemsCard(order),
                        const SizedBox(height: 28),
                        // ── Action Buttons ────────────────────────
                        _buildActions(context, canCancel, isCompleted),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBanner(Order order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Code',
                    style:
                        TextStyle(color: AppColors.subText, fontSize: 11)),
                Text(
                  order.code,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDateTime(order.createdAt),
            style:
                const TextStyle(color: AppColors.subText, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing,
        ],
      ],
    );
  }

  Widget _buildTimeline(Order order) {
    final steps = [
      _TimelineStep(
        title: 'Order Placed',
        description: 'We have received your order request.',
        icon: Icons.shopping_bag_outlined,
        stepKey: 'placed',
      ),
      _TimelineStep(
        title: 'Payment Confirmed',
        description: order.paymentStatus.toUpperCase() == 'PAID'
            ? 'Payment verified via ${order.paymentMethod}.'
            : 'Awaiting payment confirmation.',
        icon: Icons.credit_card_rounded,
        stepKey: 'paid',
      ),
      _TimelineStep(
        title: 'Order Confirmed',
        description: _isStepDone(order.status, 'confirmed')
            ? 'QR scanned. Kitchen is preparing your meal.'
            : 'Scan your QR code at the counter to enter the queue.',
        icon: Icons.restaurant_rounded,
        stepKey: 'confirmed',
      ),
      _TimelineStep(
        title: 'Ready for Pickup',
        description: _isStepDone(order.status, 'ready')
            ? 'Your meal is ready. Please pick it up!'
            : 'Your meal will be ready shortly.',
        icon: Icons.check_circle_outline_rounded,
        stepKey: 'ready',
      ),
    ];

    final isCancelledOrExpired = ['CANCELLED', 'EXPIRED']
        .contains(order.status.toUpperCase());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isCancelledOrExpired)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    order.status.toUpperCase() == 'CANCELLED'
                        ? Icons.cancel_outlined
                        : Icons.timer_off_outlined,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    order.status.toUpperCase() == 'CANCELLED'
                        ? 'This order was cancelled'
                        : 'This order expired',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: steps.asMap().entries.map((entry) {
                final idx = entry.key;
                final step = entry.value;
                final done = _isStepDone(order.status, step.stepKey);
                final isActive =
                    _isStepActive(order.status, step.stepKey);
                final isLast = idx == steps.length - 1;
                return _TimelineItem(
                  step: step,
                  done: done,
                  isActive: isActive,
                  isLast: isLast,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Order order) {
    final paymentPaid = order.paymentStatus.toUpperCase() == 'PAID';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.qr_code_rounded,
            label: 'Order Code',
            value: order.code,
            isFirst: true,
          ),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Placed At',
            value: _formatDateTime(order.createdAt),
          ),
          _InfoRow(
            icon: Icons.payment_rounded,
            label: 'Payment Method',
            value: order.paymentMethod,
          ),
          _InfoRow(
            icon: paymentPaid
                ? Icons.check_circle_rounded
                : Icons.pending_rounded,
            label: 'Payment Status',
            value: order.paymentStatus,
            valueColor: paymentPaid ? AppColors.success : AppColors.warning,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...order.items.map((item) => _buildItemRow(item)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppColors.border, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_rounded,
                        color: AppColors.subText, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.subText),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.vnd(order.totalPrice),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    final imageUrl = _resolvedImageUrl(item.food);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl == null
                  ? Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.fastfood_rounded,
                          color: AppColors.primary, size: 26),
                    )
                  : Image.network(
                      imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.fastfood_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.food.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.text),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '×${item.quantity}',
                        style: const TextStyle(
                            color: AppColors.subText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      CurrencyFormatter.vnd(item.food.price),
                      style: const TextStyle(
                          color: AppColors.subText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.vnd(item.subtotal),
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, bool canCancel, bool isCompleted) {
    return Column(
      children: [
        if (isCompleted)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, CreateRatingScreen.routeName),
              icon: const Icon(Icons.star_rounded, size: 20),
              label: const Text('Rate Your Meal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF3C7),
                foregroundColor: const Color(0xFFD97706),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        if (canCancel) ...[
          if (isCompleted) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(context),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel Order',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
        if (!isCompleted && !canCancel) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, CreateRatingScreen.routeName),
              icon: const Icon(Icons.star_outline_rounded, size: 20),
              label: const Text('Rate Your Meal',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cancel this order?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can cancel before the kitchen starts final preparation. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.subText, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Keep Order',
                    secondary: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Cancel Order',
                    danger: true,
                    onPressed: _cancelOrder,
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

// ─── Data Helpers ────────────────────────────────────────────────────────────
class _StatusMeta {
  final String label;
  final String message;
  final List<Color> gradientColors;
  final IconData icon;

  _StatusMeta({
    required this.label,
    required this.message,
    required this.gradientColors,
    required this.icon,
  });
}

class _TimelineStep {
  final String title;
  final String description;
  final IconData icon;
  final String stepKey;

  _TimelineStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.stepKey,
  });
}

// ─── Timeline Item ────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final _TimelineStep step;
  final bool done;
  final bool isActive;
  final bool isLast;

  const _TimelineItem({
    required this.step,
    required this.done,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    Color lineColor;

    if (done) {
      iconBg = AppColors.primary;
      iconColor = Colors.white;
      lineColor = AppColors.primary;
    } else if (isActive) {
      iconBg = AppColors.primarySoft;
      iconColor = AppColors.primary;
      lineColor = AppColors.border;
    } else {
      iconBg = AppColors.muted;
      iconColor = AppColors.subText;
      lineColor = AppColors.border;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + Line column
        SizedBox(
          width: 40,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  boxShadow: done
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : isActive
                        ? _PulsingInnerDot(color: AppColors.primary)
                        : Icon(step.icon, color: iconColor, size: 17),
              ),
              if (!isLast)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 2,
                  height: 36,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Text content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: done || isActive
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: done || isActive
                              ? AppColors.text
                              : AppColors.subText,
                        ),
                      ),
                    ),
                    if (done)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      )
                    else if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Now',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: done || isActive
                        ? AppColors.subText
                        : const Color(0xFFD1D5DB),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppColors.subText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.subText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: valueColor ?? AppColors.text,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppColors.border),
          ),
      ],
    );
  }
}

// ─── Pulsing Inner Dot (for active step) ─────────────────────────────────────
class _PulsingInnerDot extends StatefulWidget {
  final Color color;
  const _PulsingInnerDot({required this.color});

  @override
  State<_PulsingInnerDot> createState() => _PulsingInnerDotState();
}

class _PulsingInnerDotState extends State<_PulsingInnerDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─── Live Chip ────────────────────────────────────────────────────────────────
class _LiveChip extends StatefulWidget {
  const _LiveChip();

  @override
  State<_LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<_LiveChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: Colors.green.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.green.withValues(alpha: _anim.value),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(
                        alpha: 0.4 * _anim.value),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Live',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
