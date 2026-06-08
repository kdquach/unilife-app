import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String? preselectedCategoryId;
  final String? preselectedCategoryName;

  const AlwaysAvailableScreen({
    super.key,
    this.preselectedCategoryId,
    this.preselectedCategoryName,
  });

  @override
  State<AlwaysAvailableScreen> createState() => _AlwaysAvailableScreenState();
}

class _AlwaysAvailableScreenState extends State<AlwaysAvailableScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _foods = [];
  List<FoodCategory> _categories = [];
  bool _isLoading = true;
  bool _isFiltering = false;
  String? _error;
  String? _selectedCategoryId;
  int _availableMinPrice = 0;
  int _availableMaxPrice = 0;
  int _selectedMinPrice = 0;
  int _selectedMaxPrice = 0;
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final options = await _foodService.getFoodFilterOptions();
      final categories = options.categories.isNotEmpty
          ? options.categories
          : await _foodService.getFoodCategories();

      final selectedCategoryId = widget.preselectedCategoryId ??
          _selectedCategoryId ??
          _categoryIdByName(categories, widget.preselectedCategoryName);

      final minPrice = options.minPrice;
      final maxPrice = options.maxPrice;

      if (mounted) {
        setState(() {
          _categories = categories;
          _selectedCategoryId = selectedCategoryId;
          _availableMinPrice = minPrice;
          _availableMaxPrice = maxPrice;
          _selectedMinPrice = minPrice;
          _selectedMaxPrice = maxPrice;
        });
      }

      await _loadFilteredFoods(showFullScreenLoading: false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFilteredFoods({bool showFullScreenLoading = false}) async {
    if (mounted) {
      setState(() {
        if (showFullScreenLoading) {
          _isLoading = true;
        } else {
          _isFiltering = true;
        }
        _error = null;
      });
    }

    try {
      final foods = await _foodService.filterFoods(
        categoryId: _selectedCategoryId,
        minPrice: _selectedMinPrice,
        maxPrice: _selectedMaxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );
      if (mounted) setState(() => _foods = foods);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFiltering = false;
        });
      }
    }
  }

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

  String get _selectedCategoryName {
    if (_selectedCategoryId == null) return 'All';
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category.name;
    }
    return 'All';
  }

  bool get _hasPriceRange =>
      _availableMaxPrice > _availableMinPrice && _availableMaxPrice > 0;

  bool get _hasActiveFilters =>
      _selectedCategoryId != null ||
      (_hasPriceRange &&
          (_selectedMinPrice != _availableMinPrice ||
              _selectedMaxPrice != _availableMaxPrice)) ||
      _sortBy != 'createdAt' ||
      _sortOrder != 'desc';

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _add(Food food) {
    AppState.instance.addToCart(food);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
  }

  Future<void> _selectCategory(String? categoryId) async {
    if (_selectedCategoryId == categoryId) return;
    setState(() => _selectedCategoryId = categoryId);
    await _loadFilteredFoods();
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedCategoryId = null;
      _selectedMinPrice = _availableMinPrice;
      _selectedMaxPrice = _availableMaxPrice;
      _sortBy = 'createdAt';
      _sortOrder = 'desc';
    });
    await _loadFilteredFoods();
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
                                'Filter foods',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Always Available'),
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
        onRefresh: _loadData,
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
              'Could not load daily foods',
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
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChoiceChip(
                  label: 'All',
                  selected: _selectedCategoryId == null,
                  onSelected: () => _selectCategory(null),
                ),
              ),
              ..._categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChoiceChip(
                    label: category.name,
                    selected: _selectedCategoryId == category.id,
                    onSelected: () => _selectCategory(category.id),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_foods.length} item${_foods.length == 1 ? '' : 's'} in $_selectedCategoryName',
                style: const TextStyle(color: AppColors.subText),
              ),
            ),
          ],
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Clear filters'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_isFiltering)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        const SizedBox(height: 18),
        if (_foods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.no_food_outlined,
                  size: 56,
                  color: AppColors.subText,
                ),
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
            itemCount: _foods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (_, index) {
              final food = _foods[index];
              return RegularFoodCard(
                food: food,
                onTap: () => _open(food),
                onAdd: food.canAddToCart ? () => _add(food) : null,
              );
            },
          ),
      ],
    );
  }
}
