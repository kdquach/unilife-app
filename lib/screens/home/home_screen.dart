import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/food_image_placeholder.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import '../menu/always_available_screen.dart';
import '../menu/today_menu_screen.dart';
import 'main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FoodService _foodService = FoodService(ApiClient());
  final TextEditingController _searchController = TextEditingController();

  List<Food> _regularFoods = [];
  List<FoodCategory> _categories = [];
  List<Food> _searchResults = [];
  Food? _menuFood;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _searchError;
  int _searchRequestId = 0;
  bool _isLoadingRegular = true;
  bool _isLoadingMenu = true;
  bool _isLoadingCategories = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadRegularFoods();
    _loadMenuFoods();
    _loadCategories();
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

  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoadingCategories = true);
    try {
      final categories = await _foodService.getFoodCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      if (mounted) setState(() => _categories = []);
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      _searchRequestId++;
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _searchError = null;
      _isSearching = true;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchFoods(query),
    );
  }

  Future<void> _searchFoods(String query) async {
    final requestId = ++_searchRequestId;
    try {
      final foods = await _foodService.searchFoods(keyword: query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = foods;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = [];
        _searchError = e.toString();
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _openDetail(Food food) {
    Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);
  }

  void _add(Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
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
              'Good morning, Duy',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose today meal or daily snacks',
              style: TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      ),
                hintText: 'Search food, drinks, snacks...',
              ),
            ),
            const SizedBox(height: 22),
            if (_searchQuery.isNotEmpty) ...[
              _buildSearchResults(),
            ] else ...[
              _buildCategoriesSection(),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today menu is ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Order main meals and add drinks or snacks.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SectionTitle(
                title: 'Today Menu',
                action: 'See all',
                onActionTap: () =>
                    Navigator.pushNamed(context, TodayMenuScreen.routeName),
              ),
              _buildTodayMenuPreview(),
              const SizedBox(height: 24),
              SectionTitle(
                title: 'Always Available',
                action: 'See all',
                onActionTap: () => Navigator.pushNamed(
                  context,
                  AlwaysAvailableScreen.routeName,
                ),
              ),
              _buildAlwaysAvailablePreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchError != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 42,
              color: AppColors.subText,
            ),
            const SizedBox(height: 10),
            const Text(
              'Could not search foods',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _searchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.subText,
            ),
            const SizedBox(height: 12),
            Text(
              'No foods found for "$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_searchResults.length} result${_searchResults.length > 1 ? 's' : ''} for "$_searchQuery"',
          style: const TextStyle(
            color: AppColors.subText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ..._searchResults.map(
          (food) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SearchFoodTile(
              food: food,
              onTap: () => _openDetail(food),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    if (_isLoadingCategories) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      MainShell.routeName,
                      arguments: {
                        'tabIndex': 1,
                        'categoryId': cat.id,
                        'categoryName': cat.name,
                        'todayOnly': true,
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
        child: Text(
          'No daily foods available',
          style: TextStyle(color: AppColors.subText),
        ),
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
          onAdd: food.canAddToCart ? () => _add(food) : null,
        );
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
            child: Text(
              'No menu foods available today',
              style: TextStyle(color: AppColors.subText),
            ),
          ),
        ),
      );
    }

    return MenuFoodCard(
      food: _menuFood!,
      onTap: () => _openDetail(_menuFood!),
      onAdd: _menuFood!.canAddToCart ? () => _add(_menuFood!) : null,
    );
  }
}

class _SearchFoodTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;

  const _SearchFoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryLabel =
        food.category.isEmpty ? food.typeLabel : food.category;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            FoodImagePlaceholder(food: food, size: 64, radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.subText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.vnd(food.price),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.subText),
          ],
        ),
      ),
    );
  }
}
