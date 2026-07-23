import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../states/cart_provider.dart';
import '../../services/auth_storage.dart';
import '../../services/food_service.dart';
import '../../widgets/app_button.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/food-detail';

  final Food food;

  const FoodDetailScreen({super.key, required this.food});

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  final FoodService _foodService = FoodService(ApiClient());

  late Food _food;
  int quantity = 1;
  bool _isLoadingDetail = false;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _food = widget.food;
    _loadFoodDetail();
  }

  Future<void> _loadFoodDetail() async {
    if (_food.id.isEmpty) return;
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      final detail = await _foodService.getFoodById(_food.id);
      final mergedDetail = await _mergeDetail(detail);
      if (!mounted) return;
      setState(() => _food = mergedDetail);
    } catch (e) {
      if (mounted) setState(() => _detailError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  Future<Food> _mergeDetail(Food detail) async {
    if (_food.menuScheduleItemId != null) {
      return _mergeMenuContext(detail, _food);
    }

    if (!detail.isMenuFood) return detail;

    try {
      final todayFoods = await _foodService.getTodayMenuFoods();
      Food? scheduledFood;
      for (final food in todayFoods) {
        if (food.id == detail.id && food.menuScheduleItemId != null) {
          scheduledFood = food;
          break;
        }
      }
      if (scheduledFood == null) {
        return detail.copyWith(
          status: FoodStatus.comingSoon,
          remainingServings: 0,
          mealType: 'Menu',
          menuDateLabel: 'Today',
        );
      }
      return _mergeMenuContext(detail, scheduledFood);
    } catch (_) {
      return detail;
    }
  }

  Food _mergeMenuContext(Food detail, Food menuContext) {
    final remainingServings = menuContext.remainingServings;
    final status =
        (remainingServings != null && remainingServings <= 0) ? FoodStatus.soldOut : menuContext.status;

    return detail.copyWith(
      kind: menuContext.kind,
      status: status,
      menuScheduleItemId: menuContext.menuScheduleItemId,
      remainingServings: remainingServings,
      mealType: menuContext.mealType,
      menuDateLabel: menuContext.menuDateLabel,
    );
  }

  String? _resolvedImageUrl(Food food) {
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

  int? get _maxQuantity {
    if (_food.isMenuFood) return _food.remainingServings;
    return _food.stockQuantity;
  }

  Future<void> _addToCart({bool openCart = false}) async {
    if (!_food.canAddToCart) return;

    HapticFeedback.mediumImpact();

    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }

    try {
      await ref.read(cartProvider.notifier).addItem(_food, quantity: quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_food.name} added to cart'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      if (openCart) {
        Navigator.pushNamed(context, CartScreen.routeName);
      }
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

  void _increaseQuantity() {
    final maxQuantity = _maxQuantity;
    if (maxQuantity != null && quantity >= maxQuantity) return;
    HapticFeedback.selectionClick();
    setState(() => quantity++);
  }

  void _decreaseQuantity() {
    if (quantity <= 1) return;
    HapticFeedback.selectionClick();
    setState(() => quantity--);
  }

  @override
  Widget build(BuildContext context) {
    final food = _food;
    final heroHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Hero Image (42% screen height) ─────────────────────────────────
          _buildHero(food, heroHeight),

          // ─── Action Buttons (Back & Refresh) ──────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _CircleActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _CircleActionButton(
                    icon: _isLoadingDetail ? Icons.sync : Icons.refresh_rounded,
                    isLoading: _isLoadingDetail,
                    onPressed: _isLoadingDetail ? null : _loadFoodDetail,
                  ),
                ],
              ),
            ),
          ),

          // ─── Draggable Scrollable Content Sheet ────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.62,
            minChildSize: 0.60,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // ─── Drag Handle ─────────────────────────────────────────
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    if (_detailError != null) ...[
                      _DetailErrorBanner(
                        message: _detailError!,
                        onRetry: _loadFoodDetail,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Food Title & Type Label ─────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            food.typeLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ─── Price ───────────────────────────────────────────────
                    Text(
                      CurrencyFormatter.vnd(food.price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ─── Info Badges (Category, Stock/Servings, Status) ─────
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Category Chip
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: food.isMenuFood
                              ? '${food.menuDateLabel ?? 'Today'} · ${food.mealType ?? 'Menu'}'
                              : (food.category.isEmpty
                                  ? 'Uncategorized'
                                  : food.category),
                          backgroundColor: const Color(0xFFFFF3ED),
                          textColor: const Color(0xFFFF6B00),
                        ),

                        // Stock / Servings Chip
                        _InfoChip(
                          icon: food.canAddToCart
                              ? Icons.inventory_2_outlined
                              : Icons.do_not_disturb_on_outlined,
                          label: food.isMenuFood
                              ? (food.remainingServings == null
                                  ? 'Unlimited servings left'
                                  : '${food.remainingServings} servings left')
                              : food.statusLabel,
                          backgroundColor: food.canAddToCart
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          textColor: food.canAddToCart
                              ? AppColors.success
                              : AppColors.error,
                        ),

                        // Rating Chip
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: food.rating > 0
                              ? food.rating.toStringAsFixed(1)
                              : '4.8',
                          backgroundColor: const Color(0xFFFFF8E1),
                          textColor: const Color(0xFFFFB300),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      food.description.isEmpty
                          ? 'No description available for this item.'
                          : food.description,
                      style: const TextStyle(
                        color: AppColors.subText,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─── Quantity Selector ────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed:
                                    quantity > 1 ? _decreaseQuantity : null,
                                icon: const Icon(Icons.remove_rounded),
                                color: quantity > 1
                                    ? AppColors.text
                                    : AppColors.subText.withValues(alpha: 0.4),
                                iconSize: 20,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: food.canAddToCart
                                      ? AppColors.primary
                                      : AppColors.subText.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: food.canAddToCart
                                      ? _increaseQuantity
                                      : null,
                                  icon: const Icon(Icons.add_rounded,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ─── Bottom Actions (Add Cart Icon + Order Now) ───────────
                    Row(
                      children: [
                        // Cart Icon Button
                        InkWell(
                          onTap: food.canAddToCart ? () => _addToCart() : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: food.canAddToCart
                                  ? AppColors.primarySoft
                                  : AppColors.muted,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: food.canAddToCart
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: food.canAddToCart
                                  ? AppColors.primary
                                  : AppColors.subText,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Main Order Now Button
                        Expanded(
                          child: AppButton(
                            label: 'Order Now →',
                            onPressed: food.canAddToCart
                                ? () => _addToCart(openCart: true)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHero(Food food, double height) {
    final imageUrl = _resolvedImageUrl(food);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl == null
                ? Container(
                    color: AppColors.primarySoft,
                    child: const Center(
                      child: Icon(
                        Icons.fastfood_rounded,
                        size: 72,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: height,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primarySoft,
                      child: const Center(
                        child: Icon(
                          Icons.fastfood_rounded,
                          size: 72,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
          ),
          // Gradient Scrim overlay at the top for button readability
          Positioned(
            top: 0, left: 0, right: 0,
            height: 100,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle Action Button with glassmorphism / shadow style
// ─────────────────────────────────────────────────────────────────────────────
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _CircleActionButton({
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(icon, color: AppColors.text, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled Info Chip Component
// ─────────────────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Banner
// ─────────────────────────────────────────────────────────────────────────────
class _DetailErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.subText, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
