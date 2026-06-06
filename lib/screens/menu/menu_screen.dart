import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../../widgets/food_image_placeholder.dart';
import '../../widgets/section_title.dart';
import '../food/food_detail_screen.dart';
import 'always_available_screen.dart';
import 'today_menu_screen.dart';
import 'weekly_menu_screen.dart';

class MenuScreen extends StatefulWidget {
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
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _scheduledFoods = [];
  List<Food> _alwaysAvailableFoods = [];
  List<Food> _filteredFoods = [];
  List<FoodCategory> _categories = [];
  String? _filterError;
  String? _selectedCategoryId;
  int _availableMinPrice = 0;
  int _availableMaxPrice = 0;
  int _selectedMinPrice = 0;
  int _selectedMaxPrice = 0;
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';
  bool _todayOnly = false;
  bool _initialCategoryApplied = false;
  bool _isLoadingScheduled = true;
  bool _isLoadingAlways = true;
  bool _isLoadingFilterOptions = true;
  bool _isLoadingFilteredFoods = false;

  @override
  void initState() {
    super.initState();
    _todayOnly = widget.preselectedTodayOnly;
    _loadData();
  }

  Future<void> _loadData() async {
    _loadScheduledFoods();
    _loadAlwaysAvailableFoods();
    await _loadFilterOptions();
    if (_hasActiveFilters) {
      await _loadFilteredFoods();
    }
  }

  Future<void> _loadFilterOptions() async {
    if (mounted) setState(() => _isLoadingFilterOptions = true);
    try {
      final options = await _foodService.getFoodFilterOptions(kind: null);
      final categories = options.categories.isNotEmpty
          ? options.categories
          : await _foodService.getFoodCategories();
      var selectedCategoryId = _selectedCategoryId;
      if (!_initialCategoryApplied) {
        selectedCategoryId = widget.preselectedCategoryId ??
            _selectedCategoryId ??
            _categoryIdByName(categories, widget.preselectedCategoryName);
        _initialCategoryApplied = true;
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId = selectedCategoryId;
        _availableMinPrice = options.minPrice;
        _availableMaxPrice = options.maxPrice;
        _selectedMinPrice = options.minPrice;
        _selectedMaxPrice = options.maxPrice;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = [];
        _availableMinPrice = 0;
        _availableMaxPrice = 0;
        _selectedMinPrice = 0;
        _selectedMaxPrice = 0;
      });
    } finally {
      if (mounted) setState(() => _isLoadingFilterOptions = false);
    }
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
      if (mounted) {
        setState(() => _alwaysAvailableFoods = foods.take(2).toList());
      }
    } catch (_) {
      if (mounted) setState(() => _alwaysAvailableFoods = []);
    } finally {
      if (mounted) setState(() => _isLoadingAlways = false);
    }
  }

  bool get _hasPriceRange =>
      _availableMaxPrice > _availableMinPrice && _availableMaxPrice > 0;

  bool get _hasPriceFilter =>
      _hasPriceRange &&
      (_selectedMinPrice != _availableMinPrice ||
          _selectedMaxPrice != _availableMaxPrice);

  bool get _hasActiveFilters =>
      _selectedCategoryId != null ||
      _todayOnly ||
      _hasPriceFilter ||
      _sortBy != 'createdAt' ||
      _sortOrder != 'desc';

  int? get _minPriceParam => _hasPriceRange ? _selectedMinPrice : null;
  int? get _maxPriceParam => _hasPriceRange ? _selectedMaxPrice : null;

  String? _categoryIdByName(
    List<FoodCategory> categories,
    String? categoryName,
  ) {
    if (categoryName == null || categoryName.isEmpty) return null;
    for (final category in categories) {
      if (category.name.toLowerCase() == categoryName.toLowerCase()) {
        return category.id;
      }
    }
    return null;
  }

  String? _categoryNameById(String? categoryId) {
    if (categoryId == null) return null;
    for (final category in _categories) {
      if (category.id == categoryId) return category.name;
    }
    return null;
  }

  void _openDetail(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _add(Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  Future<void> _loadFilteredFoods() async {
    if (!_hasActiveFilters) return;
    if (mounted) {
      setState(() {
        _isLoadingFilteredFoods = true;
        _filterError = null;
      });
    }

    try {
      final foods = _todayOnly
          ? await _loadTodayMenuFilteredFoods()
          : await _foodService.filterFoods(
              kind: null,
              categoryId: _selectedCategoryId,
              minPrice: _minPriceParam,
              maxPrice: _maxPriceParam,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              limit: 100,
            );
      final enrichedFoods =
          _todayOnly ? foods : await _withTodayMenuContext(foods);
      if (mounted) setState(() => _filteredFoods = enrichedFoods);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filteredFoods = [];
        _filterError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoadingFilteredFoods = false);
    }
  }

  Future<List<Food>> _loadTodayMenuFilteredFoods() async {
    final categoryName = _categoryNameById(_selectedCategoryId);
    final foods = await _foodService.getTodayMenuFoods();
    final filteredFoods = foods.where((food) {
      final matchesCategory = categoryName == null ||
          food.category.toLowerCase() == categoryName.toLowerCase();
      final matchesMinPrice =
          _minPriceParam == null || food.price >= _minPriceParam!;
      final matchesMaxPrice =
          _maxPriceParam == null || food.price <= _maxPriceParam!;
      return matchesCategory && matchesMinPrice && matchesMaxPrice;
    }).toList();

    filteredFoods.sort(_compareFilteredFoods);
    return filteredFoods;
  }

  int _compareFilteredFoods(Food a, Food b) {
    var result = 0;
    if (_sortBy == 'price') {
      result = a.price.compareTo(b.price);
    } else if (_sortBy == 'name') {
      result = a.name.compareTo(b.name);
    }
    return _sortOrder == 'asc' ? result : -result;
  }

  Future<List<Food>> _withTodayMenuContext(List<Food> foods) async {
    final needsMenuContext = foods.any(
      (food) => food.isMenuFood && food.menuScheduleItemId == null,
    );
    if (!needsMenuContext) return foods;

    try {
      final todayFoods = await _foodService.getTodayMenuFoods();
      return foods.map((food) {
        if (!food.isMenuFood || food.menuScheduleItemId != null) return food;

        Food? scheduledFood;
        for (final todayFood in todayFoods) {
          if (todayFood.id == food.id && todayFood.menuScheduleItemId != null) {
            scheduledFood = todayFood;
            break;
          }
        }

        if (scheduledFood == null) return food;
        return food.copyWith(
          kind: scheduledFood.kind,
          status: scheduledFood.status,
          menuScheduleItemId: scheduledFood.menuScheduleItemId,
          remainingServings: scheduledFood.remainingServings,
          mealType: scheduledFood.mealType,
          menuDateLabel: scheduledFood.menuDateLabel,
        );
      }).toList();
    } catch (_) {
      return foods;
    }
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedCategoryId = null;
      _selectedMinPrice = _availableMinPrice;
      _selectedMaxPrice = _availableMaxPrice;
      _sortBy = 'createdAt';
      _sortOrder = 'desc';
      _todayOnly = false;
      _filterError = null;
      _filteredFoods = [];
    });
  }

  Future<void> _openFilterSheet() async {
    String? tempCategoryId = _selectedCategoryId;
    int tempMinPrice = _selectedMinPrice;
    int tempMaxPrice = _selectedMaxPrice;
    String tempSortBy = _sortBy;
    String tempSortOrder = _sortOrder;
    final minPriceController = TextEditingController(
      text: tempMinPrice.toString(),
    );
    final maxPriceController = TextEditingController(
      text: tempMaxPrice.toString(),
    );

    try {
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
                                'Filter menu',
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
                        if (_isLoadingFilterOptions)
                          const LinearProgressIndicator(minHeight: 2)
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _filterChoiceChip(
                                label: 'All',
                                selected: tempCategoryId == null,
                                onSelected: () {
                                  setSheetState(() => tempCategoryId = null);
                                },
                              ),
                              ..._categories.map(
                                (category) => _filterChoiceChip(
                                  label: category.name,
                                  selected: tempCategoryId == category.id,
                                  onSelected: () {
                                    setSheetState(
                                      () => tempCategoryId = category.id,
                                    );
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
                        if (_hasPriceRange) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minPriceController,
                                  keyboardType: TextInputType.number,
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
                                  controller: maxPriceController,
                                  keyboardType: TextInputType.number,
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
                        DropdownButtonFormField<String>(
                          initialValue: '${tempSortBy}_$tempSortOrder',
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.sort),
                          ),
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
                            setSheetState(() {
                              tempSortBy = parts.first;
                              tempSortOrder = parts.last;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setSheetState(() {
                                    tempCategoryId = null;
                                    tempMinPrice = _availableMinPrice;
                                    tempMaxPrice = _availableMaxPrice;
                                    minPriceController.text =
                                        tempMinPrice.toString();
                                    maxPriceController.text =
                                        tempMaxPrice.toString();
                                    tempSortBy = 'createdAt';
                                    tempSortOrder = 'desc';
                                  });
                                },
                                child: const Text('Clear'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final minPrice = int.tryParse(
                                        minPriceController.text.trim(),
                                      ) ??
                                      _availableMinPrice;
                                  final maxPrice = int.tryParse(
                                        maxPriceController.text.trim(),
                                      ) ??
                                      _availableMaxPrice;
                                  final nextMinPrice = minPrice <= maxPrice
                                      ? minPrice
                                      : maxPrice;
                                  final nextMaxPrice = minPrice <= maxPrice
                                      ? maxPrice
                                      : minPrice;
                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedCategoryId = tempCategoryId;
                                    _selectedMinPrice = nextMinPrice;
                                    _selectedMaxPrice = nextMaxPrice;
                                    _sortBy = tempSortBy;
                                    _sortOrder = tempSortOrder;
                                  });
                                  _loadFilteredFoods();
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
    } finally {
      minPriceController.dispose();
      maxPriceController.dispose();
    }
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
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Menu',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Filter',
                  onPressed: _openFilterSheet,
                  icon: Badge(
                    isLabelVisible: _hasActiveFilters,
                    child: const Icon(Icons.tune),
                  ),
                ),
              ],
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
                  onTap: () =>
                      Navigator.pushNamed(context, TodayMenuScreen.routeName),
                ),
                const SizedBox(width: 10),
                _Chip(
                  label: 'Weekly',
                  onTap: () =>
                      Navigator.pushNamed(context, WeeklyMenuScreen.routeName),
                ),
                const SizedBox(width: 10),
                _Chip(
                  label: 'Always',
                  onTap: () => Navigator.pushNamed(
                    context,
                    AlwaysAvailableScreen.routeName,
                  ),
                ),
              ],
            ),
            _buildFilterBar(),
            const SizedBox(height: 20),
            if (_hasActiveFilters) ...[
              _buildFilterResults(),
            ] else ...[
              const SectionTitle(title: 'Scheduled Food'),
              _buildScheduledList(),
              const SizedBox(height: 10),
              const SectionTitle(title: 'Always Available Food'),
              _buildAlwaysAvailableGrid(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Clear filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterResults() {
    if (_isLoadingFilteredFoods) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filterError != null) {
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
              'Could not load menu results',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _filterError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      );
    }

    if (_filteredFoods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 52,
              color: AppColors.subText,
            ),
            SizedBox(height: 12),
            Text(
              'No foods match this filter',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_filteredFoods.length} result${_filteredFoods.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: AppColors.subText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ..._filteredFoods.map(
          (food) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MenuFilterResultTile(
              food: food,
              onTap: () => _openDetail(food),
            ),
          ),
        ),
      ],
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
        child: Text(
          'No menu foods scheduled for today',
          style: TextStyle(color: AppColors.subText),
        ),
      );
    }

    return Column(
      children: _scheduledFoods
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

    if (_alwaysAvailableFoods.isEmpty) {
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
          onAdd: food.canAddToCart ? () => _add(food) : null,
        );
      },
    );
  }
}

class _MenuFilterResultTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;

  const _MenuFilterResultTile({required this.food, required this.onTap});

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
