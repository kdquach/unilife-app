import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/food_image_placeholder.dart';
import '../food/food_detail_screen.dart';
import '../menu/always_available_screen.dart';
import '../menu/today_menu_screen.dart';
import 'main_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final FoodService _foodService = FoodService(ApiClient());
  final TextEditingController _searchController = TextEditingController();

  List<Food> _menuFoods = [];
  List<Food> _regularFoods = [];
  List<Food> _searchResults = [];
  List<FoodCategory> _searchCategories = [];
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _searchError;
  String? _selectedSearchCategoryId;
  int _availableSearchMinPrice = 0;
  int _availableSearchMaxPrice = 0;
  int _selectedSearchMinPrice = 0;
  int _selectedSearchMaxPrice = 0;
  String _searchSortBy = 'createdAt';
  String _searchSortOrder = 'desc';
  int _searchRequestId = 0;
  bool _isLoading = true;
  bool _isLoadingSearchFilters = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadFoods();
    _loadSearchFilterOptions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    try {
      final results = await Future.wait([
        _foodService.getTodayMenuFoods(),
        _foodService.getAlwaysAvailableFoods(),
      ]);

      if (!mounted) return;
      setState(() {
        _menuFoods = results[0].take(1).toList();
        _regularFoods = results[1].take(2).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSearchFilterOptions() async {
    if (mounted) setState(() => _isLoadingSearchFilters = true);
    try {
      final options = await _foodService.getAllFoodFilterOptions();
      final categories = options.categories.isNotEmpty
          ? options.categories
          : await _foodService.getFoodCategories();
      if (!mounted) return;
      setState(() {
        _searchCategories = categories;
        _availableSearchMinPrice = options.minPrice;
        _availableSearchMaxPrice = options.maxPrice;
        _selectedSearchMinPrice = options.minPrice;
        _selectedSearchMaxPrice = options.maxPrice;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchCategories = [];
        _availableSearchMinPrice = 0;
        _availableSearchMaxPrice = 0;
        _selectedSearchMinPrice = 0;
        _selectedSearchMaxPrice = 0;
      });
    } finally {
      if (mounted) setState(() => _isLoadingSearchFilters = false);
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
      final foods = await _foodService.searchFoods(
        keyword: query,
        categoryId: _selectedSearchCategoryId,
        minPrice: _searchMinPriceParam,
        maxPrice: _searchMaxPriceParam,
        sortBy: _searchSortBy,
        sortOrder: _searchSortOrder,
      );
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

  bool get _hasSearchPriceRange =>
      _availableSearchMaxPrice > _availableSearchMinPrice &&
      _availableSearchMaxPrice > 0;

  bool get _hasSearchPriceFilter =>
      _hasSearchPriceRange &&
      (_selectedSearchMinPrice != _availableSearchMinPrice ||
          _selectedSearchMaxPrice != _availableSearchMaxPrice);

  bool get _hasActiveSearchFilters =>
      _selectedSearchCategoryId != null ||
      _hasSearchPriceFilter ||
      _searchSortBy != 'createdAt' ||
      _searchSortOrder != 'desc';

  int? get _searchMinPriceParam =>
      _hasSearchPriceFilter ? _selectedSearchMinPrice : null;

  int? get _searchMaxPriceParam =>
      _hasSearchPriceFilter ? _selectedSearchMaxPrice : null;

  void _refreshSearchIfNeeded() {
    if (_searchQuery.isEmpty) return;
    setState(() => _isSearching = true);
    _searchFoods(_searchQuery);
  }

  Future<void> _openSearchFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _SearchFilterSheet(
          categories: _searchCategories,
          isLoadingCategories: _isLoadingSearchFilters,
          selectedCategoryId: _selectedSearchCategoryId,
          availableMinPrice: _availableSearchMinPrice,
          availableMaxPrice: _availableSearchMaxPrice,
          selectedMinPrice: _selectedSearchMinPrice,
          selectedMaxPrice: _selectedSearchMaxPrice,
          sortBy: _searchSortBy,
          sortOrder: _searchSortOrder,
          onApply: (selection) {
            if (!mounted) return;
            setState(() {
              _selectedSearchCategoryId = selection.categoryId;
              _selectedSearchMinPrice = selection.minPrice;
              _selectedSearchMaxPrice = selection.maxPrice;
              _searchSortBy = selection.sortBy;
              _searchSortOrder = selection.sortOrder;
            });
            _refreshSearchIfNeeded();
          },
        );
      },
    );
  }

  void _openDetail(BuildContext context, Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _openMenuCategory(FoodCategory category) {
    Navigator.pushNamed(
      context,
      MainShell.routeName,
      arguments: {
        'tabIndex': 1,
        'categoryId': category.id,
        'categoryName': category.name,
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Food food) async {
    try {
      await ref.read(cartProvider.notifier).addItem(food);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food.name} added to cart')),
      );
    } catch (e) {
      if (!context.mounted) return;
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F8),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final menuFood = _menuFoods.isNotEmpty ? _menuFoods.first : null;
    final regularFoods = _regularFoods;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _TopBar(),
            _SearchBar(
              controller: _searchController,
              query: _searchQuery,
              hasActiveFilters: _hasActiveSearchFilters,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
              onFilterTap: _openSearchFilterSheet,
            ),
            const SizedBox(height: 12),
            if (_searchQuery.isNotEmpty)
              _SearchResults(
                isSearching: _isSearching,
                error: _searchError,
                query: _searchQuery,
                foods: _searchResults,
                onFoodTap: (food) => _openDetail(context, food),
              )
            else ...[
              _PromoBanner(),
              _SectionHeader(
                title: 'Categories',
                action: 'See all',
                onAction: () {},
              ),
              _CategoryRow(
                categories: _searchCategories,
                onCategoryTap: _openMenuCategory,
              ),
              _SectionHeader(
                title: 'Today Menu',
                action: 'See all',
                onAction: () =>
                    Navigator.pushNamed(context, TodayMenuScreen.routeName),
              ),
              if (menuFood != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MenuFoodCard(
                    food: menuFood,
                    onTap: () => _openDetail(context, menuFood),
                    onAdd: menuFood.canAddToCart
                        ? () => _add(context, ref, menuFood)
                        : null,
                  ),
                ),
              _SectionHeader(
                title: 'Always Available',
                action: 'See all',
                onAction: () => Navigator.pushNamed(
                  context,
                  AlwaysAvailableScreen.routeName,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: regularFoods.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (_, i) {
                    final food = regularFoods[i];
                    return RegularFoodCard(
                      food: food,
                      onTap: () => _openDetail(context, food),
                      onAdd: food.canAddToCart
                          ? () => _add(context, ref, food)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, Student!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Nguyen Van A',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          _IconCircle(
            child: const Icon(Icons.notifications_outlined, size: 20),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            alignment: Alignment.center,
            child: const Text(
              'NA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final Widget child;

  const _IconCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5F5F5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final bool hasActiveFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;

  const _SearchBar({
    required this.controller,
    required this.query,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onClear,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 22, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search food, drinks, snacks...',
                hintStyle: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filter',
            onPressed: onFilterTap,
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              child: const Icon(Icons.tune_rounded, size: 18),
            ),
            color: AppColors.primary,
          ),
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final bool isSearching;
  final String? error;
  final String query;
  final List<Food> foods;
  final ValueChanged<Food> onFoodTap;

  const _SearchResults({
    required this.isSearching,
    required this.error,
    required this.query,
    required this.foods,
    required this.onFoodTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not search foods: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    if (foods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 42),
        child: Text(
          'No foods found for "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.subText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${foods.length} result${foods.length == 1 ? '' : 's'} for "$query"',
            style: const TextStyle(
              color: AppColors.subText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...foods.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SearchFoodTile(
                food: food,
                onTap: () => onFoodTap(food),
              ),
            ),
          ),
        ],
      ),
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

class _SearchFilterSelection {
  final String? categoryId;
  final int minPrice;
  final int maxPrice;
  final String sortBy;
  final String sortOrder;

  const _SearchFilterSelection({
    required this.categoryId,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.sortOrder,
  });
}

class _SearchFilterSheet extends StatefulWidget {
  final List<FoodCategory> categories;
  final bool isLoadingCategories;
  final String? selectedCategoryId;
  final int availableMinPrice;
  final int availableMaxPrice;
  final int selectedMinPrice;
  final int selectedMaxPrice;
  final String sortBy;
  final String sortOrder;
  final ValueChanged<_SearchFilterSelection> onApply;

  const _SearchFilterSheet({
    required this.categories,
    required this.isLoadingCategories,
    required this.selectedCategoryId,
    required this.availableMinPrice,
    required this.availableMaxPrice,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.sortBy,
    required this.sortOrder,
    required this.onApply,
  });

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late String? _categoryId;
  late int _minPrice;
  late int _maxPrice;
  late String _sortBy;
  late String _sortOrder;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  String? _priceError;

  bool get _hasPriceRange =>
      widget.availableMaxPrice > widget.availableMinPrice &&
      widget.availableMaxPrice > 0;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.selectedCategoryId;
    _minPrice = widget.selectedMinPrice;
    _maxPrice = widget.selectedMaxPrice;
    _sortBy = widget.sortBy;
    _sortOrder = widget.sortOrder;
    _minPriceController = TextEditingController(text: _minPrice.toString());
    _maxPriceController = TextEditingController(text: _maxPrice.toString());
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _categoryId = null;
      _minPrice = widget.availableMinPrice;
      _maxPrice = widget.availableMaxPrice;
      _minPriceController.text = _minPrice.toString();
      _maxPriceController.text = _maxPrice.toString();
      _sortBy = 'createdAt';
      _sortOrder = 'desc';
      _priceError = null;
    });
  }

  void _setPriceError(String message) {
    setState(() => _priceError = message);
  }

  void _clearPriceError() {
    if (_priceError == null) return;
    setState(() => _priceError = null);
  }

  void _applyFilters() {
    final minPriceText = _minPriceController.text.trim();
    final maxPriceText = _maxPriceController.text.trim();
    final minPrice = int.tryParse(minPriceText);
    final maxPrice = int.tryParse(maxPriceText);

    if (_hasPriceRange) {
      if (minPriceText.isEmpty || maxPriceText.isEmpty) {
        _setPriceError('Please enter both min and max price.');
        return;
      }

      if (minPrice == null || maxPrice == null) {
        _setPriceError('Price must be a valid number.');
        return;
      }

      if (minPrice > maxPrice) {
        _setPriceError('Min price must be less than or equal to max price.');
        return;
      }

      if (minPrice < widget.availableMinPrice ||
          maxPrice > widget.availableMaxPrice) {
        _setPriceError(
          'Price must be between ${CurrencyFormatter.vnd(widget.availableMinPrice)} and ${CurrencyFormatter.vnd(widget.availableMaxPrice)}.',
        );
        return;
      }
    }

    widget.onApply(
      _SearchFilterSelection(
        categoryId: _categoryId,
        minPrice: minPrice ?? widget.availableMinPrice,
        maxPrice: maxPrice ?? widget.availableMaxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );
    Navigator.pop(context);
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
    final sortValue = '${_sortBy}_$_sortOrder';

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
                      'Filter search',
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
                'Category',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (widget.isLoadingCategories)
                const LinearProgressIndicator(minHeight: 2)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChoiceChip(
                      label: 'All',
                      selected: _categoryId == null,
                      onSelected: () => setState(() => _categoryId = null),
                    ),
                    ...widget.categories.map(
                      (category) => _filterChoiceChip(
                        label: category.name,
                        selected: _categoryId == category.id,
                        onSelected: () {
                          setState(() => _categoryId = category.id);
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 22),
              const Text(
                'Price',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _PriceErrorMessage(message: _priceError),
              if (_hasPriceRange) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _clearPriceError(),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Min price',
                          suffixText: 'VND',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _clearPriceError(),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Max price',
                          suffixText: 'VND',
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                const Text(
                  'No price range available',
                  style: TextStyle(color: AppColors.subText),
                ),
              const SizedBox(height: 18),
              const Text(
                'Sort by',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sort, color: AppColors.subText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: sortValue,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: 'createdAt_desc',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'price_asc',
                            child: Text('Price low to high'),
                          ),
                          DropdownMenuItem(
                            value: 'price_desc',
                            child: Text('Price high to low'),
                          ),
                          DropdownMenuItem(
                            value: 'name_asc',
                            child: Text('Name A-Z'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          final parts = value.split('_');
                          setState(() {
                            _sortBy = parts.first;
                            _sortOrder = parts.last;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
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
  }
}

class _PriceErrorMessage extends StatelessWidget {
  final String? message;

  const _PriceErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: message == null ? 0 : 8),
      child: Text(
        message ?? '',
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TODAY'S DEAL",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Text(
                    'Only at\nCanteen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Order Now!',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 120,
            color: const Color(0xFFE85C00),
            alignment: Alignment.center,
            child: const Icon(
              Icons.fastfood_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<FoodCategory> categories;
  final ValueChanged<FoodCategory> onCategoryTap;

  const _CategoryRow({
    required this.categories,
    required this.onCategoryTap,
  });

  IconData _iconFor(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('rice')) return Icons.rice_bowl_rounded;
    if (lowerName.contains('drink') ||
        lowerName.contains('tea') ||
        lowerName.contains('water')) {
      return Icons.local_drink_rounded;
    }
    if (lowerName.contains('snack')) return Icons.cookie_rounded;
    if (lowerName.contains('noodle')) return Icons.ramen_dining_rounded;
    if (lowerName.contains('fruit')) return Icons.apple_rounded;
    return Icons.fastfood_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories
        .where((category) => category.isActive && category.name.isNotEmpty)
        .toList();

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: visibleCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final category = visibleCategories[i];
          final icon = _iconFor(category.name);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onCategoryTap(category),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEBEBEB),
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 22,
                    color: const Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
