import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../states/cart_provider.dart';
import '../../services/food_service.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class AlwaysAvailableScreen extends ConsumerStatefulWidget {
  static const String routeName = '/always-available';
  final String? preselectedCategoryId;
  final String? preselectedCategoryName;

  const AlwaysAvailableScreen({
    super.key,
    this.preselectedCategoryId,
    this.preselectedCategoryName,
  });

  @override
  ConsumerState<AlwaysAvailableScreen> createState() =>
      _AlwaysAvailableScreenState();
}

class _AlwaysAvailableScreenState extends ConsumerState<AlwaysAvailableScreen> {
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
        minPrice: _minPriceParam,
        maxPrice: _maxPriceParam,
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

  bool get _hasPriceFilter =>
      _hasPriceRange &&
      (_selectedMinPrice != _availableMinPrice ||
          _selectedMaxPrice != _availableMaxPrice);

  bool get _hasActiveFilters =>
      _selectedCategoryId != null ||
      _hasPriceFilter ||
      _sortBy != 'createdAt' ||
      _sortOrder != 'desc';

  int? get _minPriceParam => _hasPriceFilter ? _selectedMinPrice : null;

  int? get _maxPriceParam => _hasPriceFilter ? _selectedMaxPrice : null;

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  Future<void> _add(Food food) async {
    try {
      await ref.read(cartProvider.notifier).addItem(food);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
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

  Future<void> _openStableFilterSheet() async {
    final selection =
        await showModalBottomSheet<_AlwaysAvailableFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AlwaysAvailableFilterSheet(
        categories: _categories,
        selectedCategoryId: _selectedCategoryId,
        availableMinPrice: _availableMinPrice,
        availableMaxPrice: _availableMaxPrice,
        selectedMinPrice: _selectedMinPrice,
        selectedMaxPrice: _selectedMaxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );

    if (selection == null || !mounted) return;
    setState(() {
      _selectedCategoryId = selection.categoryId;
      _selectedMinPrice = selection.minPrice;
      _selectedMaxPrice = selection.maxPrice;
      _sortBy = selection.sortBy;
      _sortOrder = selection.sortOrder;
    });
    await _loadFilteredFoods();
  }

  // ignore: unused_element
  Future<void> _openFilterSheet() async {
    String? tempCategoryId = _selectedCategoryId;
    int tempMinPrice = _selectedMinPrice;
    int tempMaxPrice = _selectedMaxPrice;
    String tempSortBy = _sortBy;
    String tempSortOrder = _sortOrder;
    String? tempPriceError;
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
                        _PriceErrorMessage(message: tempPriceError),
                        if (_hasPriceRange) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minPriceController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    if (tempPriceError == null) return;
                                    setSheetState(() => tempPriceError = null);
                                  },
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
                                  onChanged: (_) {
                                    if (tempPriceError == null) return;
                                    setSheetState(() => tempPriceError = null);
                                  },
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
                                  value: '${tempSortBy}_$tempSortOrder',
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
                                    setSheetState(() {
                                      tempSortBy = parts.first;
                                      tempSortOrder = parts.last;
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
                                    tempPriceError = null;
                                  });
                                },
                                child: const Text('Clear'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final minPriceText =
                                      minPriceController.text.trim();
                                  final maxPriceText =
                                      maxPriceController.text.trim();
                                  final minPrice = int.tryParse(minPriceText);
                                  final maxPrice = int.tryParse(maxPriceText);

                                  if (_hasPriceRange) {
                                    if (minPriceText.isEmpty ||
                                        maxPriceText.isEmpty) {
                                      setSheetState(
                                        () => tempPriceError =
                                            'Please enter both min and max price.',
                                      );
                                      return;
                                    }

                                    if (minPrice == null || maxPrice == null) {
                                      setSheetState(
                                        () => tempPriceError =
                                            'Price must be a valid number.',
                                      );
                                      return;
                                    }

                                    if (minPrice > maxPrice) {
                                      setSheetState(
                                        () => tempPriceError =
                                            'Min price must be less than or equal to max price.',
                                      );
                                      return;
                                    }

                                    if (minPrice < _availableMinPrice ||
                                        maxPrice > _availableMaxPrice) {
                                      setSheetState(
                                        () => tempPriceError =
                                            'Price must be between ${CurrencyFormatter.vnd(_availableMinPrice)} and ${CurrencyFormatter.vnd(_availableMaxPrice)}.',
                                      );
                                      return;
                                    }
                                  }

                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedCategoryId = tempCategoryId;
                                    _selectedMinPrice =
                                        minPrice ?? _availableMinPrice;
                                    _selectedMaxPrice =
                                        maxPrice ?? _availableMaxPrice;
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
            onPressed: _isLoading ? null : _openStableFilterSheet,
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

class _AlwaysAvailableFilterSelection {
  final String? categoryId;
  final int minPrice;
  final int maxPrice;
  final String sortBy;
  final String sortOrder;

  const _AlwaysAvailableFilterSelection({
    required this.categoryId,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.sortOrder,
  });
}

class _AlwaysAvailableFilterSheet extends StatefulWidget {
  final List<FoodCategory> categories;
  final String? selectedCategoryId;
  final int availableMinPrice;
  final int availableMaxPrice;
  final int selectedMinPrice;
  final int selectedMaxPrice;
  final String sortBy;
  final String sortOrder;

  const _AlwaysAvailableFilterSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.availableMinPrice,
    required this.availableMaxPrice,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.sortBy,
    required this.sortOrder,
  });

  @override
  State<_AlwaysAvailableFilterSheet> createState() =>
      _AlwaysAvailableFilterSheetState();
}

class _AlwaysAvailableFilterSheetState
    extends State<_AlwaysAvailableFilterSheet> {
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
        setState(
          () => _priceError = 'Please enter both min and max price.',
        );
        return;
      }
      if (minPrice == null || maxPrice == null) {
        setState(() => _priceError = 'Price must be a valid number.');
        return;
      }
      if (minPrice > maxPrice) {
        setState(
          () => _priceError =
              'Min price must be less than or equal to max price.',
        );
        return;
      }
      if (minPrice < widget.availableMinPrice ||
          maxPrice > widget.availableMaxPrice) {
        setState(
          () => _priceError =
              'Price must be between ${CurrencyFormatter.vnd(widget.availableMinPrice)} and ${CurrencyFormatter.vnd(widget.availableMaxPrice)}.',
        );
        return;
      }
    }

    Navigator.pop(
      context,
      _AlwaysAvailableFilterSelection(
        categoryId: _categoryId,
        minPrice: minPrice ?? widget.availableMinPrice,
        maxPrice: maxPrice ?? widget.availableMaxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
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
