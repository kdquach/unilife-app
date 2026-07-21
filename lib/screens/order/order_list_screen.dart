import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/order_service.dart';
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
  String _selectedTab = 'Active';

  final _tabs = ['Active', 'Completed', 'Cancelled'];

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
      final filtered = _computeFiltered(orders, _selectedTab);
      setState(() {
        _allOrders = orders;
        _filteredOrders = filtered;
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

  List<Order> _computeFiltered(List<Order> orders, String tab) {
    if (tab == 'Active') {
      return orders.where((o) {
        final s = o.status.toUpperCase();
        return s != 'COMPLETED' && s != 'CANCELLED' && s != 'EXPIRED';
      }).toList();
    } else if (tab == 'Completed') {
      return orders
          .where((o) => o.status.toUpperCase() == 'COMPLETED')
          .toList();
    } else {
      return orders.where((o) {
        final s = o.status.toUpperCase();
        return s == 'CANCELLED' || s == 'EXPIRED';
      }).toList();
    }
  }

  void _onTabChanged(String tab) {
    if (!mounted) return;
    final filtered = _computeFiltered(_allOrders, tab);
    setState(() {
      _selectedTab = tab;
      _filteredOrders = filtered;
    });
  }

  int _countForTab(String tab) => _computeFiltered(_allOrders, tab).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetchOrders,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── White Top Bar (matches Home, Menu, Profile pattern) ─
              SliverToBoxAdapter(child: _buildTopBar()),
              // ── Tab Chips ─────────────────────────────────────────
              SliverToBoxAdapter(child: _buildTabRow()),
              // ── Content ───────────────────────────────────────────
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildError(),
                )
              else if (_filteredOrders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OrderCard(order: _filteredOrders[i]),
                      ),
                      childCount: _filteredOrders.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Matches the _TopBar pattern used by HomeScreen
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.text, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your active and past orders',
                  style: TextStyle(
                    color: AppColors.subText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chip-style tabs — same style used in other screens
  Widget _buildTabRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = tab == _selectedTab;
          final count = _isLoading ? 0 : _countForTab(tab);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onTabChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                    ),
                    if (!_isLoading && count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.muted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.subText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    final icons = {
      'Active': Icons.hourglass_empty_rounded,
      'Completed': Icons.check_circle_outline_rounded,
      'Cancelled': Icons.cancel_outlined,
    };
    final messages = {
      'Active': 'No active orders right now.\nOrder your meal to get started!',
      'Completed':
          'No completed orders yet.\nYour meal history will appear here.',
      'Cancelled': 'No cancelled orders.\nKeep enjoying UniLife meals!',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[_selectedTab] ?? Icons.inbox_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              messages[_selectedTab] ?? 'No orders found.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load orders',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.subText, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _fetchOrders,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  _StatusConfig _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return _StatusConfig(
          color: AppColors.success,
          bgColor: const Color(0xFFDCFCE7),
          label: 'Completed',
          icon: Icons.check_circle_rounded,
        );
      case 'CANCELLED':
        return _StatusConfig(
          color: AppColors.error,
          bgColor: const Color(0xFFFEE2E2),
          label: 'Cancelled',
          icon: Icons.cancel_rounded,
        );
      case 'EXPIRED':
        return _StatusConfig(
          color: AppColors.subText,
          bgColor: AppColors.muted,
          label: 'Expired',
          icon: Icons.timer_off_rounded,
        );
      case 'CONFIRMED':
        return _StatusConfig(
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
          label: 'In Kitchen',
          icon: Icons.restaurant_rounded,
        );
      case 'PAID':
        return _StatusConfig(
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
          label: 'Paid',
          icon: Icons.qr_code_scanner_rounded,
        );
      case 'PENDING_PAYMENT':
      default:
        return _StatusConfig(
          color: AppColors.warning,
          bgColor: const Color(0xFFFEF3C7),
          label: 'Pending',
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(order.status);
    final formattedTime = order.createdAt != null
        ? DateFormat('dd/MM/yyyy · HH:mm').format(order.createdAt!.toLocal())
        : 'N/A';
    final totalQty = order.items.fold(0, (sum, item) => sum + item.quantity);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        OrderDetailScreen.routeName,
        arguments: order.id,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Order code + status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: config.bgColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(config.icon, size: 11, color: config.color),
                        const SizedBox(width: 4),
                        Text(
                          config.label,
                          style: TextStyle(
                            color: config.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Row 2: Date + Queue
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: AppColors.subText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formattedTime,
                      style: const TextStyle(
                          color: AppColors.subText, fontSize: 12),
                    ),
                  ),
                  if (order.queueNumber != 'N/A')
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            size: 12, color: AppColors.subText),
                        const SizedBox(width: 3),
                        Text(
                          'Queue ${order.queueNumber}',
                          style: const TextStyle(
                            color: AppColors.subText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              // Row 3: Items + Price + Arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items
                              .map((e) => '${e.quantity}× ${e.food.name}')
                              .join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.text,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalQty item${totalQty == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppColors.subText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        CurrencyFormatter.vnd(order.totalPrice),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.subText),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusConfig {
  final Color color;
  final Color bgColor;
  final String label;
  final IconData icon;

  _StatusConfig({
    required this.color,
    required this.bgColor,
    required this.label,
    required this.icon,
  });
}
