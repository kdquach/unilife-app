import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_notification.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/notification_service.dart';
import '../../services/notification_socket_service.dart';
import '../../states/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../auth/login_screen.dart';
import '../menu/menu_screen.dart';
import '../notification/notifications_screen.dart';
import '../order/order_list_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  static const String routeName = '/main';
  final int initialIndex;
  final String? initialMenuCategoryId;
  final String? initialMenuCategoryName;
  final bool initialMenuTodayOnly;

  const MainShell({
    super.key,
    this.initialIndex = 0,
    this.initialMenuCategoryId,
    this.initialMenuCategoryName,
    this.initialMenuTodayOnly = false,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _index;
  final NotificationService _notificationService =
      NotificationService(ApiClient());
  final NotificationSocketService _notificationSocketService =
      NotificationSocketService();
  StreamSubscription<UserNotification>? _notificationSubscription;
  String? _notificationToken;
  int _notificationUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _initializeNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationSocketService.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    final token = await AuthStorage.getToken();
    if (!mounted || token == null || token.isEmpty) return;
    _notificationToken = token;
    await _refreshNotificationCount();
    _notificationSubscription = _notificationSocketService.notifications.listen(
      (notification) {
        if (!mounted || notification.isRead) return;
        setState(() => _notificationUnreadCount += 1);
      },
    );
    _notificationSocketService.connect(token);
  }

  Future<void> _refreshNotificationCount() async {
    final token = _notificationToken;
    if (token == null || token.isEmpty) return;
    try {
      final result = await _notificationService.getMine(token: token, limit: 1);
      if (!mounted) return;
      setState(() => _notificationUnreadCount = result.unreadCount);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, NotificationsScreen.routeName);
    await _refreshNotificationCount();
  }

  Future<void> _handleDestinationSelected(int value) async {
    const restrictedTabs = {2, 3, 4};
    if (restrictedTabs.contains(value)) {
      final token = await AuthStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        Navigator.pushNamed(context, LoginScreen.routeName);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final int cartItemsCount = cartState.value?.totalItems ?? 0;

    final screens = [
      HomeScreen(
        unreadNotificationCount: _notificationUnreadCount,
        onNotificationTap: _openNotifications,
      ),
      MenuScreen(
        preselectedCategoryId: widget.initialMenuCategoryId,
        preselectedCategoryName: widget.initialMenuCategoryName,
        preselectedTodayOnly: widget.initialMenuTodayOnly,
      ),
      const CartScreen(showBackButton: false),
      const OrderListScreen(showBackButton: false),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        indicatorColor: AppColors.primarySoft,
        onDestinationSelected: _handleDestinationSelected,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu_rounded),
              label: 'Menu'),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: cartItemsCount > 0,
                label: Text(cartItemsCount.toString()),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartItemsCount > 0,
                label: Text(cartItemsCount.toString()),
                child: const Icon(Icons.shopping_cart_rounded),
              ),
              label: 'Cart'),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}