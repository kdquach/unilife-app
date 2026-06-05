import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class TodayMenuScreen extends StatefulWidget {
  static const String routeName = '/today-menu';

  const TodayMenuScreen({super.key});

  @override
  State<TodayMenuScreen> createState() => _TodayMenuScreenState();
}

class _TodayMenuScreenState extends State<TodayMenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _foods = [];
  List<FoodCategory> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _selectedMeal = 'Lunch';
  String _selectedCategoryName = 'All';

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _foodService.getTodayMenuFoods(),
        _foodService.getFoodCategories(),
      ]);
      if (mounted) {
        setState(() {
          _foods = results[0] as List<Food>;
          _categories = results[1] as List<FoodCategory>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _add(Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    // Lọc kép: Lọc theo meal type (Breakfast/Lunch/Dinner) + Lọc theo Category
    final filteredFoods = _foods.where((f) {
      final matchesMeal = f.mealType == _selectedMeal;
      final matchesCategory = _selectedCategoryName == 'All' ||
          f.category.toLowerCase() == _selectedCategoryName.toLowerCase();
      return matchesMeal && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Today Menu')),
      body: RefreshIndicator(
        onRefresh: _loadFoods,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView()
                : _buildBody(filteredFoods),
      ),
    );
  }

  Widget _buildErrorView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 150,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.subText),
            const SizedBox(height: 16),
            const Text(
              'Could not load today menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subText)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFoods,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Food> filteredFoods) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Food sold by menu schedule',
            style: TextStyle(color: AppColors.subText)),
        const SizedBox(height: 16),

        // Lọc theo Bữa ăn (Breakfast, Lunch, Dinner)
        Row(
          children: [
            _buildMealChip('Breakfast'),
            const SizedBox(width: 10),
            _buildMealChip('Lunch'),
            const SizedBox(width: 10),
            _buildMealChip('Dinner'),
          ],
        ),
        const SizedBox(height: 16),

        // Thanh chọn danh mục cuộn ngang không chứa icon
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final categoryName = isAll ? 'All' : _categories[index - 1].name;
              final isSelected =
                  _selectedCategoryName.toLowerCase() == categoryName.toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(categoryName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategoryName = categoryName;
                      });
                    }
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Menu Food',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(
                  'Uses menuScheduleItemId, has remaining servings, can be sold out by meal session.',
                  style: TextStyle(color: AppColors.subText)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (filteredFoods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_meals_outlined,
                    size: 56, color: AppColors.subText),
                const SizedBox(height: 16),
                Text(
                  'No foods scheduled for $_selectedMeal in $_selectedCategoryName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.subText),
                ),
              ],
            ),
          )
        else
          ...filteredFoods.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MenuFoodCard(
                food: food,
                onTap: () => _open(food),
                onAdd: food.canAddToCart ? () => _add(food) : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMealChip(String meal) {
    final isSelected = _selectedMeal == meal;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMeal = meal;
        });
      },
      child: Chip(
        label: Text(meal),
        backgroundColor: isSelected ? AppColors.primary : Colors.white,
        labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w800),
        side:
            BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }
}
