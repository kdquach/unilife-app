import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
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
      appBar: AppBar(title: Text('Order ${order.code}')),
      body: RefreshIndicator(
        onRefresh: _fetchOrderDetail,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.status,
                          style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStatusMessage(order.status),
                          style: const TextStyle(color: AppColors.subText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(26)),
                    alignment: Alignment.center,
                    child: Text(order.queueNumber, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ProgressStep(title: 'Order placed', done: _isStepDone(order.status, 'placed')),
            _ProgressStep(title: 'Paid', done: _isStepDone(order.status, 'paid')),
            _ProgressStep(title: 'Preparing', done: _isStepDone(order.status, 'preparing')),
            _ProgressStep(title: 'Ready to pickup', done: _isStepDone(order.status, 'ready')),
            const SizedBox(height: 22),
            AppCard(
              child: Column(
                children: order.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text('${item.quantity}× ${item.food.name}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text(CurrencyFormatter.vnd(item.subtotal), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
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
  final bool done;

  const _ProgressStep({required this.title, this.done = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: done ? AppColors.primary : AppColors.border, shape: BoxShape.circle),
            child: done ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontWeight: done ? FontWeight.w800 : FontWeight.w500, color: done ? AppColors.text : AppColors.subText)),
        ],
      ),
    );
  }
}
