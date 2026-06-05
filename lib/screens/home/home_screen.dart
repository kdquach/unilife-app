import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import '../menu/always_available_screen.dart';
import '../menu/today_menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _regularFoods = [];
  Food? _menuFood;
  bool _isLoadingRegular = true;
  bool _isLoadingMenu = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadRegularFoods();
    _loadMenuFoods();
  }

  Future<void> _loadRegularFoods() async {
    if (mounted) setState(() => _isLoadingRegular = true);
    try {
      final foods = await _foodService.getAlwaysAvailableFoods();
      if (mounted) setState(() => _regularFoods = foods.take(2).toList());
    } catch (_) {
      if (mounted) setState(() => _regularFoods = []);
    } finally {
      if (mounted) setState(() => _isLoadingRegular = false);
    }
  }

  Future<void> _loadMenuFoods() async {
    if (mounted) setState(() => _isLoadingMenu = true);
    try {
      final foods = await _foodService.getTodayMenuFoods();
      if (mounted) {
        setState(() => _menuFood = foods.isNotEmpty ? foods.first : null);
      }
    } catch (_) {
      if (mounted) setState(() => _menuFood = null);
    } finally {
      if (mounted) setState(() => _isLoadingMenu = false);
    }
  }

  void _openDetail(Food food) {
    Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);
  }

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
            const Text('Good morning, Duy',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Choose today meal or daily snacks',
                style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 22),
            const TextField(
                decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search food, drinks, snacks...')),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today menu is ready',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('Order main meals and add drinks or snacks.',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SectionTitle(
                title: 'Today Menu',
                action: 'See all',
                onActionTap: () =>
                    Navigator.pushNamed(context, TodayMenuScreen.routeName)),
            _buildTodayMenuPreview(),

            const SizedBox(height: 24),
            SectionTitle(
                title: 'Always Available',
                action: 'See all',
                onActionTap: () => Navigator.pushNamed(
                    context, AlwaysAvailableScreen.routeName)),
            _buildAlwaysAvailablePreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlwaysAvailablePreview() {
    if (_isLoadingRegular) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_regularFoods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No daily foods available',
            style: TextStyle(color: AppColors.subText)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _regularFoods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, index) {
        final food = _regularFoods[index];
        return RegularFoodCard(
            food: food,
            onTap: () => _openDetail(food),
            onAdd: food.canAddToCart ? () => _add(food) : null);
      },
    );
  }

  Widget _buildTodayMenuPreview() {
    if (_isLoadingMenu) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_menuFood == null) {
      return const Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No menu foods available today',
                style: TextStyle(color: AppColors.subText)),
          ),
        ),
      );
    }

    return MenuFoodCard(
        food: _menuFood!,
        onTap: () => _openDetail(_menuFood!),
        onAdd: _menuFood!.canAddToCart ? () => _add(_menuFood!) : null);
  }
}


