import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/order_service.dart';
import '../../widgets/app_card.dart';
import '../order/order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  static const String routeName = '/orders';

  final bool showBackButton;

  const OrderListScreen({super.key, this.showBackButton = true});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final OrderService _orderService = OrderService(ApiClient());

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedTab = 'Active'; // Active, Completed, Cancelled

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken();
      final orders = await _orderService.getOrders(token: token);

      if (!mounted) return;
      setState(() {
        _allOrders = orders;
        _filterOrders();
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

  void _filterOrders() {
    if (!mounted) return;
    setState(() {
      if (_selectedTab == 'Active') {
        _filteredOrders = _allOrders.where((o) {
          final s = o.status.toUpperCase();
          return s != 'COMPLETED' && s != 'CANCELLED';
        }).toList();
      } else if (_selectedTab == 'Completed') {
        _filteredOrders = _allOrders.where((o) {
          return o.status.toUpperCase() == 'COMPLETED';
        }).toList();
      } else if (_selectedTab == 'Cancelled') {
        _filteredOrders = _allOrders.where((o) {
          return o.status.toUpperCase() == 'CANCELLED';
        }).toList();
      }
    });
  }

  void _onTabChanged(String tab) {
    setState(() {
      _selectedTab = tab;
      _filterOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showBackButton ? AppBar(title: const Text('My Orders')) : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchOrders,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (!widget.showBackButton)
                const Text('My Orders', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Track all active and past orders', style: TextStyle(color: AppColors.subText)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _OrderChip(
                    'Active',
                    selected: _selectedTab == 'Active',
                    onTap: () => _onTabChanged('Active'),
                  ),
                  const SizedBox(width: 10),
                  _OrderChip(
                    'Completed',
                    selected: _selectedTab == 'Completed',
                    onTap: () => _onTabChanged('Completed'),
                  ),
                  const SizedBox(width: 10),
                  _OrderChip(
                    'Cancelled',
                    selected: _selectedTab == 'Cancelled',
                    onTap: () => _onTabChanged('Cancelled'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchOrders,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Text(
                      'No orders found.',
                      style: TextStyle(color: AppColors.subText, fontSize: 16),
                    ),
                  ),
                )
              else
                ..._filteredOrders.map((order) {
                  final s = order.status.toUpperCase();
                  final isSuccess = s == 'COMPLETED' || s == 'READY';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _OrderCard(
                      id: order.id,
                      code: order.code,
                      status: order.status,
                      amount: order.totalPrice,
                      queue: order.queueNumber,
                      success: isSuccess,
                      itemCount: order.items.length,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderChip(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Chip(
          label: Text(label),
          backgroundColor: selected ? AppColors.primary : Colors.white,
          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text, fontWeight: FontWeight.w800),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  final String id;
  final String code;
  final String status;
  final int amount;
  final String queue;
  final bool success;
  final int itemCount;

  const _OrderCard({
    required this.id,
    required this.code,
    required this.status,
    required this.amount,
    required this.queue,
    this.success = false,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        OrderDetailScreen.routeName,
        arguments: id,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(code, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: success ? AppColors.success : AppColors.primary, borderRadius: BorderRadius.circular(999)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('$itemCount items · ${CurrencyFormatter.vnd(amount)}', style: const TextStyle(color: AppColors.subText)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Queue $queue', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Text('View detail', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
