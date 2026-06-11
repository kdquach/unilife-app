import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_storage.dart';
import '../cart/cart_screen.dart';
import '../auth/login_screen.dart';
import '../menu/menu_screen.dart';
import '../notification/notifications_screen.dart';
import '../order/order_list_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
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
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _screens = [
      const HomeScreen(),
      MenuScreen(
        preselectedCategoryId: widget.initialMenuCategoryId,
        preselectedCategoryName: widget.initialMenuCategoryName,
        preselectedTodayOnly: widget.initialMenuTodayOnly,
      ),
      const CartScreen(showBackButton: false),
      const OrderListScreen(showBackButton: false),
      const ProfileScreen(),
    ];
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
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        indicatorColor: AppColors.primarySoft,
        onDestinationSelected: _handleDestinationSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu_rounded),
              label: 'Menu'),
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart_rounded),
              label: 'Cart'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.small(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () =>
                  Navigator.pushNamed(context, NotificationsScreen.routeName),
              child: const Icon(Icons.notifications_outlined),
            )
          : null,
    );
  }
}
