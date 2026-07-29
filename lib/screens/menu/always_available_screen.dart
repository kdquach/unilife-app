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
    final selection = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        categories: _categories,
        selectedCategoryId: _selectedCategoryId,
        availableMinPrice: _availableMinPrice,
        availableMaxPrice: _availableMaxPrice,
        selectedMinPrice: _selectedMinPrice,
        selectedMaxPrice: _selectedMaxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        hasPriceRange: _hasPriceRange,
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

  String get _sortLabel {
    switch ('${_sortBy}_$_sortOrder') {
      case 'price_asc':
        return 'Price ↑';
      case 'price_desc':
        return 'Price ↓';
      case 'name_asc':
        return 'A → Z';
      default:
        return 'Newest';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
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
                'Always Available',
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
                    tooltip: 'Filter & Sort',
                    onPressed:
                        (_isLoading || _isFiltering) ? null : _openFilterSheet,
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
                  children: const [
                    Text(
                      'Always Available',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Daily items available anytime',
                      style: TextStyle(
                        color: AppColors.subText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category chips ──────────────────────────────────────────────
            if (!_isLoading && _error == null && _categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const Divider(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
                      child: SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 20),
                          itemCount: _categories.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final isAll = i == 0;
                            final cat = isAll ? null : _categories[i - 1];
                            final isSelected = isAll
                                ? _selectedCategoryId == null
                                : _selectedCategoryId == cat!.id;
                            return GestureDetector(
                              onTap: () =>
                                  _selectCategory(isAll ? null : cat!.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primarySoft
                                      : AppColors.muted,
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.primary, width: 1.5)
                                      : null,
                                ),
                                child: Text(
                                  isAll ? 'All' : cat!.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.subText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Status bar ──────────────────────────────────────────────────
            if (!_isLoading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_foods.length} item${_foods.length == 1 ? '' : 's'} · $_selectedCategoryName · $_sortLabel',
                          style: const TextStyle(
                              color: AppColors.subText, fontSize: 12),
                        ),
                      ),
                      if (_hasActiveFilters)
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

            // ── Filtering indicator ─────────────────────────────────────────
            if (_isFiltering)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
                ),
              ),

            // ── Content ─────────────────────────────────────────────────────
            if (_isLoading)
              SliverFillRemaining(child: _ListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                child: _ErrorView(message: _error!, onRetry: _loadData),
              )
            else if (_foods.isEmpty)
              SliverFillRemaining(
                child: _EmptyView(
                  icon: Icons.no_food_rounded,
                  title: 'No items found',
                  subtitle: 'Try a different category or reset filters.',
                  onReset: _hasActiveFilters ? _resetFilters : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                sliver: SliverList.separated(
                  itemCount: _foods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final food = _foods[i];
                    return _AlwaysAvailableCard(
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
// Always Available food card (grid)
// ─────────────────────────────────────────────────────────────────────────────
class _AlwaysAvailableCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const _AlwaysAvailableCard({required this.food, this.onTap, this.onAdd});

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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 124),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 0.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(18)),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 112,
                      height: 124,
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                    if (isSoldOut)
                      Container(
                        width: 112,
                        height: 124,
                        color: Colors.black.withValues(alpha: 0.38),
                        alignment: Alignment.center,
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (food.category.isNotEmpty)
                            Flexible(
                              child: _MiniTag(
                                label: food.category,
                                color: AppColors.primary,
                                bgColor: AppColors.primarySoft,
                              ),
                            ),
                          const Spacer(),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            food.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        food.statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              isSoldOut ? AppColors.error : AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              CurrencyFormatter.vnd(food.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 76,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: onAdd,
                              style: ElevatedButton.styleFrom(
                                fixedSize: const Size(76, 36),
                                minimumSize: const Size(76, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: isSoldOut
                                    ? AppColors.muted
                                    : AppColors.primary,
                                foregroundColor: isSoldOut
                                    ? AppColors.subText
                                    : Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 112,
      height: 124,
      color: AppColors.muted,
      alignment: Alignment.center,
      child: Icon(
        Icons.fastfood_rounded,
        color: AppColors.subText.withValues(alpha: 0.5),
        size: 36,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter selection data class
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FilterSelection {
  final String? categoryId;
  final int minPrice;
  final int maxPrice;
  final String sortBy;
  final String sortOrder;

  const _FilterSelection({
    this.categoryId,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.sortOrder,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<FoodCategory> categories;
  final String? selectedCategoryId;
  final int availableMinPrice;
  final int availableMaxPrice;
  final int selectedMinPrice;
  final int selectedMaxPrice;
  final String sortBy;
  final String sortOrder;
  final bool hasPriceRange;

  const _FilterSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.availableMinPrice,
    required this.availableMaxPrice,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.sortBy,
    required this.sortOrder,
    required this.hasPriceRange,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _catId;
  late int _minPrice;
  late int _maxPrice;
  late String _sortKey;
  String? _priceError;

  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _catId = widget.selectedCategoryId;
    _minPrice = widget.selectedMinPrice;
    _maxPrice = widget.selectedMaxPrice;
    _sortKey = '${widget.sortBy}_${widget.sortOrder}';
    _minCtrl = TextEditingController(text: _minPrice.toString());
    _maxCtrl = TextEditingController(text: _maxPrice.toString());
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    if (widget.hasPriceRange) {
      final min = int.tryParse(_minCtrl.text.trim());
      final max = int.tryParse(_maxCtrl.text.trim());
      if (min == null || max == null) {
        setState(() => _priceError = 'Enter valid numbers.');
        return;
      }
      if (min > max) {
        setState(() => _priceError = 'Min must be ≤ Max.');
        return;
      }
      _minPrice = min;
      _maxPrice = max;
    }
    final parts = _sortKey.split('_');
    Navigator.pop(
      context,
      _FilterSelection(
        categoryId: _catId,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: parts.first,
        sortOrder: parts.last,
      ),
    );
  }

  void _clear() {
    setState(() {
      _catId = null;
      _minPrice = widget.availableMinPrice;
      _maxPrice = widget.availableMaxPrice;
      _minCtrl.text = _minPrice.toString();
      _maxCtrl.text = _maxPrice.toString();
      _sortKey = 'createdAt_desc';
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
            color: selected ? AppColors.primary : AppColors.border,
          ),
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
            // ── Category ──────────────────────────────────────────────
            const Text('Category',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.subText)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                    'All', _catId == null, () => setState(() => _catId = null)),
                ...widget.categories.map((c) => _chip(c.name, _catId == c.id,
                    () => setState(() => _catId = c.id))),
              ],
            ),

            // ── Sort ──────────────────────────────────────────────────
            const SizedBox(height: 20),
            const Text('Sort by',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.subText)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in [
                  {'key': 'createdAt_desc', 'label': 'Newest'},
                  {'key': 'price_asc', 'label': 'Price ↑'},
                  {'key': 'price_desc', 'label': 'Price ↓'},
                  {'key': 'name_asc', 'label': 'A → Z'},
                ])
                  _chip(item['label']!, _sortKey == item['key'],
                      () => setState(() => _sortKey = item['key']!)),
              ],
            ),

            // ── Price ─────────────────────────────────────────────────
            if (widget.hasPriceRange) ...[
              const SizedBox(height: 20),
              const Text('Price range',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.subText)),
              const SizedBox(height: 10),
              if (_priceError != null) ...[
                Text(
                  _priceError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _priceError = null),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _priceError = null),
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
            ],

            const SizedBox(height: 28),
            // ── Buttons ───────────────────────────────────────────────
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
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => Container(
              height: 124,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(20),
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
            const Text('Could not load items',
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
