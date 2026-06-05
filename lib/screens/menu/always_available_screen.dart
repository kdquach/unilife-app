import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class AlwaysAvailableScreen extends StatefulWidget {
  static const String routeName = '/always-available';
  final String? preselectedCategoryName;

  const AlwaysAvailableScreen({super.key, this.preselectedCategoryName});

  @override
  State<AlwaysAvailableScreen> createState() => _AlwaysAvailableScreenState();
}

class _AlwaysAvailableScreenState extends State<AlwaysAvailableScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _foods = [];
  List<FoodCategory> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategoryName = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCategoryName != null) {
      _selectedCategoryName = widget.preselectedCategoryName!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _foodService.getAlwaysAvailableFoods(),
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

  @override
  Widget build(BuildContext context) {
    // Lọc danh sách món ăn theo danh mục đang chọn
    final filteredFoods = _selectedCategoryName == 'All'
        ? _foods
        : _foods
            .where((f) =>
                f.category.toLowerCase() == _selectedCategoryName.toLowerCase())
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Always Available')),
      body: RefreshIndicator(
        onRefresh: _loadData,
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
              'Could not load daily foods',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subText)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
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
        // Thanh chọn danh mục cuộn ngang
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
        Text(
          '${filteredFoods.length} item${filteredFoods.length > 1 ? 's' : ''} available in $_selectedCategoryName',
          style: const TextStyle(color: AppColors.subText),
        ),
        const SizedBox(height: 20),
        if (filteredFoods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_food_outlined,
                    size: 56, color: AppColors.subText),
                const SizedBox(height: 16),
                Text(
                  'No items found in $_selectedCategoryName',
                  style: const TextStyle(color: AppColors.subText),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredFoods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, index) {
              final food = filteredFoods[index];
              return RegularFoodCard(
                food: food,
                onTap: () => _open(food),
                onAdd: food.canAddToCart
                    ? () => AppState.instance.addToCart(food)
                    : null,
              );
            },
          ),
      ],
    );
  }
}
