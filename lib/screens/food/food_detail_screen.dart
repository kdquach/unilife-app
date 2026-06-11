import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../services/app_state.dart';
import '../../services/auth_storage.dart';
import '../../services/food_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_badge.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';

class FoodDetailScreen extends StatefulWidget {
  static const String routeName = '/food-detail';

  final Food food;

  const FoodDetailScreen({super.key, required this.food});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
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
    final remainingServings = menuContext.remainingServings ?? 0;
    final status = remainingServings <= 0
        ? FoodStatus.soldOut
        : menuContext.status;

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
    AppState.instance.addToCart(_food, quantity: quantity);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${_food.name} added to cart')));
    if (openCart) {
      final token = await AuthStorage.getToken();
      if (!mounted) return;
      if (token == null) {
        Navigator.pushNamed(context, LoginScreen.routeName);
        return;
      }
      Navigator.pushNamed(context, CartScreen.routeName);
    }
  }

  void _increaseQuantity() {
    final maxQuantity = _maxQuantity;
    if (maxQuantity != null && quantity >= maxQuantity) return;
    setState(() => quantity++);
  }

  void _decreaseQuantity() {
    if (quantity <= 1) return;
    setState(() => quantity--);
  }

  @override
  Widget build(BuildContext context) {
    final food = _food;
    return Scaffold(
      body: Stack(
        children: [
          _buildHero(food),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: _isLoadingDetail ? null : _loadFoodDetail,
                    icon: _isLoadingDetail
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.66,
            minChildSize: 0.66,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (_detailError != null) ...[
                      _DetailErrorBanner(
                        message: _detailError!,
                        onRetry: _loadFoodDetail,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        StatusBadge(label: food.typeLabel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.vnd(food.price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _InfoRow(
                      label: food.isMenuFood ? 'Menu session' : 'Category',
                      value: food.isMenuFood
                          ? '${food.menuDateLabel ?? 'Today'} ${food.mealType ?? 'Menu'}'
                          : (food.category.isEmpty
                              ? 'Uncategorized'
                              : food.category),
                    ),
                    _InfoRow(
                      label: food.isMenuFood ? 'Remaining' : 'Stock status',
                      value: food.isMenuFood
                          ? '${food.remainingServings ?? 0} servings'
                          : food.statusLabel,
                      valueColor: food.canAddToCart
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    _InfoRow(label: 'Status', value: food.statusLabel),
                    _InfoRow(
                      label: 'Rating',
                      value: food.rating.toStringAsFixed(1),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      food.description.isEmpty
                          ? 'No description available.'
                          : food.description,
                      style: const TextStyle(
                        color: AppColors.subText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed:
                                    quantity > 1 ? _decreaseQuantity : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Text(
                                '$quantity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              IconButton(
                                onPressed: food.canAddToCart
                                    ? _increaseQuantity
                                    : null,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Add Cart',
                            secondary: true,
                            onPressed:
                                food.canAddToCart ? () => _addToCart() : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'Order Now',
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

  Widget _buildHero(Food food) {
    final imageUrl = _resolvedImageUrl(food);
    final backgroundColor =
        food.isMenuFood ? AppColors.primarySoft : AppColors.muted;

    return Container(
      height: 310,
      color: backgroundColor,
      alignment: Alignment.center,
      child: imageUrl == null
          ? _HeroLabel(food: food)
          : Image.network(
              imageUrl,
              width: double.infinity,
              height: 310,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _HeroLabel(food: food),
            ),
    );
  }
}

class _HeroLabel extends StatelessWidget {
  final Food food;

  const _HeroLabel({required this.food});

  @override
  Widget build(BuildContext context) {
    return Text(
      food.isMenuFood
          ? 'MEAL'
          : (food.category.isEmpty ? 'FOOD' : food.category.toUpperCase()),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 44,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

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
              style: const TextStyle(color: AppColors.subText),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.subText),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
