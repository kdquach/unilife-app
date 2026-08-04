import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_rating.dart';
import '../../models/food.dart';
import '../../services/api_client.dart';
import '../../states/cart_provider.dart';
import '../../services/auth_storage.dart';
import '../../services/food_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/app_button.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';
import '../rating/rating_list_screen.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/food-detail';

  final Food food;

  const FoodDetailScreen({super.key, required this.food});

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  final FoodService _foodService = FoodService(ApiClient());
  final RatingService _ratingService = RatingService(ApiClient());

  late Food _food;
  List<CustomerRating> _ratings = [];
  int _ratingsTotal = 0;
  int quantity = 1;
  bool _isLoadingDetail = false;
  bool _isLoadingRatings = false;
  String? _detailError;
  String? _ratingsError;

  @override
  void initState() {
    super.initState();
    _food = widget.food;
    _loadFoodDetail();
    _loadFoodRatings();
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

  Future<void> _loadFoodRatings() async {
    if (_food.id.isEmpty) return;
    setState(() {
      _isLoadingRatings = true;
      _ratingsError = null;
    });

    try {
      final token = await AuthStorage.getToken();
      final result = await _loadFoodRatingsPage(token: token, limit: 4);
      if (!mounted) return;
      setState(() {
        _ratings = result.items;
        _ratingsTotal = result.total;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        setState(() {
          _ratings = [];
          _ratingsTotal = 0;
          _ratingsError = null;
        });
      } else {
        setState(() => _ratingsError = _cleanReviewError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _ratingsError = _cleanReviewError(e));
    } finally {
      if (mounted) setState(() => _isLoadingRatings = false);
    }
  }

  Future<RatingPage> _loadFoodRatingsPage({
    required String? token,
    required int limit,
    int page = 1,
  }) async {
    return _ratingService.getRatingsPage(
      token: token,
      foodId: _food.id,
      ratingType: 'FOOD',
      page: page,
      limit: limit,
    );
  }

  void _openAllReviews() {
    Navigator.pushNamed(
      context,
      RatingListScreen.routeName,
      arguments: RatingListArgs(
        foodId: _food.id,
        title: 'Comments',
        foodName: _food.name,
      ),
    );
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
    final status = (remainingServings != null && remainingServings <= 0)
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

  String _availabilityLabel(Food food) {
    if (food.isMenuFood) {
      if (food.remainingServings == null) return 'Available';
      return food.remainingServings! > 0
          ? '${food.remainingServings} servings left'
          : 'Sold out';
    }

    if (food.stockQuantity != null) {
      return food.stockQuantity! > 0
          ? '${food.stockQuantity} items left'
          : 'Out of stock';
    }

    return food.statusLabel;
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
                          label: _availabilityLabel(food),
                          backgroundColor: food.canAddToCart
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          textColor: food.canAddToCart
                              ? AppColors.success
                              : AppColors.error,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
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
                                      : AppColors.subText
                                          .withValues(alpha: 0.3),
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

                    const SizedBox(height: 28),

                    _FoodReviewsSection(
                      ratings: _ratings,
                      totalCount: _ratingsTotal,
                      isLoading: _isLoadingRatings,
                      errorMessage: _ratingsError,
                      onRetry: _loadFoodRatings,
                      onSeeAll: _ratingsTotal > 3 || _ratings.length > 3
                          ? _openAllReviews
                          : null,
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
            top: 0,
            left: 0,
            right: 0,
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
class _FoodReviewsSection extends StatelessWidget {
  final List<CustomerRating> ratings;
  final int totalCount;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback? onSeeAll;

  const _FoodReviewsSection({
    required this.ratings,
    required this.totalCount,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onSeeAll,
  });

  int get _effectiveTotal => totalCount > 0 ? totalCount : ratings.length;

  double? get _exactAverage {
    if (ratings.isEmpty || _effectiveTotal > ratings.length) return null;
    final total = ratings.fold<int>(0, (sum, rating) => sum + rating.stars);
    return total / ratings.length;
  }

  @override
  Widget build(BuildContext context) {
    final total = _effectiveTotal;
    final average = _exactAverage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: AppColors.primary,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See All'),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (average != null) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  average.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '.',
                  style: TextStyle(color: AppColors.subText),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$total ${total == 1 ? 'comment' : 'comments'}',
                style: const TextStyle(
                  color: AppColors.subText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (isLoading)
          const Column(
            children: [
              _ReviewSkeletonCard(),
              SizedBox(height: 10),
              _ReviewSkeletonCard(),
            ],
          )
        else if (errorMessage != null)
          _ReviewErrorState(onRetry: onRetry)
        else if (ratings.isEmpty)
          const _ReviewEmptyState()
        else
          ...ratings.take(3).map(
                (rating) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FoodReviewCard(rating: rating),
                ),
              ),
      ],
    );
  }
}

class _FoodReviewCard extends StatelessWidget {
  final CustomerRating rating;

  const _FoodReviewCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final createdAt = rating.createdAt;
    final customerName = rating.user?.fullName.trim().isNotEmpty == true
        ? rating.user!.fullName.trim()
        : 'Customer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewAvatar(
                name: customerName,
                avatarUrl: rating.user?.avatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('dd MMM yyyy').format(createdAt.toLocal()),
                        style: const TextStyle(
                          color: AppColors.subText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ReviewStars(value: rating.stars),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rating.comment ?? 'No comment',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.subText,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          if (rating.staffReply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Staff reply: ${rating.staffReply}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ReviewAvatar({required this.name, this.avatarUrl});

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'C';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  String? _resolvedAvatarUrl() {
    final rawUrl = avatarUrl;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final apiRoot = Uri.parse(ApiClient.baseUrl);
    final origin = '${apiRoot.scheme}://${apiRoot.authority}';
    final normalizedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$origin$normalizedPath';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolvedAvatarUrl();

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
      child: imageUrl == null
          ? Text(
              _initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            )
          : null,
    );
  }
}

class _ReviewStars extends StatelessWidget {
  final int value;

  const _ReviewStars({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < value ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.warning,
          size: 15,
        ),
      ),
    );
  }
}

class _ReviewSkeletonCard extends StatelessWidget {
  const _ReviewSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewEmptyState extends StatelessWidget {
  const _ReviewEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No comments yet',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Be the first customer to comment after completing an order.',
            style: TextStyle(
              color: AppColors.subText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ReviewErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Unable to load comments',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

String _cleanReviewError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}

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
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
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
