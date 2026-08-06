import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../models/menu_schedule.dart';
import '../../services/api_client.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../food/food_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Semantic palette — must stay in sync with the badges used in the cart:
//   • Orange  → primary actions (Add button, prices, "Today" tab)
//   • Blue    → "Today's Menu" (Menu Food) label & badges
//   • Green   → "Always Available" label & badges
// ─────────────────────────────────────────────────────────────────────────────
class _MenuPalette {
  static const orange = Color(0xFFF04422);
  static const orangeDark = Color(0xFFF04422);
  static const blue = Color(0xFF2F6FE4);
  static const blueSoft = Color(0xFFE8F0FE);
  static const green = Color(0xFF1FA463);
  static const greenSoft = Color(0xFFE4F6ED);
}

enum _MenuTab { today, week, always }

class MenuScreen extends ConsumerStatefulWidget {
  final String? preselectedCategoryId;
  final String? preselectedCategoryName;
  final bool preselectedTodayOnly;
  final String? initialTab;

  const MenuScreen({
    super.key,
    this.preselectedCategoryId,
    this.preselectedCategoryName,
    this.preselectedTodayOnly = false,
    this.initialTab,
  });

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  static const String _all = 'All';

  final FoodService _foodService = FoodService(ApiClient());
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  _MenuTab _selectedTab = _MenuTab.today;
  List<Food> _scheduledFoods = [];
  List<Food> _alwaysAvailableFoods = [];
  List<MenuSchedule> _weeklySchedules = [];
  late List<DateTime> _weekDays;
  late DateTime _selectedWeekDay;
  late String? _selectedCategoryName;
  String _searchText = '';
  String _searchQuery = '';
  String _todayAvailabilityFilter = _all;
  String _todaySortOption = 'default';
  String _alwaysAvailabilityFilter = _all;
  String _alwaysSortOption = 'default';
  String _weekCategoryName = _all;
  String _weekAvailabilityFilter = _all;
  String _weekSortOption = 'default';
  int? _todayMinPrice;
  int? _todayMaxPrice;
  int? _alwaysMinPrice;
  int? _alwaysMaxPrice;
  int? _weekMinPrice;
  int? _weekMaxPrice;
  bool _isLoadingScheduled = true;
  bool _isLoadingAlways = true;
  bool _isLoadingWeekly = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryName = widget.preselectedCategoryName;
    _selectedTab = _tabFromName(widget.initialTab);
    _computeWeekDays();
    _loadData();
  }

  _MenuTab _tabFromName(String? name) {
    switch (name) {
      case 'week':
        return _MenuTab.week;
      case 'always':
        return _MenuTab.always;
      case 'today':
      default:
        return _MenuTab.today;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadScheduledFoods(),
      _loadAlwaysAvailableFoods(),
      _loadWeeklySchedules(),
    ]);
  }

  Future<void> _loadScheduledFoods() async {
    if (mounted) setState(() => _isLoadingScheduled = true);
    try {
      final foods = await _foodService.getTodayMenuFoods();
      if (mounted) setState(() => _scheduledFoods = foods);
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
        setState(() => _alwaysAvailableFoods = foods);
      }
    } catch (_) {
      if (mounted) setState(() => _alwaysAvailableFoods = []);
    } finally {
      if (mounted) setState(() => _isLoadingAlways = false);
    }
  }

  void _computeWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedWeekDay = today;
    _weekDays = List.generate(7, (index) {
      final diff = index + 1 - today.weekday;
      final day = today.add(Duration(days: diff));
      return DateTime(day.year, day.month, day.day);
    });
  }

  Future<void> _loadWeeklySchedules() async {
    if (mounted) setState(() => _isLoadingWeekly = true);

    final monday = _weekDays.first;
    final sunday = _weekDays.last;
    final dateFrom =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final dateTo =
        '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')} 23:59:59';

    try {
      final schedules = await _foodService.getWeeklyMenuSchedules(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      if (mounted) setState(() => _weeklySchedules = schedules);
    } catch (_) {
      if (mounted) setState(() => _weeklySchedules = []);
    } finally {
      if (mounted) setState(() => _isLoadingWeekly = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _searchText = value);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchText = '';
      _searchQuery = '';
    });
  }

  Future<void> _handleBack() async {
    final popped = await Navigator.maybePop(context);
    if (popped || !mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/main',
      arguments: {'tabIndex': 0},
    );
  }

  void _openDetail(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  bool get _hasCategoryFilter =>
      _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty;

  bool _matchesSelectedCategory(Food food) {
    if (!_hasCategoryFilter) return true;
    return food.category.toLowerCase() == _selectedCategoryName!.toLowerCase();
  }

  bool _matchesAvailability(Food food, String filter) {
    return filter == _all ||
        (filter == 'Available' && food.canAddToCart) ||
        (filter == 'Sold out' && !food.canAddToCart);
  }

  bool _matchesCategoryName(Food food, String category) {
    return category == _all ||
        food.category.toLowerCase() == category.toLowerCase();
  }

  bool _matchesPrice(Food food, int? minPrice, int? maxPrice) {
    final minOk = minPrice == null || food.price >= minPrice;
    final maxOk = maxPrice == null || food.price <= maxPrice;
    return minOk && maxOk;
  }

  List<Food> _sortFoods(List<Food> foods, String sortOption) {
    final sorted = [...foods];
    switch (sortOption) {
      case 'price_asc':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'name_asc':
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }
    return sorted;
  }

  bool _matchesSearch(Food food) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return food.name.toLowerCase().contains(query) ||
        food.category.toLowerCase().contains(query) ||
        food.description.toLowerCase().contains(query);
  }

  List<Food> get _visibleScheduledFoods {
    final foods = _scheduledFoods
        .where(_matchesSelectedCategory)
        .where((food) => _matchesAvailability(food, _todayAvailabilityFilter))
        .where((food) => _matchesPrice(food, _todayMinPrice, _todayMaxPrice))
        .where(_matchesSearch)
        .toList();
    return _sortFoods(foods, _todaySortOption);
  }

  List<Food> get _visibleAlwaysAvailableFoods {
    final foods = _alwaysAvailableFoods
        .where(_matchesSelectedCategory)
        .where((food) => _matchesAvailability(food, _alwaysAvailabilityFilter))
        .where((food) => _matchesPrice(food, _alwaysMinPrice, _alwaysMaxPrice))
        .where(_matchesSearch)
        .toList();
    return _sortFoods(foods, _alwaysSortOption);
  }

  MenuSchedule? _activeScheduleFor(DateTime day) {
    for (final schedule in _weeklySchedules) {
      final isSameDay = schedule.date.year == day.year &&
          schedule.date.month == day.month &&
          schedule.date.day == day.day;
      if (isSameDay && schedule.status == 'PUBLISHED') return schedule;
    }
    return null;
  }

  List<Food> get _selectedWeekFoods =>
      _activeScheduleFor(_selectedWeekDay)?.items ?? const [];

  List<Food> get _visibleWeekFoods {
    final foods = _selectedWeekFoods
        .where((food) => _matchesCategoryName(food, _weekCategoryName))
        .where((food) => _matchesAvailability(food, _weekAvailabilityFilter))
        .where((food) => _matchesPrice(food, _weekMinPrice, _weekMaxPrice))
        .where(_matchesSearch)
        .toList();
    return _sortFoods(foods, _weekSortOption);
  }

  List<String> _categoryOptionsFor(List<Food> foods) {
    final categories = foods
        .map((food) => food.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [_all, ...categories];
  }

  int _minPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a < b ? a : b);
  }

  int _maxPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a > b ? a : b);
  }

  bool get _hasTodayAdvancedFilters =>
      _todayMinPrice != null ||
      _todayMaxPrice != null ||
      _todaySortOption != 'default';

  bool get _hasAlwaysAdvancedFilters =>
      _alwaysMinPrice != null ||
      _alwaysMaxPrice != null ||
      _alwaysSortOption != 'default';

  bool get _hasWeekFilters =>
      _weekCategoryName != _all ||
      _weekAvailabilityFilter != _all ||
      _weekMinPrice != null ||
      _weekMaxPrice != null ||
      _weekSortOption != 'default';

  bool get _hasCurrentTabFilters {
    switch (_selectedTab) {
      case _MenuTab.today:
        return _hasCategoryFilter ||
            _todayAvailabilityFilter != _all ||
            _hasTodayAdvancedFilters;
      case _MenuTab.week:
        return _hasWeekFilters;
      case _MenuTab.always:
        return _hasCategoryFilter ||
            _alwaysAvailabilityFilter != _all ||
            _hasAlwaysAdvancedFilters;
    }
  }

  List<Food> get _currentFilterFoods {
    switch (_selectedTab) {
      case _MenuTab.today:
        return _scheduledFoods;
      case _MenuTab.week:
        return _selectedWeekFoods;
      case _MenuTab.always:
        return _alwaysAvailableFoods;
    }
  }

  String get _currentFilterCategory {
    switch (_selectedTab) {
      case _MenuTab.week:
        return _weekCategoryName;
      case _MenuTab.today:
      case _MenuTab.always:
        return _selectedCategoryName ?? _all;
    }
  }

  String get _currentFilterAvailability {
    switch (_selectedTab) {
      case _MenuTab.today:
        return _todayAvailabilityFilter;
      case _MenuTab.week:
        return _weekAvailabilityFilter;
      case _MenuTab.always:
        return _alwaysAvailabilityFilter;
    }
  }

  String get _currentFilterSortOption {
    switch (_selectedTab) {
      case _MenuTab.today:
        return _todaySortOption;
      case _MenuTab.week:
        return _weekSortOption;
      case _MenuTab.always:
        return _alwaysSortOption;
    }
  }

  int? get _currentFilterMinPrice {
    switch (_selectedTab) {
      case _MenuTab.today:
        return _todayMinPrice;
      case _MenuTab.week:
        return _weekMinPrice;
      case _MenuTab.always:
        return _alwaysMinPrice;
    }
  }

  int? get _currentFilterMaxPrice {
    switch (_selectedTab) {
      case _MenuTab.today:
        return _todayMaxPrice;
      case _MenuTab.week:
        return _weekMaxPrice;
      case _MenuTab.always:
        return _alwaysMaxPrice;
    }
  }

  void _applyCurrentFilterSelection(_MenuFilterSelection selection) {
    setState(() {
      switch (_selectedTab) {
        case _MenuTab.today:
          _selectedCategoryName =
              selection.category == _all ? null : selection.category;
          _todayAvailabilityFilter = selection.availability;
          _todayMinPrice = selection.minPrice;
          _todayMaxPrice = selection.maxPrice;
          _todaySortOption = selection.sortOption;
          break;
        case _MenuTab.week:
          _weekCategoryName = selection.category;
          _weekAvailabilityFilter = selection.availability;
          _weekMinPrice = selection.minPrice;
          _weekMaxPrice = selection.maxPrice;
          _weekSortOption = selection.sortOption;
          break;
        case _MenuTab.always:
          _selectedCategoryName =
              selection.category == _all ? null : selection.category;
          _alwaysAvailabilityFilter = selection.availability;
          _alwaysMinPrice = selection.minPrice;
          _alwaysMaxPrice = selection.maxPrice;
          _alwaysSortOption = selection.sortOption;
          break;
      }
    });
  }

  Future<void> _openCurrentFilterSheet() async {
    final foods = _currentFilterFoods;
    final availableMinPrice = _minPriceFor(foods);
    final availableMaxPrice = _maxPriceFor(foods);
    final selection = await showModalBottomSheet<_MenuFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _MenuFilterSheet(
        categories: _categoryOptionsFor(foods),
        selectedCategory: _currentFilterCategory,
        selectedAvailability: _currentFilterAvailability,
        availableMinPrice: availableMinPrice,
        availableMaxPrice: availableMaxPrice,
        selectedMinPrice: _currentFilterMinPrice ?? availableMinPrice,
        selectedMaxPrice: _currentFilterMaxPrice ?? availableMaxPrice,
        selectedSortOption: _currentFilterSortOption,
      ),
    );

    if (selection == null || !mounted) return;
    _applyCurrentFilterSelection(selection);
  }

  Future<void> _add(Food food) async {
    try {
      HapticFeedback.mediumImpact();
      await ref.read(cartProvider.notifier).addItem(food);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${food.name} added to cart'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _MenuPalette.orange,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ─── Header ─────────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ─── Nav tiles ──────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildNavTiles()),

              // ─── Category filter chip ────────────────────────────────────────
              // ─── Scheduled (Today Menu) — BLUE section ───────────────────────
              if (_selectedTab == _MenuTab.today)
                SliverToBoxAdapter(
                  child: _buildFilterChips(
                    foods: _scheduledFoods,
                    availabilityFilter: _todayAvailabilityFilter,
                    onCategoryChanged: (category) => setState(() {
                      _selectedCategoryName =
                          category == _all ? null : category;
                    }),
                    onAvailabilityChanged: (availability) => setState(
                      () => _todayAvailabilityFilter = availability,
                    ),
                  ),
                ),
              if (_selectedTab == _MenuTab.today)
                SliverToBoxAdapter(child: _buildScheduledList()),

              // ─── Always Available — GREEN section ────────────────────────────
              if (_selectedTab == _MenuTab.week) ..._buildWeeklyTabSlivers(),

              if (_selectedTab == _MenuTab.always)
                SliverToBoxAdapter(
                  child: _buildFilterChips(
                    foods: _alwaysAvailableFoods,
                    availabilityFilter: _alwaysAvailabilityFilter,
                    onCategoryChanged: (category) => setState(() {
                      _selectedCategoryName =
                          category == _all ? null : category;
                    }),
                    onAvailabilityChanged: (availability) => setState(
                      () => _alwaysAvailabilityFilter = availability,
                    ),
                  ),
                ),
              if (_selectedTab == _MenuTab.always)
                SliverToBoxAdapter(child: _buildAlwaysAvailableGrid()),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  List<Widget> _buildWeeklyTabSlivers() {
    final selectedSchedule = _activeScheduleFor(_selectedWeekDay);
    final foods = _visibleWeekFoods;

    return [
      SliverToBoxAdapter(child: _buildWeekDaySelector()),
      if (_isLoadingWeekly)
        SliverToBoxAdapter(child: _buildFoodListLoading())
      else if (selectedSchedule == null || foods.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No menu for this day',
              subtitle: 'Please choose another day in this week.',
            ),
          ),
        )
      else
        SliverToBoxAdapter(child: _buildWeekFoodList(foods)),
    ];
  }

  Widget _buildFilterChips({
    required List<Food> foods,
    required String availabilityFilter,
    required ValueChanged<String> onCategoryChanged,
    required ValueChanged<String> onAvailabilityChanged,
  }) {
    final categories = _categoryOptionsFor(foods);
    if (_hasCategoryFilter &&
        !categories.any((category) =>
            category.toLowerCase() == _selectedCategoryName!.toLowerCase())) {
      categories.add(_selectedCategoryName!);
    }
    final selectedCategory = _selectedCategoryName ?? _all;
    final availabilityOptions = [_all, 'Available', 'Sold out'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final category = categories[index];
                return _MenuFilterChip(
                  label: category,
                  selected:
                      selectedCategory.toLowerCase() == category.toLowerCase(),
                  onSelected: () => onCategoryChanged(category),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availabilityOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final option = availabilityOptions[index];
                return _MenuFilterChip(
                  label: option,
                  selected: availabilityFilter == option,
                  compact: true,
                  onSelected: () => onAvailabilityChanged(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaySelector() {
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        itemCount: _weekDays.length,
        itemBuilder: (_, index) {
          final day = _weekDays[index];
          final selected = _isSameDay(day, _selectedWeekDay);
          final hasSchedule = _activeScheduleFor(day) != null;

          return GestureDetector(
            onTap: () => setState(() => _selectedWeekDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected ? _MenuPalette.orange : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _MenuPalette.orange : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayLabels[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.subText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasSchedule
                          ? (selected ? Colors.white : AppColors.success)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeekFoodList(List<Food> foods) {
    return _buildFoodList(
      foods,
      badgeColor: _MenuPalette.blue,
      placeholderColor: _MenuPalette.blueSoft,
      placeholderIcon: Icons.restaurant_menu_rounded,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildFoodList(
    List<Food> foods, {
    required Color badgeColor,
    required Color placeholderColor,
    required IconData placeholderIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var index = 0; index < foods.length; index++) ...[
            _MenuFoodListCard(
              food: foods[index],
              badgeColor: badgeColor,
              placeholderColor: placeholderColor,
              placeholderIcon: placeholderIcon,
              onTap: () => _openDetail(foods[index]),
              onAdd:
                  foods[index].canAddToCart ? () => _add(foods[index]) : null,
            ),
            if (index != foods.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodListLoading({int count = 3}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var index = 0; index < count; index++) ...[
            const _ShimmerCard(width: double.infinity, height: 116),
            if (index != count - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // Header
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 52,
            child: IconButton(
              onPressed: _handleBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _MenuPalette.orange,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                border: Border.all(color: _MenuPalette.orange, width: 1.2),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search meals, drinks, and deals',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB9B9B9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.subText,
                            size: 18,
                          ),
                        ),
                ),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 52,
            child: IconButton(
              tooltip: 'Filter',
              onPressed: _openCurrentFilterSheet,
              style: IconButton.styleFrom(
                backgroundColor: _hasCurrentTabFilters
                    ? AppColors.primarySoft
                    : const Color(0xFFF5F5F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: _hasCurrentTabFilters
                        ? _MenuPalette.orange
                        : AppColors.subText,
                    size: 22,
                  ),
                  if (_hasCurrentTabFilters)
                    const Positioned(
                      top: -3,
                      right: -3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _MenuPalette.orange,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 7, height: 7),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 58,
            height: 52,
            decoration: const BoxDecoration(
              color: _MenuPalette.orange,
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Nav tiles
  // Today   → orange (primary action)
  // Weekly  → neutral dark (secondary, no clash with the 3-color system)
  // Always Available → green (matches its section + cart badge)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildNavTiles() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _MenuTabButton(
            label: 'Today',
            selected: _selectedTab == _MenuTab.today,
            onTap: () => setState(() => _selectedTab = _MenuTab.today),
          ),
          _MenuTabButton(
            label: 'This Week',
            selected: _selectedTab == _MenuTab.week,
            onTap: () => setState(() => _selectedTab = _MenuTab.week),
          ),
          _MenuTabButton(
            label: 'Always Available',
            selected: _selectedTab == _MenuTab.always,
            onTap: () => setState(() => _selectedTab = _MenuTab.always),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Today Scheduled List – horizontal scroll cards (blue badge = Menu Food)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildScheduledList() {
    if (_isLoadingScheduled) {
      return _buildFoodListLoading();
    }

    final foods = _visibleScheduledFoods;

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(
          icon: Icons.no_meals_rounded,
          title: 'No menu available today',
          subtitle: 'Explore foods that are always available.',
        ),
      );
    }

    return _buildFoodList(
      foods,
      badgeColor: _MenuPalette.blue,
      placeholderColor: _MenuPalette.blueSoft,
      placeholderIcon: Icons.restaurant_menu_rounded,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Always Available Grid – 2 column (green badge = Always Available)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAlwaysAvailableGrid() {
    if (_isLoadingAlways) {
      return _buildFoodListLoading(count: 4);
    }

    final foods = _visibleAlwaysAvailableFoods;

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(
          icon: Icons.fastfood_rounded,
          title: 'No foods are currently available',
          subtitle: 'Please check again later.',
        ),
      );
    }

    return _buildFoodList(
      foods,
      badgeColor: _MenuPalette.green,
      placeholderColor: _MenuPalette.greenSoft,
      placeholderIcon: Icons.fastfood_rounded,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Tile
// ─────────────────────────────────────────────────────────────────────────────
class _MenuTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MenuTabButton({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? _MenuPalette.orange
                          : const Color(0xFF222222),
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: double.infinity,
                color: selected ? _MenuPalette.orange : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header — carries a small colored dot + accent-colored title so the
// section instantly reads as "blue = Today's Menu" / "green = Always Available"
// ─────────────────────────────────────────────────────────────────────────────
class _MenuFilterSelection {
  final String category;
  final String availability;
  final int? minPrice;
  final int? maxPrice;
  final String sortOption;

  const _MenuFilterSelection({
    required this.category,
    required this.availability,
    required this.minPrice,
    required this.maxPrice,
    required this.sortOption,
  });
}

class _MenuFilterSheet extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final String selectedAvailability;
  final int availableMinPrice;
  final int availableMaxPrice;
  final int selectedMinPrice;
  final int selectedMaxPrice;
  final String selectedSortOption;

  const _MenuFilterSheet({
    required this.categories,
    required this.selectedCategory,
    required this.selectedAvailability,
    required this.availableMinPrice,
    required this.availableMaxPrice,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.selectedSortOption,
  });

  @override
  State<_MenuFilterSheet> createState() => _MenuFilterSheetState();
}

class _MenuFilterSheetState extends State<_MenuFilterSheet> {
  late String _category;
  late String _availability;
  late String _sortOption;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  String? _priceError;

  bool get _hasPriceRange =>
      widget.availableMaxPrice > widget.availableMinPrice &&
      widget.availableMaxPrice > 0;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _availability = widget.selectedAvailability;
    _sortOption = widget.selectedSortOption;
    _minPriceController =
        TextEditingController(text: widget.selectedMinPrice.toString());
    _maxPriceController =
        TextEditingController(text: widget.selectedMaxPrice.toString());
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _clearPriceError() {
    if (_priceError == null) return;
    setState(() => _priceError = null);
  }

  void _clear() {
    setState(() {
      _category = 'All';
      _availability = 'All';
      _sortOption = 'default';
      _minPriceController.text = widget.availableMinPrice.toString();
      _maxPriceController.text = widget.availableMaxPrice.toString();
      _priceError = null;
    });
  }

  void _apply() {
    int? minPrice;
    int? maxPrice;

    if (_hasPriceRange) {
      final minText = _minPriceController.text.trim();
      final maxText = _maxPriceController.text.trim();
      final min = int.tryParse(minText);
      final max = int.tryParse(maxText);

      if (minText.isEmpty || maxText.isEmpty) {
        setState(() => _priceError = 'Please enter both min and max price.');
        return;
      }
      if (min == null || max == null) {
        setState(() => _priceError = 'Price must be a valid number.');
        return;
      }
      if (min > max) {
        setState(
          () => _priceError = 'Min price must be less than or equal to max.',
        );
        return;
      }
      if (min < widget.availableMinPrice || max > widget.availableMaxPrice) {
        setState(
          () => _priceError =
              'Price must be between ${CurrencyFormatter.vnd(widget.availableMinPrice)} and ${CurrencyFormatter.vnd(widget.availableMaxPrice)}.',
        );
        return;
      }
      if (min != widget.availableMinPrice || max != widget.availableMaxPrice) {
        minPrice = min;
        maxPrice = max;
      }
    }

    Navigator.pop(
      context,
      _MenuFilterSelection(
        category: _category,
        availability: _availability,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sortOption: _sortOption,
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      backgroundColor: const Color(0xFFF5F5F7),
      selectedColor: _MenuPalette.orange,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? _MenuPalette.orange : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                'Category',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.categories
                      .map(
                        (category) => _chip(
                          label: category,
                          selected:
                              _category.toLowerCase() == category.toLowerCase(),
                          onSelected: () => setState(() {
                            _category = category;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              _section(
                'Availability',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', 'Available', 'Sold out']
                      .map(
                        (option) => _chip(
                          label: option,
                          selected: _availability == option,
                          onSelected: () => setState(() {
                            _availability = option;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              _section(
                'Price',
                _hasPriceRange
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_priceError != null) ...[
                            Text(
                              _priceError!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _minPriceController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) => _clearPriceError(),
                                  decoration: InputDecoration(
                                    labelText: 'Min price',
                                    suffixText: 'VND',
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _maxPriceController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (_) => _clearPriceError(),
                                  decoration: InputDecoration(
                                    labelText: 'Max price',
                                    suffixText: 'VND',
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const Text(
                        'No price range available',
                        style: TextStyle(color: AppColors.subText),
                      ),
              ),
              const SizedBox(height: 20),
              _section(
                'Sort by',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in const [
                      {'key': 'default', 'label': 'Default'},
                      {'key': 'price_asc', 'label': 'Price low to high'},
                      {'key': 'price_desc', 'label': 'Price high to low'},
                      {'key': 'name_asc', 'label': 'Name A-Z'},
                    ])
                      _chip(
                        label: item['label']!,
                        selected: _sortOption == item['key'],
                        onSelected: () => setState(() {
                          _sortOption = item['key']!;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clear,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _MenuPalette.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
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

class _MenuFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onSelected;

  const _MenuFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      backgroundColor: Colors.white,
      selectedColor: AppColors.primarySoft,
      labelStyle: TextStyle(
        color: selected ? _MenuPalette.orangeDark : AppColors.text,
        fontSize: compact ? 12 : 13,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? _MenuPalette.orange : AppColors.border,
        ),
      ),
    );
  }
}

class _MenuFoodListCard extends StatelessWidget {
  final Food food;
  final Color badgeColor;
  final Color placeholderColor;
  final IconData placeholderIcon;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const _MenuFoodListCard({
    required this.food,
    required this.badgeColor,
    required this.placeholderColor,
    required this.placeholderIcon,
    this.onTap,
    this.onAdd,
  });

  String? _resolveImageUrl(Food food) {
    final imageUrl = food.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    final apiRoot = Uri.parse(ApiClient.baseUrl);
    final origin = '${apiRoot.scheme}://${apiRoot.authority}';
    final normalizedPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    return '$origin$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(food);
    final isSoldOut = !food.canAddToCart;
    final badge = food.isMenuFood ? (food.mealType ?? 'Menu') : food.category;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  if (badge.trim().isNotEmpty)
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 82),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (isSoldOut)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.32),
                        alignment: Alignment.center,
                        child: const Text(
                          'Sold Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (food.category.isNotEmpty)
                    Text(
                      food.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.subText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.vnd(food.price),
                    style: const TextStyle(
                      color: _MenuPalette.orangeDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    food.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: food.canAddToCart
                          ? AppColors.success
                          : AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 54,
              height: 36,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSoldOut ? AppColors.border : _MenuPalette.orange,
                  foregroundColor: isSoldOut ? AppColors.subText : Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 96,
      height: 96,
      color: placeholderColor,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, color: badgeColor, size: 28),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled Food Card – horizontal (Menu Food → blue badge, matches cart)
class _ShimmerCard extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerCard({required this.width, required this.height});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width == double.infinity ? null : widget.width,
          height: widget.height == double.infinity ? null : widget.height,
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.subText),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.subText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
