import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import 'always_available_screen.dart';
import 'today_menu_screen.dart';
import 'weekly_menu_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _scheduledFoods = [];
  List<Food> _alwaysAvailableFoods = [];
  bool _isLoadingScheduled = true;
  bool _isLoadingAlways = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadScheduledFoods();
    _loadAlwaysAvailableFoods();
  }

  Future<void> _loadScheduledFoods() async {
    if (mounted) setState(() => _isLoadingScheduled = true);
    try {
      final foods = await _foodService.getTodayMenuFoods();
      if (mounted) setState(() => _scheduledFoods = foods.take(2).toList());
    } catch (_) {
      if (mounted) setState(() => _scheduledFoods = []);
    } finally {
      if (mounted) setState(() => _isLoadingScheduled = false);
    }
  }

  Future<void> _loadAlwaysAvailableFoods() async {
    if (mounted) setState(() => _isLoadingAlways = true);
    try {
      final foods = await _foodService.getAlwaysAvailableFoods();
      if (mounted) setState(() => _alwaysAvailableFoods = foods.take(2).toList());
    } catch (_) {
      if (mounted) setState(() => _alwaysAvailableFoods = []);
    } finally {
      if (mounted) setState(() => _isLoadingAlways = false);
    }
  }

  void _openDetail(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _add(Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            const Text('Menu',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Scheduled meals and daily items',
                style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 20),
            Row(
              children: [
                _Chip(
                    label: 'Today',
                    selected: true,
                    onTap: () =>
                        Navigator.pushNamed(context, TodayMenuScreen.routeName)),
                const SizedBox(width: 10),
                _Chip(
                    label: 'Weekly',
                    onTap: () => Navigator.pushNamed(
                        context, WeeklyMenuScreen.routeName)),
                const SizedBox(width: 10),
                _Chip(
                    label: 'Always',
                    onTap: () => Navigator.pushNamed(
                        context, AlwaysAvailableScreen.routeName)),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Scheduled Food'),
            _buildScheduledList(),
            const SizedBox(height: 10),
            const SectionTitle(title: 'Always Available Food'),
            _buildAlwaysAvailableGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledList() {
    if (_isLoadingScheduled) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_scheduledFoods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No menu foods scheduled for today',
            style: TextStyle(color: AppColors.subText)),
      );
    }

    return Column(
      children: _scheduledFoods.map(
        (food) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MenuFoodCard(
              food: food,
              onTap: () => _openDetail(food),
              onAdd: food.canAddToCart ? () => _add(food) : null),
        ),
      ).toList(),
    );
  }

  Widget _buildAlwaysAvailableGrid() {
    if (_isLoadingAlways) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_alwaysAvailableFoods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No daily foods available',
            style: TextStyle(color: AppColors.subText)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _alwaysAvailableFoods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, index) {
        final food = _alwaysAvailableFoods[index];
        return RegularFoodCard(
            food: food,
            onTap: () => _openDetail(food),
            onAdd: food.canAddToCart ? () => _add(food) : null);
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Chip({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
