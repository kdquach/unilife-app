import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
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
  bool _isLoading = true;
  String? _error;
  String _selectedMeal = 'Lunch';
  String _selectedCategoryName = 'All';
  String _selectedAvailability = 'All';

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
      final foods = await _foodService.getTodayMenuFoods();
      if (!mounted) return;
      setState(() {
        _foods = foods;
        final categories = _todayCategories;
        if (_selectedCategoryName != 'All' &&
            !categories.contains(_selectedCategoryName)) {
          _selectedCategoryName = 'All';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _todayCategories {
    final categories = _foods
        .map((food) => food.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  List<Food> get _filteredFoods {
    return _foods.where((food) {
      final matchesMeal = food.mealType == _selectedMeal;
      final matchesCategory = _selectedCategoryName == 'All' ||
          food.category.toLowerCase() == _selectedCategoryName.toLowerCase();
      final matchesAvailability = _selectedAvailability == 'All' ||
          (_selectedAvailability == 'Available' && food.canAddToCart) ||
          (_selectedAvailability == 'Sold out' && !food.canAddToCart);

      return matchesMeal && matchesCategory && matchesAvailability;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedMeal != 'Lunch' ||
      _selectedCategoryName != 'All' ||
      _selectedAvailability != 'All';

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _add(Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  void _resetFilters() {
    setState(() {
      _selectedMeal = 'Lunch';
      _selectedCategoryName = 'All';
      _selectedAvailability = 'All';
    });
  }

  Future<void> _openFilterSheet() async {
    var tempMeal = _selectedMeal;
    var tempCategory = _selectedCategoryName;
    var tempAvailability = _selectedAvailability;
    final categories = _todayCategories;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter today menu',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Meal',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Breakfast', 'Lunch', 'Dinner']
                            .map(
                              (meal) => _filterChoiceChip(
                                label: meal,
                                selected: tempMeal == meal,
                                onSelected: () {
                                  setSheetState(() => tempMeal = meal);
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Category',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _filterChoiceChip(
                            label: 'All',
                            selected: tempCategory == 'All',
                            onSelected: () {
                              setSheetState(() => tempCategory = 'All');
                            },
                          ),
                          ...categories.map(
                            (category) => _filterChoiceChip(
                              label: category,
                              selected: tempCategory == category,
                              onSelected: () {
                                setSheetState(() => tempCategory = category);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Availability',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['All', 'Available', 'Sold out']
                            .map(
                              (availability) => _filterChoiceChip(
                                label: availability,
                                selected: tempAvailability == availability,
                                onSelected: () {
                                  setSheetState(
                                    () => tempAvailability = availability,
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  tempMeal = 'Lunch';
                                  tempCategory = 'All';
                                  tempAvailability = 'All';
                                });
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  _selectedMeal = tempMeal;
                                  _selectedCategoryName = tempCategory;
                                  _selectedAvailability = tempAvailability;
                                });
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Menu'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _isLoading ? null : _openFilterSheet,
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFoods,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView()
                : _buildBody(),
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
            const Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: AppColors.subText,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load today menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
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

  Widget _buildBody() {
    final filteredFoods = _filteredFoods;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Only foods scheduled for today are shown here.',
          style: TextStyle(color: AppColors.subText),
        ),
        const SizedBox(height: 16),
        if (_hasActiveFilters) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Clear filters'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChoiceChip(
                  label: 'All',
                  selected: _selectedCategoryName == 'All',
                  onSelected: () {
                    setState(() => _selectedCategoryName = 'All');
                  },
                ),
              ),
              ..._todayCategories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChoiceChip(
                    label: category,
                    selected: _selectedCategoryName == category,
                    onSelected: () {
                      setState(() => _selectedCategoryName = category);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${filteredFoods.length} item${filteredFoods.length == 1 ? '' : 's'} today',
          style: const TextStyle(color: AppColors.subText),
        ),
        const SizedBox(height: 20),
        if (filteredFoods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.no_meals_outlined,
                  size: 56,
                  color: AppColors.subText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $_selectedAvailability foods scheduled for $_selectedMeal in $_selectedCategoryName today',
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
}
