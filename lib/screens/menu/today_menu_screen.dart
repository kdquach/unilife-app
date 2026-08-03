import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../states/cart_provider.dart';
import '../../services/food_service.dart';
import '../food/food_detail_screen.dart';

class TodayMenuScreen extends ConsumerStatefulWidget {
  static const String routeName = '/today-menu';
  final String? preselectedCategoryName;

  const TodayMenuScreen({super.key, this.preselectedCategoryName});

  @override
  ConsumerState<TodayMenuScreen> createState() => _TodayMenuScreenState();
}

class _TodayMenuScreenState extends ConsumerState<TodayMenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _foods = [];
  bool _isLoading = true;
  String? _error;
  String _selectedMeal = 'All';
  String _selectedCategoryName = 'All';
  String _selectedAvailability = 'All';
  String _sortOption = 'default';
  int? _selectedMinPrice;
  int? _selectedMaxPrice;

  @override
  void initState() {
    super.initState();
    _selectedCategoryName = widget.preselectedCategoryName ?? 'All';
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
      setState(() => _foods = foods);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _mealTypes {
    final types = _foods.map((f) => f.mealType ?? 'Menu').toSet().toList();
    types.sort();
    return types;
  }

  List<String> get _categories {
    final cats = _foods
        .map((f) => f.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<Food> get _filteredFoods {
    final filtered = _foods.where((food) {
      final mealOk =
          _selectedMeal == 'All' || (food.mealType ?? 'Menu') == _selectedMeal;
      final catOk = _selectedCategoryName == 'All' ||
          food.category.toLowerCase() == _selectedCategoryName.toLowerCase();
      final availOk = _selectedAvailability == 'All' ||
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
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  bool get _hasActiveFilters =>
      _selectedMeal != 'All' ||
      _selectedCategoryName != 'All' ||
      _selectedAvailability != 'All' ||
      _selectedMinPrice != null ||
      _selectedMaxPrice != null ||
      _sortOption != 'default';

  int _minPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a < b ? a : b);
  }

  int _maxPriceFor(List<Food> foods) {
    if (foods.isEmpty) return 0;
    return foods.map((food) => food.price).reduce((a, b) => a > b ? a : b);
  }

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

  void _resetFilters() {
    setState(() {
      _selectedMeal = 'All';
      _selectedCategoryName = 'All';
      _selectedAvailability = 'All';
      _selectedMinPrice = null;
      _selectedMaxPrice = null;
      _sortOption = 'default';
    });
  }

  Future<void> _openFilterSheet() async {
    var tempMeal = _selectedMeal;
    var tempCategory = _selectedCategoryName;
    var tempAvailability = _selectedAvailability;
    var tempSortOption = _sortOption;
    final availableMinPrice = _minPriceFor(_foods);
    final availableMaxPrice = _maxPriceFor(_foods);
    final hasPriceRange =
        availableMaxPrice > availableMinPrice && availableMaxPrice > 0;
    final minCtrl = TextEditingController(
      text: (_selectedMinPrice ?? availableMinPrice).toString(),
    );
    final maxCtrl = TextEditingController(
      text: (_selectedMaxPrice ?? availableMaxPrice).toString(),
    );
    String? priceError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      child: Text('Filter Menu',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sheetSection(
                  title: 'Meal Type',
                  options: ['All', ..._mealTypes],
                  selected: tempMeal,
                  onSelect: (v) => setSheet(() => tempMeal = v),
                ),
                const SizedBox(height: 20),
                _sheetSection(
                  title: 'Category',
                  options: ['All', ..._categories],
                  selected: tempCategory,
                  onSelect: (v) => setSheet(() => tempCategory = v),
                ),
                const SizedBox(height: 20),
                _sheetSection(
                  title: 'Availability',
                  options: ['All', 'Available', 'Sold out'],
                  selected: tempAvailability,
                  onSelect: (v) => setSheet(() => tempAvailability = v),
                ),
                const SizedBox(height: 20),
                _sheetSection(
                  title: 'Sort by',
                  options: const [
                    'Default',
                    'Price low to high',
                    'Price high to low',
                    'Name A-Z',
                  ],
                  selected: _sortLabel(tempSortOption),
                  onSelect: (v) => setSheet(
                    () => tempSortOption = _sortOptionForLabel(v),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Price',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.subText,
                  ),
                ),
                const SizedBox(height: 10),
                if (hasPriceRange) ...[
                  if (priceError != null) ...[
                    Text(
                      priceError!,
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
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setSheet(() => priceError = null),
                          decoration: InputDecoration(
                            labelText: 'Min price',
                            suffixText: 'VND',
                            filled: true,
                            fillColor: AppColors.muted,
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
                          controller: maxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setSheet(() => priceError = null),
                          decoration: InputDecoration(
                            labelText: 'Max price',
                            suffixText: 'VND',
                            filled: true,
                            fillColor: AppColors.muted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
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
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheet(() {
                            tempMeal = 'All';
                            tempCategory = 'All';
                            tempAvailability = 'All';
                            tempSortOption = 'default';
                            minCtrl.text = availableMinPrice.toString();
                            maxCtrl.text = availableMaxPrice.toString();
                            priceError = null;
                          });
                        },
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
                        onPressed: () {
                          int? minPrice;
                          int? maxPrice;
                          if (hasPriceRange) {
                            final minText = minCtrl.text.trim();
                            final maxText = maxCtrl.text.trim();
                            final min = int.tryParse(minText);
                            final max = int.tryParse(maxText);
                            if (minText.isEmpty || maxText.isEmpty) {
                              setSheet(() => priceError =
                                  'Please enter both min and max price.');
                              return;
                            }
                            if (min == null || max == null) {
                              setSheet(() =>
                                  priceError = 'Price must be a valid number.');
                              return;
                            }
                            if (min > max) {
                              setSheet(() => priceError =
                                  'Min price must be less than or equal to max.');
                              return;
                            }
                            if (min < availableMinPrice ||
                                max > availableMaxPrice) {
                              setSheet(() => priceError =
                                  'Price must be between ${CurrencyFormatter.vnd(availableMinPrice)} and ${CurrencyFormatter.vnd(availableMaxPrice)}.');
                              return;
                            }
                            if (min != availableMinPrice ||
                                max != availableMaxPrice) {
                              minPrice = min;
                              maxPrice = max;
                            }
                          }
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedMeal = tempMeal;
                            _selectedCategoryName = tempCategory;
                            _selectedAvailability = tempAvailability;
                            _selectedMinPrice = minPrice;
                            _selectedMaxPrice = maxPrice;
                            _sortOption = tempSortOption;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Apply filters',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    minCtrl.dispose();
    maxCtrl.dispose();
  }

  String _sortLabel(String sortOption) {
    switch (sortOption) {
      case 'price_asc':
        return 'Price low to high';
      case 'price_desc':
        return 'Price high to low';
      case 'name_asc':
        return 'Name A-Z';
      default:
        return 'Default';
    }
  }

  String _sortOptionForLabel(String label) {
    switch (label) {
      case 'Price low to high':
        return 'price_asc';
      case 'Price high to low':
        return 'price_desc';
      case 'Name A-Z':
        return 'name_asc';
      default:
        return 'default';
    }
  }

  Widget _sheetSection({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.subText)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadFoods,
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
                "Today's Menu",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              centerTitle: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Filter',
                    onPressed: _isLoading ? null : _openFilterSheet,
                    icon: Stack(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.text),
                        if (_hasActiveFilters)
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Menu",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_foods.length} meals scheduled today',
                      style: const TextStyle(
                        color: AppColors.subText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Meal type tabs ─────────────────────────────────────────────
            if (!_isLoading && _error == null)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      _MealTypeTabs(
                        mealTypes: ['All', ..._mealTypes],
                        selected: _selectedMeal,
                        onSelect: (m) => setState(() => _selectedMeal = m),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Category chips ─────────────────────────────────────────────
            if (!_isLoading && _error == null && _categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 0, 0),
                  child: _CategoryChips(
                    categories: ['All', ..._categories],
                    selected: _selectedCategoryName,
                    onSelect: (c) => setState(() => _selectedCategoryName = c),
                  ),
                ),
              ),

            // ── Status bar ─────────────────────────────────────────────────
            if (!_isLoading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_filteredFoods.length} item${_filteredFoods.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.subText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_hasActiveFilters)
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Reset'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Content ───────────────────────────────────────────────────
            if (_isLoading)
              SliverFillRemaining(child: _SkeletonList())
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorView(message: _error!, onRetry: _loadFoods),
              )
            else if (_filteredFoods.isEmpty)
              SliverFillRemaining(
                child: _EmptyView(
                  icon: Icons.no_meals_rounded,
                  title: 'No meals found',
                  subtitle: 'Try adjusting your filters.',
                  onReset: _hasActiveFilters ? _resetFilters : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                sliver: SliverList.separated(
                  itemCount: _filteredFoods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final food = _filteredFoods[i];
                    return _TodayMenuCard(
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
// Meal type tabs
// ─────────────────────────────────────────────────────────────────────────────
class _MealTypeTabs extends StatelessWidget {
  final List<String> mealTypes;
  final String selected;
  final ValueChanged<String> onSelect;

  const _MealTypeTabs({
    required this.mealTypes,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
        itemCount: mealTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final m = mealTypes[i];
          final isSelected = m == selected;
          return GestureDetector(
            onTap: () => onSelect(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                m,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.subText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chips
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySoft : AppColors.muted,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.subText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today menu card – modern horizontal
// ─────────────────────────────────────────────────────────────────────────────
class _TodayMenuCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const _TodayMenuCard({required this.food, this.onTap, this.onAdd});

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
            // Image
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
                            errorBuilder: (_, __, ___) => _placeholder(food))
                        : _placeholder(food),
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
                    Row(
                      children: [
                        if (food.mealType != null)
                          _MiniTag(
                            label: food.mealType!,
                            color: AppColors.primary,
                            bgColor: AppColors.primarySoft,
                          ),
                        if (food.category.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _MiniTag(
                            label: food.category,
                            color: AppColors.subText,
                            bgColor: AppColors.muted,
                          ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                CurrencyFormatter.vnd(food.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              if (remaining != null && !isSoldOut)
                                Text(
                                  '$remaining left',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.subText,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
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

  Widget _placeholder(Food food) {
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
// Mini tag chip
// ─────────────────────────────────────────────────────────────────────────────
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _MiniTag({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton list
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
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
            const Text('Could not load menu',
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
