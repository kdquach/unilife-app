import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../models/menu_schedule.dart';
import '../../services/api_client.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../../widgets/food_cards.dart';
import '../food/food_detail_screen.dart';

class WeeklyMenuScreen extends ConsumerStatefulWidget {
  static const String routeName = '/weekly-menu';
  final String? preselectedCategoryName;

  const WeeklyMenuScreen({super.key, this.preselectedCategoryName});

  @override
  ConsumerState<WeeklyMenuScreen> createState() => _WeeklyMenuScreenState();
}

class _WeeklyMenuScreenState extends ConsumerState<WeeklyMenuScreen> {
  static const String _all = 'All';

  final FoodService _foodService = FoodService(ApiClient());

  List<MenuSchedule> _schedules = [];
  bool _isLoading = true;
  String? _error;

  late List<DateTime> _weekDays;
  late DateTime _selectedDay;

  String _selectedMeal = _all;
  String _selectedCategory = _all;
  String _selectedAvailability = _all;
  String _sortOption = 'default';
  int? _selectedMinPrice;
  int? _selectedMaxPrice;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preselectedCategoryName ?? _all;
    _computeWeekDays();
    _loadWeeklySchedules();
  }

  void _computeWeekDays() {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    _selectedDay = DateTime(now.year, now.month, now.day);

    _weekDays = List.generate(7, (index) {
      final diff = index + 1 - currentWeekday;
      final day = now.add(Duration(days: diff));
      return DateTime(day.year, day.month, day.day);
    });
  }

  Future<void> _loadWeeklySchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final monday = _weekDays.first;
    final sunday = _weekDays.last;

    final formattedStart =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final formattedEnd =
        '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')} 23:59:59';

    try {
      final schedules = await _foodService.getWeeklyMenuSchedules(
        dateFrom: formattedStart,
        dateTo: formattedEnd,
      );
      if (mounted) setState(() => _schedules = schedules);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  MenuSchedule? _activeScheduleFor(DateTime day) {
    for (final schedule in _schedules) {
      final isSameDay = schedule.date.year == day.year &&
          schedule.date.month == day.month &&
          schedule.date.day == day.day;
      if (isSameDay && schedule.status == 'PUBLISHED') return schedule;
    }
    return null;
  }

  List<Food> get _selectedDayFoods =>
      _activeScheduleFor(_selectedDay)?.items ?? const [];

  void _open(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

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

  String _mealLabel(Food food) {
    final meal = food.mealType?.trim();
    return meal == null || meal.isEmpty ? 'Lunch' : meal;
  }

  String _categoryLabel(Food food) {
    final category = food.category.trim();
    return category.isEmpty ? 'Other' : category;
  }

  List<String> _uniqueOptions(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return normalized;
  }

  int _minPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a < b ? a : b);
  }

  int _maxPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a > b ? a : b);
  }

  bool _hasPriceDataFor(List<Food> foods) =>
      foods.isNotEmpty && _maxPriceFor(foods) > 0;

  bool _hasPriceFilterFor(List<Food> foods) {
    if (!_hasPriceDataFor(foods)) return false;
    final selectedMin = _selectedMinPrice;
    final selectedMax = _selectedMaxPrice;
    if (selectedMin == null || selectedMax == null) return false;
    return selectedMin != _minPriceFor(foods) ||
        selectedMax != _maxPriceFor(foods);
  }

  bool _hasActiveFiltersFor(List<Food> foods) {
    return _selectedMeal != _all ||
        _selectedCategory != _all ||
        _selectedAvailability != _all ||
        _sortOption != 'default' ||
        _hasPriceFilterFor(foods);
  }

  List<Food> _filteredFoodsFor(List<Food> foods) {
    final filtered = foods.where((food) {
      final matchesMeal =
          _selectedMeal == _all || _mealLabel(food) == _selectedMeal;
      final matchesCategory = _selectedCategory == _all ||
          _categoryLabel(food) == _selectedCategory;
      final matchesAvailability = _selectedAvailability == _all ||
          (_selectedAvailability == 'Available' && food.canAddToCart) ||
          (_selectedAvailability == 'Sold out' && !food.canAddToCart);
      final matchesMinPrice =
          _selectedMinPrice == null || food.price >= _selectedMinPrice!;
      final matchesMaxPrice =
          _selectedMaxPrice == null || food.price <= _selectedMaxPrice!;
      return matchesMeal &&
          matchesCategory &&
          matchesAvailability &&
          matchesMinPrice &&
          matchesMaxPrice;
    }).toList();

    switch (_sortOption) {
      case 'price_asc':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'name_asc':
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  void _resetFilters() {
    setState(() {
      _selectedMeal = _all;
      _selectedCategory = _all;
      _selectedAvailability = _all;
      _sortOption = 'default';
      _selectedMinPrice = null;
      _selectedMaxPrice = null;
    });
  }

  Future<void> _openStableFilterSheet(List<Food> foods) async {
    final selection = await showModalBottomSheet<_WeeklyFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WeeklyFilterSheet(
        foods: foods,
        selectedMeal: _selectedMeal,
        selectedCategory: _selectedCategory,
        selectedAvailability: _selectedAvailability,
        selectedMinPrice: _selectedMinPrice,
        selectedMaxPrice: _selectedMaxPrice,
        sortOption: _sortOption,
        mealLabel: _mealLabel,
        categoryLabel: _categoryLabel,
      ),
    );

    if (selection == null || !mounted) return;
    setState(() {
      _selectedMeal = selection.meal;
      _selectedCategory = selection.category;
      _selectedAvailability = selection.availability;
      _selectedMinPrice = selection.minPrice;
      _selectedMaxPrice = selection.maxPrice;
      _sortOption = selection.sortOption;
    });
  }

  // ignore: unused_element
  Future<void> _openFilterSheet(List<Food> foods) async {
    final mealOptions = _uniqueOptions(foods.map(_mealLabel));
    final categoryOptions = _uniqueOptions(foods.map(_categoryLabel));
    final availableMinPrice = _minPriceFor(foods);
    final availableMaxPrice = _maxPriceFor(foods);
    final hasPriceData = _hasPriceDataFor(foods);

    var tempMeal = _selectedMeal;
    var tempCategory = _selectedCategory;
    var tempAvailability = _selectedAvailability;
    var tempSortOption = _sortOption;
    var tempMinPrice = _selectedMinPrice ?? availableMinPrice;
    var tempMaxPrice = _selectedMaxPrice ?? availableMaxPrice;
    String? tempPriceError;

    final minPriceController = TextEditingController(
      text: hasPriceData ? tempMinPrice.toString() : '',
    );
    final maxPriceController = TextEditingController(
      text: hasPriceData ? tempMaxPrice.toString() : '',
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
                                'Filter weekly menu',
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
                        _buildSheetSection(
                          title: 'Meal',
                          children: [
                            _filterChoiceChip(
                              label: _all,
                              selected: tempMeal == _all,
                              onSelected: () {
                                setSheetState(() => tempMeal = _all);
                              },
                            ),
                            ...mealOptions.map(
                              (meal) => _filterChoiceChip(
                                label: meal,
                                selected: tempMeal == meal,
                                onSelected: () {
                                  setSheetState(() => tempMeal = meal);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSheetSection(
                          title: 'Category',
                          children: [
                            _filterChoiceChip(
                              label: _all,
                              selected: tempCategory == _all,
                              onSelected: () {
                                setSheetState(() => tempCategory = _all);
                              },
                            ),
                            ...categoryOptions.map(
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
                        const SizedBox(height: 20),
                        _buildSheetSection(
                          title: 'Availability',
                          children: [
                            for (final option in const [
                              _all,
                              'Available',
                              'Sold out',
                            ])
                              _filterChoiceChip(
                                label: option,
                                selected: tempAvailability == option,
                                onSelected: () {
                                  setSheetState(
                                    () => tempAvailability = option,
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Price',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        _PriceErrorMessage(message: tempPriceError),
                        if (hasPriceData) ...[
                          Text(
                            '${CurrencyFormatter.vnd(availableMinPrice)} - ${CurrencyFormatter.vnd(availableMaxPrice)}',
                            style: const TextStyle(
                              color: AppColors.subText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                        const SizedBox(height: 20),
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
                                  value: tempSortOption,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'default',
                                      child: Text('Schedule order'),
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
                                    setSheetState(() {
                                      tempSortOption = value;
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
                                    tempMeal = _all;
                                    tempCategory = _all;
                                    tempAvailability = _all;
                                    tempSortOption = 'default';
                                    tempMinPrice = availableMinPrice;
                                    tempMaxPrice = availableMaxPrice;
                                    minPriceController.text =
                                        hasPriceData ? '$tempMinPrice' : '';
                                    maxPriceController.text =
                                        hasPriceData ? '$tempMaxPrice' : '';
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
                                  int? minPrice;
                                  int? maxPrice;

                                  if (hasPriceData) {
                                    final minPriceText =
                                        minPriceController.text.trim();
                                    final maxPriceText =
                                        maxPriceController.text.trim();
                                    minPrice = int.tryParse(minPriceText);
                                    maxPrice = int.tryParse(maxPriceText);

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

                                    if (minPrice < availableMinPrice ||
                                        maxPrice > availableMaxPrice) {
                                      setSheetState(
                                        () => tempPriceError =
                                            'Price must be between ${CurrencyFormatter.vnd(availableMinPrice)} and ${CurrencyFormatter.vnd(availableMaxPrice)}.',
                                      );
                                      return;
                                    }
                                  }

                                  Navigator.pop(context);
                                  setState(() {
                                    _selectedMeal = tempMeal;
                                    _selectedCategory = tempCategory;
                                    _selectedAvailability = tempAvailability;
                                    _sortOption = tempSortOption;
                                    _selectedMinPrice =
                                        hasPriceData ? minPrice : null;
                                    _selectedMaxPrice =
                                        hasPriceData ? maxPrice : null;
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
    } finally {
      minPriceController.dispose();
      maxPriceController.dispose();
    }
  }

  Widget _buildSheetSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
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
    final foods = _selectedDayFoods;
    final filteredFoods = _filteredFoodsFor(foods);
    final hasActiveFilters = _hasActiveFiltersFor(foods);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Menu'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: _isLoading || _error != null
                ? null
                : () => _openStableFilterSheet(foods),
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWeeklySchedules,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView()
                : _buildBody(foods, filteredFoods, hasActiveFilters),
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
              'Could not load weekly menu',
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
              onPressed: _loadWeeklySchedules,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    List<Food> foods,
    List<Food> filteredFoods,
    bool hasActiveFilters,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Weekly meal planning schedule',
          style: TextStyle(color: AppColors.subText),
        ),
        const SizedBox(height: 16),
        _buildCalendarRow(),
        const SizedBox(height: 24),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(_selectedDay),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${filteredFoods.length} of ${foods.length} foods',
                  style: const TextStyle(
                    color: AppColors.subText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (foods.isEmpty)
          _buildEmptySchedule()
        else if (filteredFoods.isEmpty)
          _buildEmptyFilter()
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

  Widget _buildEmptySchedule() {
    return Padding(
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
          const Text(
            'No menu scheduled for this day',
            style: TextStyle(color: AppColors.subText),
          ),
          const SizedBox(height: 4),
          Text(
            'Menus are draft or not published yet.',
            style: TextStyle(
              color: AppColors.subText.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilter() {
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

  Widget _buildCalendarRow() {
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = _weekDays[index];
        final isSelected = day.year == _selectedDay.year &&
            day.month == _selectedDay.month &&
            day.day == _selectedDay.day;

        final now = DateTime.now();
        final isToday = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedDay = day;
              _selectedMinPrice = null;
              _selectedMaxPrice = null;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primarySoft.withValues(alpha: 0.3)
                      : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primarySoft
                        : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  dayNames[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  day.day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _WeeklyFilterSelection {
  final String meal;
  final String category;
  final String availability;
  final String sortOption;
  final int? minPrice;
  final int? maxPrice;

  const _WeeklyFilterSelection({
    required this.meal,
    required this.category,
    required this.availability,
    required this.sortOption,
    required this.minPrice,
    required this.maxPrice,
  });
}

class _WeeklyFilterSheet extends StatefulWidget {
  final List<Food> foods;
  final String selectedMeal;
  final String selectedCategory;
  final String selectedAvailability;
  final int? selectedMinPrice;
  final int? selectedMaxPrice;
  final String sortOption;
  final String Function(Food food) mealLabel;
  final String Function(Food food) categoryLabel;

  const _WeeklyFilterSheet({
    required this.foods,
    required this.selectedMeal,
    required this.selectedCategory,
    required this.selectedAvailability,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.sortOption,
    required this.mealLabel,
    required this.categoryLabel,
  });

  @override
  State<_WeeklyFilterSheet> createState() => _WeeklyFilterSheetState();
}

class _WeeklyFilterSheetState extends State<_WeeklyFilterSheet> {
  static const String _all = 'All';

  late final List<String> _mealOptions;
  late final List<String> _categoryOptions;
  late final int _availableMinPrice;
  late final int _availableMaxPrice;
  late final bool _hasPriceData;
  late String _meal;
  late String _category;
  late String _availability;
  late String _sortOption;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _mealOptions = _uniqueOptions(widget.foods.map(widget.mealLabel));
    _categoryOptions = _uniqueOptions(widget.foods.map(widget.categoryLabel));
    _availableMinPrice = _minPriceFor(widget.foods);
    _availableMaxPrice = _maxPriceFor(widget.foods);
    _hasPriceData = widget.foods.isNotEmpty && _availableMaxPrice > 0;
    _meal = widget.selectedMeal;
    _category = widget.selectedCategory;
    _availability = widget.selectedAvailability;
    _sortOption = widget.sortOption;
    final initialMinPrice = widget.selectedMinPrice ?? _availableMinPrice;
    final initialMaxPrice = widget.selectedMaxPrice ?? _availableMaxPrice;
    _minPriceController = TextEditingController(
      text: _hasPriceData ? initialMinPrice.toString() : '',
    );
    _maxPriceController = TextEditingController(
      text: _hasPriceData ? initialMaxPrice.toString() : '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  List<String> _uniqueOptions(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return normalized;
  }

  int _minPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a < b ? a : b);
  }

  int _maxPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a > b ? a : b);
  }

  void _clearPriceError() {
    if (_priceError == null) return;
    setState(() => _priceError = null);
  }

  void _resetFilters() {
    setState(() {
      _meal = _all;
      _category = _all;
      _availability = _all;
      _sortOption = 'default';
      _minPriceController.text = _hasPriceData ? '$_availableMinPrice' : '';
      _maxPriceController.text = _hasPriceData ? '$_availableMaxPrice' : '';
      _priceError = null;
    });
  }

  void _applyFilters() {
    int? minPrice;
    int? maxPrice;

    if (_hasPriceData) {
      final minPriceText = _minPriceController.text.trim();
      final maxPriceText = _maxPriceController.text.trim();
      minPrice = int.tryParse(minPriceText);
      maxPrice = int.tryParse(maxPriceText);

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
      if (minPrice < _availableMinPrice || maxPrice > _availableMaxPrice) {
        setState(
          () => _priceError =
              'Price must be between ${CurrencyFormatter.vnd(_availableMinPrice)} and ${CurrencyFormatter.vnd(_availableMaxPrice)}.',
        );
        return;
      }
    }

    Navigator.pop(
      context,
      _WeeklyFilterSelection(
        meal: _meal,
        category: _category,
        availability: _availability,
        sortOption: _sortOption,
        minPrice: _hasPriceData ? minPrice : null,
        maxPrice: _hasPriceData ? maxPrice : null,
      ),
    );
  }

  Widget _buildSheetSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
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
                      'Filter weekly menu',
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
              _buildSheetSection(
                title: 'Meal',
                children: [
                  _filterChoiceChip(
                    label: _all,
                    selected: _meal == _all,
                    onSelected: () => setState(() => _meal = _all),
                  ),
                  ..._mealOptions.map(
                    (meal) => _filterChoiceChip(
                      label: meal,
                      selected: _meal == meal,
                      onSelected: () => setState(() => _meal = meal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSheetSection(
                title: 'Category',
                children: [
                  _filterChoiceChip(
                    label: _all,
                    selected: _category == _all,
                    onSelected: () => setState(() => _category = _all),
                  ),
                  ..._categoryOptions.map(
                    (category) => _filterChoiceChip(
                      label: category,
                      selected: _category == category,
                      onSelected: () => setState(() => _category = category),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSheetSection(
                title: 'Availability',
                children: [
                  for (final option in const [_all, 'Available', 'Sold out'])
                    _filterChoiceChip(
                      label: option,
                      selected: _availability == option,
                      onSelected: () {
                        setState(() => _availability = option);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Price',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _PriceErrorMessage(message: _priceError),
              if (_hasPriceData) ...[
                Text(
                  '${CurrencyFormatter.vnd(_availableMinPrice)} - ${CurrencyFormatter.vnd(_availableMaxPrice)}',
                  style: const TextStyle(
                    color: AppColors.subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
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
              const SizedBox(height: 20),
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
                        value: _sortOption,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: 'default',
                            child: Text('Schedule order'),
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
                          setState(() => _sortOption = value);
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
