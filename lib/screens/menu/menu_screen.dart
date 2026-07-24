import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../food/food_detail_screen.dart';
import 'always_available_screen.dart';
import 'today_menu_screen.dart';
import 'weekly_menu_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Semantic palette — must stay in sync with the badges used in the cart:
//   • Orange  → primary actions (Add button, prices, "Today" tab)
//   • Blue    → "Today's Menu" (Menu Food) label & badges
//   • Green   → "Always Available" label & badges
// ─────────────────────────────────────────────────────────────────────────────
class _MenuPalette {
  static const orange = Color(0xFFFB7A2E);
  static const orangeDark = Color(0xFFEA580C);
  static const blue = Color(0xFF2F6FE4);
  static const blueSoft = Color(0xFFE8F0FE);
  static const green = Color(0xFF1FA463);
  static const greenSoft = Color(0xFFE4F6ED);
}

class MenuScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  List<Food> _scheduledFoods = [];
  List<Food> _alwaysAvailableFoods = [];
  late String? _selectedCategoryName;
  bool _isLoadingScheduled = true;
  bool _isLoadingAlways = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryName = widget.preselectedCategoryName;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadScheduledFoods(),
      _loadAlwaysAvailableFoods(),
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

  void _openDetail(Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  bool get _hasCategoryFilter =>
      _selectedCategoryName != null && _selectedCategoryName!.isNotEmpty;

  bool _matchesSelectedCategory(Food food) {
    if (!_hasCategoryFilter) return true;
    return food.category.toLowerCase() == _selectedCategoryName!.toLowerCase();
  }

  List<Food> get _visibleScheduledFoods {
    final foods = _scheduledFoods.where(_matchesSelectedCategory).toList();
    return _hasCategoryFilter ? foods : foods.take(6).toList();
  }

  List<Food> get _visibleAlwaysAvailableFoods {
    final foods =
        _alwaysAvailableFoods.where(_matchesSelectedCategory).toList();
    return _hasCategoryFilter ? foods : foods.take(6).toList();
  }

  void _clearCategoryFilter() {
    setState(() => _selectedCategoryName = null);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            if (_hasCategoryFilter)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      InputChip(
                        label: Text(
                          _selectedCategoryName!,
                          style: const TextStyle(
                            color: _MenuPalette.orangeDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.primarySoft,
                        selectedColor: AppColors.primarySoft,
                        selected: true,
                        onDeleted: _clearCategoryFilter,
                        deleteIconColor: _MenuPalette.orangeDark,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(
                              color: _MenuPalette.orange, width: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Scheduled (Today Menu) — BLUE section ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _SectionHeader(
                  title: "Thực đơn hôm nay",
                  subtitle: '${_scheduledFoods.length} món trong hôm nay',
                  accentColor: _MenuPalette.blue,
                  dotColor: _MenuPalette.blue,
                  onSeeAll: () => Navigator.pushNamed(
                    context,
                    TodayMenuScreen.routeName,
                    arguments: {'categoryName': _selectedCategoryName},
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildScheduledList()),

            // ─── Always Available — GREEN section ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: _SectionHeader(
                  title: 'Luôn có sẵn',
                  subtitle: '${_alwaysAvailableFoods.length} món mỗi ngày',
                  accentColor: _MenuPalette.green,
                  dotColor: _MenuPalette.green,
                  onSeeAll: () => Navigator.pushNamed(
                    context,
                    AlwaysAvailableScreen.routeName,
                    arguments: {
                      'categoryId': widget.preselectedCategoryId,
                      'categoryName': _selectedCategoryName,
                    },
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildAlwaysAvailableGrid()),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Header
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu 🍽️',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Khám phá thực đơn hôm nay và các món luôn có sẵn',
            style: TextStyle(color: AppColors.subText, fontSize: 14, fontWeight: FontWeight.w400),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _NavTile(
              label: "Hôm nay",
              subtitle: "Món ăn hôm nay",
              icon: Icons.wb_sunny_rounded,
              gradient: const LinearGradient(
                colors: [_MenuPalette.orangeDark, _MenuPalette.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => Navigator.pushNamed(
                context,
                TodayMenuScreen.routeName,
                arguments: {'categoryName': _selectedCategoryName},
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _NavTile(
                  label: 'Theo tuần',
                  subtitle: 'Thực đơn tuần',
                  icon: Icons.calendar_month_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF334155), Color(0xFF64748B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  compact: true,
                  onTap: () => Navigator.pushNamed(
                    context,
                    WeeklyMenuScreen.routeName,
                    arguments: {'categoryName': _selectedCategoryName},
                  ),
                ),
                const SizedBox(height: 12),
                _NavTile(
                  label: 'Luôn có sẵn',
                  subtitle: 'Món ăn mọi lúc',
                  icon: Icons.store_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17835A), _MenuPalette.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  compact: true,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AlwaysAvailableScreen.routeName,
                    arguments: {
                      'categoryId': widget.preselectedCategoryId,
                      'categoryName': _selectedCategoryName,
                    },
                  ),
                ),
              ],
            ),
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
      return SizedBox(
        height: 205,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, __) => const _ShimmerCard(width: 176, height: 205),
        ),
      );
    }

    final foods = _visibleScheduledFoods;

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(
          icon: Icons.no_meals_rounded,
          title: 'Chưa có món nào hôm nay',
          subtitle: 'Quay lại sau để xem thực đơn hôm nay.',
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          final food = foods[index];
          return _ScheduledFoodCard(
            food: food,
            onTap: () => _openDetail(food),
            onAdd: food.canAddToCart ? () => _add(food) : null,
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Always Available Grid – 2 column (green badge = Always Available)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAlwaysAvailableGrid() {
    if (_isLoadingAlways) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (_, __) => const _ShimmerCard(width: double.infinity, height: double.infinity),
        ),
      );
    }

    final foods = _visibleAlwaysAvailableFoods;

    if (foods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(
          icon: Icons.fastfood_rounded,
          title: 'Chưa có món nào',
          subtitle: 'Các món luôn có sẵn sẽ hiển thị tại đây.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: foods.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.76,
        ),
        itemBuilder: (_, index) {
          final food = foods[index];
          return _AlwaysAvailableCard(
            food: food,
            onTap: () => _openDetail(food),
            onAdd: food.canAddToCart ? () => _add(food) : null,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Tile
// ─────────────────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onTap;
  final bool compact;

  const _NavTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: compact ? 76 : 168,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: compact
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white70, size: 14),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
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
// Section Header — carries a small colored dot + accent-colored title so the
// section instantly reads as "blue = Today's Menu" / "green = Always Available"
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color dotColor;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.dotColor,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'Xem tất cả →',
              style: TextStyle(
                color: _MenuPalette.orangeDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled Food Card – horizontal (Menu Food → blue badge, matches cart)
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduledFoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const _ScheduledFoodCard({required this.food, this.onTap, this.onAdd});

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 176,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 110,
                    width: 176,
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  // Sold-out overlay
                  if (isSoldOut)
                    Container(
                      height: 110,
                      width: 176,
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HẾT HÀNG',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  // Meal type badge — blue, matches "Menu Food" badge in cart
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _MenuPalette.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        food.mealType ?? 'Menu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.vnd(food.price),
                          style: const TextStyle(
                            color: _MenuPalette.orangeDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: onAdd,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isSoldOut
                                  ? AppColors.border
                                  : _MenuPalette.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSoldOut ? Icons.remove : Icons.add_rounded,
                              color: Colors.white,
                              size: 16,
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

  Widget _placeholder() {
    return Container(
      height: 110,
      width: 176,
      color: _MenuPalette.blueSoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu_rounded,
        color: _MenuPalette.blue,
        size: 36,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Always Available Card – grid (Always Available → green badge, matches cart)
// ─────────────────────────────────────────────────────────────────────────────
class _AlwaysAvailableCard extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const _AlwaysAvailableCard({required this.food, this.onTap, this.onAdd});

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  if (isSoldOut)
                    Container(
                      height: 100,
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: const Text(
                        'HẾT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  if (food.category.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _MenuPalette.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          food.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyFormatter.vnd(food.price),
                            style: const TextStyle(
                              color: _MenuPalette.orangeDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onAdd,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSoldOut
                                  ? AppColors.border
                                  : _MenuPalette.orange,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              isSoldOut ? Icons.remove : Icons.add_rounded,
                              color: Colors.white,
                              size: 15,
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

  Widget _placeholder() {
    return Container(
      height: 100,
      color: _MenuPalette.greenSoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.fastfood_rounded,
        color: _MenuPalette.green,
        size: 32,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton card
// ─────────────────────────────────────────────────────────────────────────────
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