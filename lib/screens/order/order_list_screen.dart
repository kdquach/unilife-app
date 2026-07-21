import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final String initialTab;

  const OrderListScreen({
    super.key,
    this.showBackButton = true,
    this.initialTab = 'Active',
  });

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final OrderService _orderService = OrderService(ApiClient());

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = _normalizedTab(widget.initialTab);
    _fetchOrders();
  }

  String _normalizedTab(String tab) {
    return switch (tab) {
      'Completed' => 'Completed',
      'Cancelled' => 'Cancelled',
      _ => 'Active',
    };
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
      appBar:
          widget.showBackButton ? AppBar(title: const Text('My Orders')) : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchOrders,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (!widget.showBackButton)
                const Text('My Orders',
                    style:
                        TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Track all active and past orders',
                  style: TextStyle(color: AppColors.subText)),
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
                        Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _OrderCard(order: order),
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
          labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w800),
          side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final s = order.status.toUpperCase();
    final isSuccess = s == 'COMPLETED' || s == 'READY';
    final isCancelled = s == 'CANCELLED';

    Color statusBgColor = AppColors.primary;
    if (isSuccess) statusBgColor = AppColors.success;
    if (isCancelled) statusBgColor = AppColors.error;

    String formattedTime = 'N/A';
    if (order.createdAt != null) {
      formattedTime =
          DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!.toLocal());
    }

    final totalItemsCount =
        order.items.fold(0, (sum, item) => sum + item.quantity);

    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        OrderDetailScreen.routeName,
        arguments: order.id,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Placed on: $formattedTime',
            style: const TextStyle(color: AppColors.subText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.items
                          .map((e) => '${e.quantity}x ${e.food.name}')
                          .join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalItemsCount items · ${CurrencyFormatter.vnd(order.totalPrice)}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Queue ${order.queueNumber}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Row(
                    children: [
                      Text('Details',
                          style: TextStyle(
                              color: AppColors.subText, fontSize: 12)),
                      Icon(Icons.chevron_right,
                          color: AppColors.subText, size: 16),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
