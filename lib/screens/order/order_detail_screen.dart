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
import '../../widgets/app_card.dart';
import '../rating/create_rating_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  static const String routeName = '/order-detail';

  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService(ApiClient());

  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken();
      final order = await _orderService.getOrderById(widget.orderId, token: token);

      if (!mounted) return;
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    
    // Pop the bottom sheet first
    Navigator.pop(context);

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthStorage.getToken();
      await _orderService.cancelOrder(widget.orderId, token: token);
      await _fetchOrderDetail();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  bool _isStepDone(String status, String step) {
    final s = status.toUpperCase();
    if (s == 'CANCELLED') return false;

    switch (step) {
      case 'placed':
        return true;
      case 'paid':
        return s == 'PAID' || s == 'PREPARING' || s == 'READY' || s == 'COMPLETED';
      case 'preparing':
        return s == 'PREPARING' || s == 'READY' || s == 'COMPLETED';
      case 'ready':
        return s == 'READY' || s == 'COMPLETED';
      default:
        return false;
    }
  }

  bool _isStepActive(String status, String step) {
    final s = status.toUpperCase();
    if (s == 'CANCELLED') return false;

    switch (step) {
      case 'placed':
        return false;
      case 'paid':
        return s == 'PENDING';
      case 'preparing':
        return s == 'PAID';
      case 'ready':
        return s == 'PREPARING' || s == 'READY';
      default:
        return false;
    }
  }

  String _getStatusMessage(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'PENDING':
        return 'Your order is pending confirmation.';
      case 'PAID':
        return 'Payment verified. Awaiting preparation.';
      case 'PREPARING':
        return 'Your food is being prepared by kitchen staff.';
      case 'READY':
        return 'Your food is ready! Please pick it up at the counter.';
      case 'COMPLETED':
        return 'Thank you for dining with UniLife!';
      case 'CANCELLED':
        return 'This order has been cancelled.';
      default:
        return 'Processing your order.';
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
    final normalizedPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    return '$origin$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage ?? 'Failed to load order details.',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchOrderDetail,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final s = order.status.toUpperCase();
    final canCancel = s == 'PENDING' || s == 'PAID';

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.code}')),
      body: RefreshIndicator(
        onRefresh: _fetchOrderDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            // Premium Ticket Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(76),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Status',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.status,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStatusMessage(order.status),
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'QUEUE',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.queueNumber,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text('Order Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _ProgressStep(
                    title: 'Order placed',
                    description: 'We have received your order request.',
                    done: _isStepDone(order.status, 'placed'),
                    isActive: _isStepActive(order.status, 'placed'),
                  ),
                  _ProgressStep(
                    title: 'Payment Confirmed',
                    description: order.paymentStatus.toUpperCase() == 'PAID'
                        ? 'Payment verified via ${order.paymentMethod}.'
                        : 'Awaiting payment confirmation.',
                    done: _isStepDone(order.status, 'paid'),
                    isActive: _isStepActive(order.status, 'paid'),
                  ),
                  _ProgressStep(
                    title: 'Preparing Food',
                    description: 'Kitchen staff is preparing your delicious meal.',
                    done: _isStepDone(order.status, 'preparing'),
                    isActive: _isStepActive(order.status, 'preparing'),
                  ),
                  _ProgressStep(
                    title: 'Ready for Pickup',
                    description: 'Pick up your meal at the counter.',
                    done: _isStepDone(order.status, 'ready'),
                    isActive: _isStepActive(order.status, 'ready'),
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  _buildDetailRow('Order Code', order.code),
                  _buildDetailRow('Placed At', _formatDateTime(order.createdAt)),
                  _buildDetailRow('Payment Method', order.paymentMethod),
                  _buildDetailRow(
                    'Payment Status',
                    order.paymentStatus,
                    valueColor: order.paymentStatus.toUpperCase() == 'PAID' ? AppColors.success : AppColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  ...order.items.map((item) => _buildOrderItemRow(item)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Price', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(
                        CurrencyFormatter.vnd(order.totalPrice),
                        style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                if (canCancel)
                  Expanded(child: AppButton(label: 'Cancel', danger: true, onPressed: () => _showCancelDialog(context))),
                if (canCancel)
                  const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Rate Meal',
                    secondary: true,
                    onPressed: () => Navigator.pushNamed(context, CreateRatingScreen.routeName),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemRow(CartItem item) {
    final imageUrl = _resolvedImageUrl(item.food);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl == null
                  ? const Icon(Icons.fastfood, color: AppColors.primary, size: 24)
                  : Image.network(
                      imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: AppColors.primary, size: 24),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: ${item.quantity} · ${CurrencyFormatter.vnd(item.food.price)} each',
                  style: const TextStyle(color: AppColors.subText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.vnd(item.subtotal),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.subText)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
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
                Expanded(child: AppButton(label: 'Cancel Order', danger: true, onPressed: _cancelOrder)),
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
  final String description;
  final bool done;
  final bool isLast;
  final bool isActive;

  const _ProgressStep({
    required this.title,
    required this.description,
    this.done = false,
    this.isLast = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? AppColors.primary
        : (isActive ? AppColors.primaryDark : AppColors.border);
    final textColor = done || isActive ? AppColors.text : AppColors.subText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : (isActive ? AppColors.primarySoft : Colors.white),
                border: Border.all(
                  color: dotColor,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : (isActive
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: done ? AppColors.primary : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: done || isActive ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subText,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
