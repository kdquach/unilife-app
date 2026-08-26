import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../services/api_client.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../../widgets/food_image_placeholder.dart';
import '../food/food_detail_screen.dart';
import '../menu/always_available_screen.dart';
import '../menu/today_menu_screen.dart';
import 'main_shell.dart';

const Color _homeHeaderColor = Color(0xFFF04422);
const Color _homeBackground = Color(0xFFF7F7F7);
const Color _homeSurface = Color(0xFFFFFFFF);
const Color _homeText = Color(0xFF181818);
const Color _homeSubText = Color(0xFF737373);
const Color _homeBorder = Color(0xFFE7E7E7);

String? _resolveHomeFoodImageUrl(Food food) {
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

class HomeScreen extends ConsumerStatefulWidget {
  final int unreadNotificationCount;
  final VoidCallback? onNotificationTap;

  const HomeScreen({
    super.key,
    this.unreadNotificationCount = 0,
    this.onNotificationTap,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final FoodService _foodService = FoodService(ApiClient());
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _categoriesKey = GlobalKey();

  List<Food> _menuFoods = [];
  List<Food> _regularFoods = [];
  List<Food> _searchResults = [];
  List<FoodCategory> _searchCategories = [];
  Timer? _searchDebounce;
  Timer? _pollingTimer;
  String _searchQuery = '';
  String? _searchError;
  String? _selectedSearchCategoryId;
  int _availableSearchMinPrice = 0;
  int _availableSearchMaxPrice = 0;
  int _selectedSearchMinPrice = 0;
  int _selectedSearchMaxPrice = 0;
  String _searchSortBy = 'createdAt';
  String _searchSortOrder = 'desc';
  int _searchRequestId = 0;
  bool _isLoading = true;
  bool _isLoadingSearchFilters = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadFoods();
    _loadSearchFilterOptions();
    _startPolling();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pollingTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadFoods(quiet: true);
      }
    });
  }

  Future<void> _loadFoods({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _foodService.getTodayMenuFoods(),
        _foodService.getAlwaysAvailableFoods(),
      ]);

      if (!mounted) return;
      setState(() {
        // Take a bit more than before so the home screen has more content
        // to browse, similar to a ShopeeFood-style feed.
        _menuFoods = results[0].take(6).toList();
        _regularFoods = results[1].take(4).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSearchFilterOptions() async {
    if (mounted) setState(() => _isLoadingSearchFilters = true);
    try {
      final options = await _foodService.getSearchFilterOptions();
      final categories = options.categories.isNotEmpty
          ? options.categories
          : await _foodService.getFoodCategories();
      if (!mounted) return;
      setState(() {
        _searchCategories = categories;
        _availableSearchMinPrice = options.minPrice;
        _availableSearchMaxPrice = options.maxPrice;
        _selectedSearchMinPrice = options.minPrice;
        _selectedSearchMaxPrice = options.maxPrice;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchCategories = [];
        _availableSearchMinPrice = 0;
        _availableSearchMaxPrice = 0;
        _selectedSearchMinPrice = 0;
        _selectedSearchMaxPrice = 0;
      });
    } finally {
      if (mounted) setState(() => _isLoadingSearchFilters = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      _searchRequestId++;
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _searchError = null;
      _isSearching = true;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchFoods(query),
    );
  }

  Future<void> _searchFoods(String query) async {
    final requestId = ++_searchRequestId;
    try {
      final foods = await _foodService.searchFoods(
        keyword: query,
        categoryId: _selectedSearchCategoryId,
        minPrice: _searchMinPriceParam,
        maxPrice: _searchMaxPriceParam,
        sortBy: _searchSortBy,
        sortOrder: _searchSortOrder,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = foods;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = [];
        _searchError = e.toString();
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  bool get _hasSearchPriceRange =>
      _availableSearchMaxPrice > _availableSearchMinPrice &&
      _availableSearchMaxPrice > 0;

  bool get _hasSearchPriceFilter =>
      _hasSearchPriceRange &&
      (_selectedSearchMinPrice != _availableSearchMinPrice ||
          _selectedSearchMaxPrice != _availableSearchMaxPrice);

  bool get _hasActiveSearchFilters =>
      _selectedSearchCategoryId != null ||
      _hasSearchPriceFilter ||
      _searchSortBy != 'createdAt' ||
      _searchSortOrder != 'desc';

  int? get _searchMinPriceParam =>
      _hasSearchPriceFilter ? _selectedSearchMinPrice : null;

  int? get _searchMaxPriceParam =>
      _hasSearchPriceFilter ? _selectedSearchMaxPrice : null;

  void _refreshSearchIfNeeded() {
    if (_searchQuery.isEmpty) return;
    setState(() => _isSearching = true);
    _searchFoods(_searchQuery);
  }

  Future<void> _openSearchFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return _SearchFilterSheet(
          categories: _searchCategories,
          isLoadingCategories: _isLoadingSearchFilters,
          selectedCategoryId: _selectedSearchCategoryId,
          availableMinPrice: _availableSearchMinPrice,
          availableMaxPrice: _availableSearchMaxPrice,
          selectedMinPrice: _selectedSearchMinPrice,
          selectedMaxPrice: _selectedSearchMaxPrice,
          sortBy: _searchSortBy,
          sortOrder: _searchSortOrder,
          onApply: (selection) {
            if (!mounted) return;
            setState(() {
              _selectedSearchCategoryId = selection.categoryId;
              _selectedSearchMinPrice = selection.minPrice;
              _selectedSearchMaxPrice = selection.maxPrice;
              _searchSortBy = selection.sortBy;
              _searchSortOrder = selection.sortOrder;
            });
            _refreshSearchIfNeeded();
          },
        );
      },
    );
  }

  void _openDetail(BuildContext context, Food food) =>
      Navigator.pushNamed(context, FoodDetailScreen.routeName, arguments: food);

  void _openMenuCategory(FoodCategory category) {
    Navigator.pushNamed(
      context,
      MainShell.routeName,
      arguments: {
        'tabIndex': 1,
        'categoryId': category.id,
        'categoryName': category.name,
      },
    );
  }

  void _openMenuTab(String tab) {
    Navigator.pushNamed(
      context,
      MainShell.routeName,
      arguments: {
        'tabIndex': 1,
        'menuTab': tab,
      },
    );
  }

  void _scrollToCategories() {
    final ctx = _categoriesKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Food food) async {
    try {
      await ref.read(cartProvider.notifier).addItem(food);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food.name} added to cart')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _homeBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final regularFoods = _regularFoods;

    return Scaffold(
      backgroundColor: _homeBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _TopBar(
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              query: _searchQuery,
              hasActiveFilters: _hasActiveSearchFilters,
              onSearchChanged: _onSearchChanged,
              onClear: _clearSearch,
              onFilterTap: _openSearchFilterSheet,
              unreadNotificationCount: widget.unreadNotificationCount,
              onNotificationTap: widget.onNotificationTap,
            ),
            if (_searchQuery.isNotEmpty)
              _SearchResults(
                isSearching: _isSearching,
                error: _searchError,
                query: _searchQuery,
                foods: _searchResults,
                onFoodTap: (food) => _openDetail(context, food),
              )
            else ...[
              const SizedBox(height: 20),
              const _PromoCarousel(),
              _SectionHeader(
                key: _categoriesKey,
                title: 'Categories',
                action: 'See all',
                onAction: _scrollToCategories,
              ),
              _CategoryRow(
                categories: _searchCategories,
                onCategoryTap: _openMenuCategory,
              ),
              _SectionHeader(
                title: 'Today\'s Menu',
                action: 'See more',
                onAction: () => _openMenuTab('today'),
              ),
              _HomeFoodCardList(
                foods: _menuFoods,
                emptyState: const _TodayMenuEmptyState(),
                onFoodTap: (food) => _openDetail(context, food),
                onAdd: (food) => _add(context, ref, food),
              ),
              _SectionHeader(
                title: 'Always Available',
                action: 'See more',
                onAction: () => _openMenuTab('always'),
              ),
              _HomeFoodCardList(
                foods: regularFoods,
                emptyState: const _CompactFoodEmptyState(
                  icon: Icons.storefront_rounded,
                  title: 'No foods are currently available',
                  message: 'Please check again later.',
                ),
                showPopularLabel: true,
                onFoodTap: (food) => _openDetail(context, food),
                onAdd: (food) => _add(context, ref, food),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact search header. Greeting/user identity stays hidden on Home.
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String query;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;
  final int unreadNotificationCount;
  final VoidCallback? onNotificationTap;

  const _TopBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.query,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onClear,
    required this.onFilterTap,
    this.unreadNotificationCount = 0,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: _homeHeaderColor,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: _homeSurface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: _homeHeaderColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      cursorColor: _homeHeaderColor,
                      decoration: const InputDecoration(
                        hintText: 'Search food, drinks, snacks...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  if (query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: onClear,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Filter',
                    onPressed: onFilterTap,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: hasActiveFilters
                              ? _homeHeaderColor
                              : _homeSubText,
                        ),
                        if (hasActiveFilters)
                          const Positioned(
                            top: -4,
                            right: -4,
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: _homeHeaderColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _NotificationBell(
            unreadCount: unreadNotificationCount,
            onTap: onNotificationTap,
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onTap;

  const _NotificationBell({required this.unreadCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 21,
              color: Colors.white,
            ),
            if (hasUnread)
              Positioned(
                top: -7,
                right: -8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  height: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: _homeHeaderColor,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promo carousel — swipeable banner with a dot indicator, ShopeeFood-style.
// Slides link to the real Today Menu / Always Available screens.
// ---------------------------------------------------------------------------
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _pageController = PageController();
  Timer? _autoPlayTimer;
  int _page = 0;

  late final List<_PromoSlide> _slides = [
    _PromoSlide(
      eyebrow: "TODAY'S DEAL",
      title: 'Only at\nCanteen',
      cta: 'Order now!',
      icon: Icons.fastfood_rounded,
      imagePath: AppAssets.banhmi,
      onTap: () => Navigator.pushNamed(context, TodayMenuScreen.routeName),
    ),
    _PromoSlide(
      eyebrow: 'TODAY\'S MENU',
      title: 'New dishes\nevery day',
      cta: 'View menu',
      icon: Icons.restaurant_menu_rounded,
      imagePath: AppAssets.hutieu,
      onTap: () => Navigator.pushNamed(context, TodayMenuScreen.routeName),
    ),
    _PromoSlide(
      eyebrow: 'ALWAYS AVAILABLE',
      title: 'Ready to\nserve',
      cta: 'Explore',
      icon: Icons.bolt_rounded,
      imagePath: AppAssets.goicuon,
      onTap: () =>
          Navigator.pushNamed(context, AlwaysAvailableScreen.routeName),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 118,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PromoBannerCard(slide: _slides[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoSlide {
  final String eyebrow;
  final String title;
  final String cta;
  final IconData icon;
  final VoidCallback onTap;
  final String? imagePath;

  const _PromoSlide({
    required this.eyebrow,
    required this.title,
    required this.cta,
    required this.icon,
    required this.onTap,
    this.imagePath,
  });
}

class _PromoBannerCard extends StatelessWidget {
  final _PromoSlide slide;

  const _PromoBannerCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final hasImage = slide.imagePath != null;

    return InkWell(
      onTap: slide.onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: Colors.white.withValues(alpha: 0.15),
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (hasImage)
              Positioned.fill(
                child: Image.asset(
                  slide.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              )
            else
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (hasImage)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              )
            else
              Positioned(
                right: 16,
                bottom: 12,
                child: Icon(
                  slide.icon,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    slide.eyebrow,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.cta,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFoodCardList extends StatelessWidget {
  final List<Food> foods;
  final Widget emptyState;
  final bool showPopularLabel;
  final ValueChanged<Food> onFoodTap;
  final ValueChanged<Food> onAdd;

  const _HomeFoodCardList({
    required this.foods,
    required this.emptyState,
    required this.onFoodTap,
    required this.onAdd,
    this.showPopularLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: emptyState,
      );
    }

    return SizedBox(
      height: 235,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final food = foods[i];
          return _HomeFoodCard(
            food: food,
            showPopularLabel: showPopularLabel,
            onTap: () => onFoodTap(food),
            onAdd: food.canAddToCart ? () => onAdd(food) : null,
          );
        },
      ),
    );
  }
}

class _HomeFoodCard extends StatelessWidget {
  final Food food;
  final bool showPopularLabel;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _HomeFoodCard({
    required this.food,
    required this.showPopularLabel,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = food.canAddToCart;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: _homeSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _homeBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeFoodImage(food: food),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPopularLabel) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Popular now',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _homeHeaderColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    SizedBox(
                      height: 24, // Fixed height for name section (2 lines max)
                      child: Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _homeText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.vnd(food.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _homeHeaderColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _FoodStatusBadge(food: food, canAdd: canAdd),
                        ),
                        const SizedBox(width: 8),
                        _AddFoodButton(onAdd: onAdd, enabled: canAdd),
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
}

class _HomeFoodImage extends StatelessWidget {
  final Food food;

  const _HomeFoodImage({required this.food});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveHomeFoodImageUrl(food);

    return SizedBox(
      height: 105,
      width: double.infinity,
      child: imageUrl == null
          ? const _FoodImageFallback()
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _FoodImageFallback(),
            ),
    );
  }
}

class _FoodImageFallback extends StatelessWidget {
  const _FoodImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu_rounded,
        color: Color(0xFF9CA3AF),
        size: 34,
      ),
    );
  }
}

class _FoodStatusBadge extends StatelessWidget {
  final Food food;
  final bool canAdd;

  const _FoodStatusBadge({required this.food, required this.canAdd});

  @override
  Widget build(BuildContext context) {
    final color = canAdd ? AppColors.success : const Color(0xFFDC2626);

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: canAdd ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.50)),
      ),
      alignment: Alignment.center,
      child: Text(
        food.statusLabel,
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

class _AddFoodButton extends StatelessWidget {
  final VoidCallback? onAdd;
  final bool enabled;

  const _AddFoodButton({required this.onAdd, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onAdd : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? _homeHeaderColor : AppColors.border,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          enabled ? Icons.add_rounded : Icons.remove_rounded,
          size: 18,
          color: enabled ? Colors.white : AppColors.subText,
        ),
      ),
    );
  }
}

class _TodayMenuEmptyState extends StatelessWidget {
  const _TodayMenuEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: _homeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _homeBorder),
      ),
      alignment: Alignment.centerLeft,
      child: const Text(
        'No menu scheduled today',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _homeText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _CompactFoodEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CompactFoodEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _homeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _homeBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: _homeHeaderColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _homeText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _homeSubText,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search results
// ---------------------------------------------------------------------------
class _SearchResults extends StatelessWidget {
  final bool isSearching;
  final String? error;
  final String query;
  final List<Food> foods;
  final ValueChanged<Food> onFoodTap;

  const _SearchResults({
    required this.isSearching,
    required this.error,
    required this.query,
    required this.foods,
    required this.onFoodTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not search foods: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    if (foods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 42),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 10),
            Text(
              'No foods found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.subText),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${foods.length} result${foods.length == 1 ? '' : 's'} for "$query"',
            style: const TextStyle(
              color: AppColors.subText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...foods.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SearchFoodTile(
                food: food,
                onTap: () => onFoodTap(food),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchFoodTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;

  const _SearchFoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryLabel =
        food.category.isEmpty ? food.typeLabel : food.category;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: AppColors.primary.withValues(alpha: 0.08),
      highlightColor: AppColors.primary.withValues(alpha: 0.04),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            FoodImagePlaceholder(food: food, size: 60, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.subText,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.vnd(food.price),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: AppColors.subText),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search filter sheet
// ---------------------------------------------------------------------------
class _SearchFilterSelection {
  final String? categoryId;
  final int minPrice;
  final int maxPrice;
  final String sortBy;
  final String sortOrder;

  const _SearchFilterSelection({
    required this.categoryId,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.sortOrder,
  });
}

class _SearchFilterSheet extends StatefulWidget {
  final List<FoodCategory> categories;
  final bool isLoadingCategories;
  final String? selectedCategoryId;
  final int availableMinPrice;
  final int availableMaxPrice;
  final int selectedMinPrice;
  final int selectedMaxPrice;
  final String sortBy;
  final String sortOrder;
  final ValueChanged<_SearchFilterSelection> onApply;

  const _SearchFilterSheet({
    required this.categories,
    required this.isLoadingCategories,
    required this.selectedCategoryId,
    required this.availableMinPrice,
    required this.availableMaxPrice,
    required this.selectedMinPrice,
    required this.selectedMaxPrice,
    required this.sortBy,
    required this.sortOrder,
    required this.onApply,
  });

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
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

  void _setPriceError(String message) {
    setState(() => _priceError = message);
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
        _setPriceError('Please enter both min and max price.');
        return;
      }

      if (minPrice == null || maxPrice == null) {
        _setPriceError('Price must be a valid number.');
        return;
      }

      if (minPrice > maxPrice) {
        _setPriceError('Min price must be less than or equal to max price.');
        return;
      }

      if (minPrice < widget.availableMinPrice ||
          maxPrice > widget.availableMaxPrice) {
        _setPriceError(
          'Price must be between ${CurrencyFormatter.vnd(widget.availableMinPrice)} and ${CurrencyFormatter.vnd(widget.availableMaxPrice)}.',
        );
        return;
      }
    }

    widget.onApply(
      _SearchFilterSelection(
        categoryId: _categoryId,
        minPrice: minPrice ?? widget.availableMinPrice,
        maxPrice: maxPrice ?? widget.availableMaxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      ),
    );
    Navigator.pop(context);
  }

  Widget _filterChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _homeHeaderColor : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
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
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter search',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (widget.isLoadingCategories)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                )
              else
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
              const Text('Price',
                  style: TextStyle(fontWeight: FontWeight.w900)),
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
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
                        onChanged: (_) => _clearPriceError(),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
              ] else
                const Text(
                  'No price range available',
                  style: TextStyle(color: AppColors.subText),
                ),
              const SizedBox(height: 20),
              const Text('Sort by',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: sortValue,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                              value: 'createdAt_desc', child: Text('Newest')),
                          DropdownMenuItem(
                              value: 'price_asc',
                              child: Text('Price low to high')),
                          DropdownMenuItem(
                              value: 'price_desc',
                              child: Text('Price high to low')),
                          DropdownMenuItem(
                              value: 'name_asc', child: Text('Name A-Z')),
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
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: AppColors.border),
                      ),
                      onPressed: _resetFilters,
                      child: const Text('Clear',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _homeHeaderColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _applyFilters,
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

// ---------------------------------------------------------------------------
// Section header — accent bar + title + "see all"
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionHeader({
    super.key,
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category row: text-only filter chips.
// ---------------------------------------------------------------------------
class _CategoryRow extends StatelessWidget {
  final List<FoodCategory> categories;
  final ValueChanged<FoodCategory> onCategoryTap;

  const _CategoryRow({
    required this.categories,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories
        .where((category) => category.isActive && category.name.isNotEmpty)
        .toList();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: visibleCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final category = visibleCategories[i];

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: _homeHeaderColor.withValues(alpha: 0.10),
            highlightColor: _homeHeaderColor.withValues(alpha: 0.05),
            onTap: () => onCategoryTap(category),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _homeSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                category.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
