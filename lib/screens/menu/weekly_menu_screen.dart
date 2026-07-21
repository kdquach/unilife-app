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
      HapticFeedback.mediumImpact();
      await ref.read(cartProvider.notifier).addItem(food);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${food.name} added to cart'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
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
    final normalized =
        values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();
    normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return normalized;
  }

  int _minPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((f) => f.price).reduce((a, b) => a < b ? a : b);
  }

  int _maxPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((f) => f.price).reduce((a, b) => a > b ? a : b);
  }

  bool _hasActiveFiltersFor(List<Food> foods) {
    return _selectedMeal != _all ||
        _selectedCategory != _all ||
        _selectedAvailability != _all ||
        _sortOption != 'default' ||
        _selectedMinPrice != null ||
        _selectedMaxPrice != null;
  }

  List<Food> _filteredFoodsFor(List<Food> foods) {
    final filtered = foods.where((food) {
      final mealOk = _selectedMeal == _all || _mealLabel(food) == _selectedMeal;
      final catOk = _selectedCategory == _all ||
          _categoryLabel(food) == _selectedCategory;
      final availOk = _selectedAvailability == _all ||
          (_selectedAvailability == 'Available' && food.canAddToCart) ||
          (_selectedAvailability == 'Sold out' && !food.canAddToCart);
      final minOk =
          _selectedMinPrice == null || food.price >= _selectedMinPrice!;
      final maxOk =
          _selectedMaxPrice == null || food.price <= _selectedMaxPrice!;
      return mealOk && catOk && availOk && minOk && maxOk;
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
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  Future<void> _openFilterSheet(List<Food> foods) async {
    final mealOptions = _uniqueOptions(foods.map(_mealLabel));
    final categoryOptions = _uniqueOptions(foods.map(_categoryLabel));
    final availableMinPrice = _minPriceFor(foods);
    final availableMaxPrice = _maxPriceFor(foods);
    final hasPriceData = foods.isNotEmpty && availableMaxPrice > 0;

    final selection = await showModalBottomSheet<_WeeklyFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeeklyFilterSheet(
        mealOptions: mealOptions,
        categoryOptions: categoryOptions,
        availableMinPrice: availableMinPrice,
        availableMaxPrice: availableMaxPrice,
        hasPriceData: hasPriceData,
        selectedMeal: _selectedMeal,
        selectedCategory: _selectedCategory,
        selectedAvailability: _selectedAvailability,
        selectedMinPrice: _selectedMinPrice,
        selectedMaxPrice: _selectedMaxPrice,
        sortOption: _sortOption,
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

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  bool _isPast(DateTime day) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return day.isBefore(t);
  }

  @override
  Widget build(BuildContext context) {
    final dayFoods = _selectedDayFoods;
    final filteredFoods = _filteredFoodsFor(dayFoods);
    final hasFilters = _hasActiveFiltersFor(dayFoods);
    final schedule = _activeScheduleFor(_selectedDay);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadWeeklySchedules,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 1,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.text),
              ),
              title: const Text(
                'Weekly Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              centerTitle: false,
              actions: [
                if (!_isLoading && _error == null && dayFoods.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip: 'Filter',
                      onPressed: () => _openFilterSheet(dayFoods),
                      icon: Stack(
                        children: [
                          const Icon(Icons.tune_rounded, color: AppColors.text),
                          if (hasFilters)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Weekly Menu',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select a day to see scheduled meals',
                      style: TextStyle(
                        color: AppColors.subText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Week day selector ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const Divider(height: 1, color: AppColors.border),
                    _WeekDayStrip(
                      weekDays: _weekDays,
                      selectedDay: _selectedDay,
                      schedules: _schedules,
                      onDaySelected: (day) =>
                          setState(() => _selectedDay = day),
                      isToday: _isToday,
                      isPast: _isPast,
                    ),
                  ],
                ),
              ),
            ),

            // ── Day info bar ────────────────────────────────────────────────
            if (!_isLoading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, d MMMM').format(_selectedDay),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                            if (schedule != null)
                              Text(
                                '${filteredFoods.length} meal${filteredFoods.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: AppColors.subText, fontSize: 12),
                              )
                            else
                              const Text(
                                'No schedule published',
                                style: TextStyle(
                                    color: AppColors.subText, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      if (hasFilters)
                        GestureDetector(
                          onTap: _resetFilters,
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Content ─────────────────────────────────────────────────────
            if (_isLoading)
              SliverFillRemaining(child: _ListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                child:
                    _ErrorView(message: _error!, onRetry: _loadWeeklySchedules),
              )
            else if (schedule == null)
              SliverFillRemaining(
                child: _EmptyView(
                  icon: Icons.event_busy_rounded,
                  title: 'No menu for this day',
                  subtitle: _isPast(_selectedDay)
                      ? 'This day has already passed.'
                      : 'No schedule has been published yet.',
                ),
              )
            else if (filteredFoods.isEmpty)
              SliverFillRemaining(
                child: _EmptyView(
                  icon: Icons.no_meals_rounded,
                  title: 'No meals match filters',
                  subtitle: 'Try resetting your filters.',
                  onReset: hasFilters ? _resetFilters : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                sliver: SliverList.separated(
                  itemCount: filteredFoods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final food = filteredFoods[i];
                    return _WeeklyFoodCard(
                      food: food,
                      onTap: () => _open(food),
                      onAdd: food.canAddToCart ? () => _add(food) : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week day strip
// ─────────────────────────────────────────────────────────────────────────────
class _WeekDayStrip extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime selectedDay;
  final List<MenuSchedule> schedules;
  final ValueChanged<DateTime> onDaySelected;
  final bool Function(DateTime) isToday;
  final bool Function(DateTime) isPast;

  const _WeekDayStrip({
    required this.weekDays,
    required this.selectedDay,
    required this.schedules,
    required this.onDaySelected,
    required this.isToday,
    required this.isPast,
  });

  bool _hasSchedule(DateTime day) {
    for (final s in schedules) {
      if (s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day &&
          s.status == 'PUBLISHED') {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: weekDays.length,
        itemBuilder: (_, i) {
          final day = weekDays[i];
          final isSelected = day.year == selectedDay.year &&
              day.month == selectedDay.month &&
              day.day == selectedDay.day;
          final today = isToday(day);
          final past = isPast(day);
          final hasSchedule = _hasSchedule(day);

          return GestureDetector(
            onTap: () => onDaySelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : today
                        ? AppColors.primarySoft
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? null
                    : today
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day), // Mon, Tue…
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : past
                              ? AppColors.subText.withValues(alpha: 0.5)
                              : AppColors.subText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : past
                              ? AppColors.subText.withValues(alpha: 0.4)
                              : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Dot if has schedule
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasSchedule
                          ? (isSelected
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.success)
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly food card
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyFoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const _WeeklyFoodCard({required this.food, this.onTap, this.onAdd});

  String? _resolveImageUrl(Food food) {
    final u = food.imageUrl;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http')) return u;
    final r = Uri.parse(ApiClient.baseUrl);
    return '${r.scheme}://${r.authority}${u.startsWith('/') ? u : '/$u'}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(food);
    final isSoldOut = !food.canAddToCart;
    final remaining = food.remainingServings;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image / placeholder
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Stack(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: imageUrl != null
                        ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(food))
                        : _imgPlaceholder(food),
                  ),
                  if (isSoldOut)
                    Container(
                      width: 110,
                      height: 110,
                      color: Colors.black.withValues(alpha: 0.4),
                      alignment: Alignment.center,
                      child: const Text(
                        'SOLD\nOUT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags
                    Row(
                      children: [
                        if (food.mealType != null)
                          _tag(food.mealType!, AppColors.primary,
                              AppColors.primarySoft),
                        if (food.category.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _tag(food.category, AppColors.subText,
                              AppColors.muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrencyFormatter.vnd(food.price),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            if (remaining != null && !isSoldOut)
                              Text(
                                '$remaining left',
                                style: const TextStyle(
                                  color: AppColors.subText,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        GestureDetector(
                          onTap: onAdd,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSoldOut
                                  ? AppColors.muted
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isSoldOut
                                  ? Icons.remove_rounded
                                  : Icons.add_rounded,
                              color:
                                  isSoldOut ? AppColors.subText : Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _imgPlaceholder(Food food) {
    return Container(
      width: 110,
      height: 110,
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu_rounded,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly filter selection data class
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyFilterSelection {
  final String meal;
  final String category;
  final String availability;
  final int? minPrice;
  final int? maxPrice;
  final String sortOption;

  const _WeeklyFilterSelection({
    required this.meal,
    required this.category,
    required this.availability,
    this.minPrice,
    this.maxPrice,
    required this.sortOption,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly filter sheet
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyFilterSheet extends StatefulWidget {
  final List<String> mealOptions;
  final List<String> categoryOptions;
  final int availableMinPrice;
  final int availableMaxPrice;
  final bool hasPriceData;
  final String selectedMeal;
  final String selectedCategory;
  final String selectedAvailability;
  final int? selectedMinPrice;
  final int? selectedMaxPrice;
  final String sortOption;

  const _WeeklyFilterSheet({
    required this.mealOptions,
    required this.categoryOptions,
    required this.availableMinPrice,
    required this.availableMaxPrice,
    required this.hasPriceData,
    required this.selectedMeal,
    required this.selectedCategory,
    required this.selectedAvailability,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.sortOption,
  });

  @override
  State<_WeeklyFilterSheet> createState() => _WeeklyFilterSheetState();
}

class _WeeklyFilterSheetState extends State<_WeeklyFilterSheet> {
  late String _meal;
  late String _category;
  late String _availability;
  late String _sortOption;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _meal = widget.selectedMeal;
    _category = widget.selectedCategory;
    _availability = widget.selectedAvailability;
    _sortOption = widget.sortOption;
    _minCtrl = TextEditingController(
        text: (widget.selectedMinPrice ?? widget.availableMinPrice).toString());
    _maxCtrl = TextEditingController(
        text: (widget.selectedMaxPrice ?? widget.availableMaxPrice).toString());
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    int? minPrice;
    int? maxPrice;
    if (widget.hasPriceData) {
      final min = int.tryParse(_minCtrl.text.trim());
      final max = int.tryParse(_maxCtrl.text.trim());
      if (min != null && max != null) {
        if (min > max) {
          setState(() => _priceError = 'Min must be ≤ Max.');
          return;
        }
        if (min != widget.availableMinPrice ||
            max != widget.availableMaxPrice) {
          minPrice = min;
          maxPrice = max;
        }
      }
    }
    Navigator.pop(
      context,
      _WeeklyFilterSelection(
        meal: _meal,
        category: _category,
        availability: _availability,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sortOption: _sortOption,
      ),
    );
  }

  void _clear() {
    setState(() {
      _meal = 'All';
      _category = 'All';
      _availability = 'All';
      _sortOption = 'default';
      _minCtrl.text = widget.availableMinPrice.toString();
      _maxCtrl.text = widget.availableMaxPrice.toString();
      _priceError = null;
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.subText)),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('Filter & Sort',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Meal ────────────────────────────────────────────
            _section(
              'Meal type',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('All', _meal == 'All',
                      () => setState(() => _meal = 'All')),
                  ...widget.mealOptions.map((m) =>
                      _chip(m, _meal == m, () => setState(() => _meal = m))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Category ────────────────────────────────────────
            _section(
              'Category',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('All', _category == 'All',
                      () => setState(() => _category = 'All')),
                  ...widget.categoryOptions.map((c) => _chip(
                      c, _category == c, () => setState(() => _category = c))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Availability ────────────────────────────────────
            _section(
              'Availability',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'Available', 'Sold out']
                    .map((opt) => _chip(opt, _availability == opt,
                        () => setState(() => _availability = opt)))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Sort ────────────────────────────────────────────
            _section(
              'Sort by',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    {'key': 'default', 'label': 'Default'},
                    {'key': 'price_asc', 'label': 'Price ↑'},
                    {'key': 'price_desc', 'label': 'Price ↓'},
                    {'key': 'name_asc', 'label': 'A → Z'},
                  ])
                    _chip(item['label']!, _sortOption == item['key'],
                        () => setState(() => _sortOption = item['key']!)),
                ],
              ),
            ),

            // ── Price ───────────────────────────────────────────
            if (widget.hasPriceData) ...[
              const SizedBox(height: 20),
              _section(
                'Price range',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${CurrencyFormatter.vnd(widget.availableMinPrice)} – ${CurrencyFormatter.vnd(widget.availableMaxPrice)}',
                      style: const TextStyle(
                          color: AppColors.subText, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: (_) =>
                                setState(() => _priceError = null),
                            decoration: InputDecoration(
                              labelText: 'Min (VND)',
                              filled: true,
                              fillColor: AppColors.muted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('–', style: TextStyle(fontSize: 18)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _maxCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: (_) =>
                                setState(() => _priceError = null),
                            decoration: InputDecoration(
                              labelText: 'Max (VND)',
                              filled: true,
                              fillColor: AppColors.muted,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_priceError != null) ...[
                      const SizedBox(height: 6),
                      Text(_priceError!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Clear all',
                        style: TextStyle(color: AppColors.subText)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Apply',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List skeleton
// ─────────────────────────────────────────────────────────────────────────────
class _ListSkeleton extends StatefulWidget {
  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: List.generate(
              5,
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error view
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.subText),
            const SizedBox(height: 16),
            const Text('Could not load schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subText, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty view
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onReset;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.subText),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subText, fontSize: 13)),
            if (onReset != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
