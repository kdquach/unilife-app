import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import 'always_available_screen.dart';
import 'today_menu_screen.dart';
import 'weekly_menu_screen.dart';

class MenuScreen extends ConsumerStatefulWidget {
  final String? preselectedCategoryId;
  final String? preselectedCategoryName;
  final bool preselectedTodayOnly;

  const MenuScreen({
    super.key,
    this.preselectedCategoryId,
    this.preselectedCategoryName,
    this.preselectedTodayOnly = false,
  });

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _scheduledFoods = [];
  List<Food> _alwaysAvailableFoods = [];
  late String? _selectedCategoryName;
  bool _isLoadingScheduled = true;
  bool _isLoadingAlways = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryName = widget.preselectedCategoryName;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadScheduledFoods(),
      _loadAlwaysAvailableFoods(),
    ]);
  }

  Future<void> _loadScheduledFoods() async {
    if (mounted) setState(() => _isLoadingScheduled = true);
    try {
      final foods = await _foodService.getTodayMenuFoods();
      if (mounted) setState(() => _scheduledFoods = foods);
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
      if (mounted) {
        setState(() => _alwaysAvailableFoods = foods);
      }
    } catch (_) {
      if (mounted) setState(() => _alwaysAvailableFoods = []);
    } finally {
      if (mounted) setState(() => _isLoadingAlways = false);
    }
  }

  void _openDetail(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  bool get _hasCategoryFilter =>
      _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty;

  bool _matchesSelectedCategory(Food food) {
    if (!_hasCategoryFilter) return true;
    return food.category.toLowerCase() == _selectedCategoryName!.toLowerCase();
  }

  List<Food> get _visibleScheduledFoods {
    final foods = _scheduledFoods.where(_matchesSelectedCategory).toList();
    return _hasCategoryFilter ? foods : foods.take(2).toList();
  }

  List<Food> get _visibleAlwaysAvailableFoods {
    final foods =
        _alwaysAvailableFoods.where(_matchesSelectedCategory).toList();
    return _hasCategoryFilter ? foods : foods.take(2).toList();
  }

  void _clearCategoryFilter() {
    setState(() => _selectedCategoryName = null);
  }

  void _openTodayMenu() {
    Navigator.pushNamed(
      context,
      TodayMenuScreen.routeName,
      arguments: {
        'categoryName': _selectedCategoryName,
      },
    );
  }

  void _openWeeklyMenu() {
    Navigator.pushNamed(
      context,
      WeeklyMenuScreen.routeName,
      arguments: {
        'categoryName': _selectedCategoryName,
      },
    );
  }

  void _openAlwaysAvailable() {
    Navigator.pushNamed(
      context,
      AlwaysAvailableScreen.routeName,
      arguments: {
        'categoryId': widget.preselectedCategoryId,
        'categoryName': _selectedCategoryName,
      },
    );
  }

  Future<void> _add(Food food) async {
    try {
      await ref.read(cartProvider.notifier).addItem(food);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food.name} added to cart')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            const Text(
              'Menu',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Scheduled meals and daily items',
              style: TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Chip(
                  label: 'Today',
                  selected: true,
                  onTap: _openTodayMenu,
                ),
                const SizedBox(width: 10),
                _Chip(
                  label: 'Weekly',
                  onTap: _openWeeklyMenu,
                ),
                const SizedBox(width: 10),
                _Chip(
                  label: 'Always',
                  onTap: _openAlwaysAvailable,
                ),
              ],
            ),
            if (_hasCategoryFilter) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(_selectedCategoryName!),
                  selected: true,
                  onDeleted: _clearCategoryFilter,
                  deleteIcon: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
            const SizedBox(height: 20),
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

    final foods = _visibleScheduledFoods;

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No menu foods scheduled for today',
          style: TextStyle(color: AppColors.subText),
        ),
      );
    }

    return Column(
      children: foods
          .map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MenuFoodCard(
                food: food,
                onTap: () => _openDetail(food),
                onAdd: food.canAddToCart ? () => _add(food) : null,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAlwaysAvailableGrid() {
    if (_isLoadingAlways) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final foods = _visibleAlwaysAvailableFoods;

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No daily foods available',
          style: TextStyle(color: AppColors.subText),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: foods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, index) {
        final food = foods[index];
        return RegularFoodCard(
          food: food,
          onTap: () => _openDetail(food),
          onAdd: food.canAddToCart ? () => _add(food) : null,
        );
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
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
