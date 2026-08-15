import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../models/cart_item.dart';
import '../../models/food.dart';

import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/order_service.dart';
import '../../services/rating_service.dart';
import '../../services/food_service.dart';
import '../../states/cart_provider.dart';
import '../../widgets/app_button.dart';
import '../rating/create_rating_screen.dart';
import '../cart/cart_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/order-detail';

  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen>
    with TickerProviderStateMixin {
  final OrderService _orderService = OrderService(ApiClient());
  final RatingService _ratingService = RatingService(ApiClient());
  final FoodService _foodService = FoodService(ApiClient());

  Order? _order;
  bool _hasRatedAllItems = false;
  bool _isLoading = true;
  bool _isReordering = false;
  String? _errorMessage;
  String? _paymentErrorMessage;
  String? _paymentWarningMessage;
  bool _hasShownPaymentError = false;
  bool _hasShownPaymentWarning = false;
  bool _hasShownPaymentSuccess = false;
  Timer? _pollingTimer;
  Timer? _paymentTimeoutTimer;
  int _remainingPaymentSeconds = 0;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _fetchOrderDetail();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _paymentTimeoutTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderDetail({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await AuthStorage.getToken();
      final fetchedOrder =
          await _orderService.getOrderById(widget.orderId, token: token);
      final order =
          await _orderService.syncStaleActiveOrder(fetchedOrder, token: token);
      final hasRatedAllItems = await _hasReviewedAllFoodItems(order, token);

      if (!mounted) return;

      // Check for payment errors from note (same logic as sepay_payment_provider)
      String? errorMessage;
      String? warningMessage;
      
      final isSuccess = order.status == 'CONFIRMED' || order.paymentStatus == 'PAID';
      final note = order.note ?? "";
      
      if (!isSuccess) {
        if (note.contains("Error: Invalid payment amount")) {
          errorMessage = "You have transferred the incorrect amount. The order is not confirmed, please transfer the correct amount to confirm the order!";
        } else if (order.paymentStatus == 'REFUND_PENDING') {
          errorMessage = "The system received a late payment after the order was cancelled. Please show this screen to the Admin to get your money back.";
        }
      }
      
      if (note.contains("[DUPLICATE_PAYMENT]") || note.contains("[EXTRA_PAYMENT]")) {
        warningMessage = "The system detected that you overpaid for this order. Please contact the Canteen Admin to get a refund for the excess amount!";
      }

      setState(() {
        _order = order;
        _hasRatedAllItems = hasRatedAllItems;
        _paymentErrorMessage = errorMessage;
        _paymentWarningMessage = warningMessage;
        if (!quiet) _isLoading = false;
      });

      if (!quiet) _slideController.forward(from: 0);
      _startPolling();
      _startPaymentTimeoutTimer();

      // Show payment error message (only when polling detects new error, not on first load)
      if (errorMessage != null && errorMessage.isNotEmpty && !_hasShownPaymentError && quiet && mounted) {
        _hasShownPaymentError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Show payment warning message (only when polling detects new warning, not on first load)
      if (warningMessage != null && warningMessage.isNotEmpty && !_hasShownPaymentWarning && quiet && mounted) {
        _hasShownPaymentWarning = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warningMessage),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Show payment success message (only when polling detects success, not on first load)
      if (isSuccess && _order != null && _order!.paymentStatus == 'PAID' && !_hasShownPaymentSuccess && quiet && mounted) {
        _hasShownPaymentSuccess = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (!quiet) {
          _errorMessage = error.toString().replaceFirst('ApiException: ', '');
          _isLoading = false;
        }
      });
    }
  }

  Future<bool> _hasReviewedAllFoodItems(Order order, String? token) async {
    if (token == null || token.isEmpty) return false;

    try {
      final items = await _ratingService.getReviewableItems(
        orderId: order.id,
        token: token,
      );
      return items.isNotEmpty && items.every((item) => item.isReviewed);
    } catch (_) {
      return false;
    }
  }

  bool _isTerminalStatus(String status) {
    final s = status.toUpperCase();
    return s == 'COMPLETED' || s == 'CANCELLED' || s == 'EXPIRED';
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (_order == null || _isTerminalStatus(_order!.status)) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _fetchOrderDetail(quiet: true);
    });
  }

  // Helper function to get current Vietnam time (UTC+7) - matches backend time calculation
  DateTime _getCurrentVietnamTime() {
    final now = DateTime.now().toUtc();
    final vietnamOffset = const Duration(hours: 7);
    return now.add(vietnamOffset);
  }

  void _startPaymentTimeoutTimer() {
    _paymentTimeoutTimer?.cancel();
    if (_order == null || _order!.status != 'PENDING_PAYMENT') return;

    // Calculate remaining time from expiresAt
    final expiresAt = _order!.expiresAt;
    if (expiresAt == null) return;

    // Use Vietnam time (UTC+7) to match backend time calculation
    final now = _getCurrentVietnamTime();
    final remainingDuration = expiresAt.difference(now);

    if (remainingDuration.isNegative) {
      // Already expired, should be handled by backend
      setState(() {
        _remainingPaymentSeconds = 0;
      });
      return;
    }

    setState(() {
      _remainingPaymentSeconds = remainingDuration.inSeconds;
    });

    _paymentTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingPaymentSeconds > 0) {
          _remainingPaymentSeconds--;
        } else {
          timer.cancel();
          // Auto-refresh order status when timer expires
          _fetchOrderDetail(quiet: true);
          // Trigger backend to check for expired orders immediately
          _triggerExpiredOrderCheck();
        }
      });
    });
  }

  Future<void> _triggerExpiredOrderCheck() async {
    try {
      final token = await AuthStorage.getToken();
      await _orderService.triggerExpiredOrderCheck(token: token);
    } catch (_) {
      // Silently fail - this is just a trigger attempt
    }
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    Navigator.pop(context);
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final token = await AuthStorage.getToken();
      await _orderService.cancelOrder(widget.orderId, token: token);
      await _fetchOrderDetail();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final cleanMessage = error is ApiException
          ? error.message
          : error
              .toString()
              .replaceFirst('ApiException: ', '')
              .replaceFirst('Exception: ', '');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFCA5A5), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cancellation Failed',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(cleanMessage,
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _reorder() async {
    if (_order == null) return;
    
    setState(() => _isReordering = true);

    try {
      final token = await AuthStorage.getToken();
      
      // Get today's menu items to check availability
      final todayMenuItems = await _foodService.getTodayMenuFoods(token: token);
      final todayMenuIds = todayMenuItems.map((item) => item.id).toSet();
      
      List<String> unavailableItems = [];
      List<String> outOfStockItems = [];
      int successfullyAdded = 0;

      // Check each item before adding to cart
      for (final item in _order!.items) {
        final food = item.food;
        
        // Check if item is available in today's menu (for menu food)
        if (food.isMenuFood) {
          // Check if the food exists in today's menu by ID
          if (!todayMenuIds.contains(food.id)) {
            unavailableItems.add(food.name);
            continue;
          }
          
          // Find the today's menu item to get fresh data
          final todayMenuItem = todayMenuItems.firstWhere(
            (f) => f.id == food.id,
            orElse: () => food,
          );
          
          // For menu food, use the current menuScheduleItemId from today's menu
          final updatedFood = food.copyWith(
            menuScheduleItemId: todayMenuItem.menuScheduleItemId,
            status: todayMenuItem.status,
            remainingServings: todayMenuItem.remainingServings,
          );
          
          // Add item to cart
          final cartNotifier = ref.read(cartProvider.notifier);
          await cartNotifier.addItem(
            updatedFood,
            quantity: item.quantity,
            notify: false,
          );
          successfullyAdded++;
        } else {
          // For always available items, check stock
          if (food.status == FoodStatus.outOfStock ||
              (food.stockQuantity != null && food.stockQuantity! <= 0)) {
            outOfStockItems.add(food.name);
            continue;
          }

          // Add item to cart
          final cartNotifier = ref.read(cartProvider.notifier);
          await cartNotifier.addItem(
            food,
            quantity: item.quantity,
            notify: false,
          );
          successfullyAdded++;
        }
      }

      // Show appropriate message based on results
      if (mounted) {
        if (unavailableItems.isEmpty && outOfStockItems.isEmpty) {
          // All items added successfully
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF86EFAC), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Items added to cart',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          // Navigate to cart screen
          if (mounted) {
            Navigator.pushNamed(context, CartScreen.routeName);
          }
        } else {
          // Some items were unavailable or out of stock
          String message = '';
          if (unavailableItems.isNotEmpty) {
            message += 'Not in today\'s menu: ${unavailableItems.join(", ")}. ';
          }
          if (outOfStockItems.isNotEmpty) {
            message += 'Out of stock: ${outOfStockItems.join(", ")}. ';
          }
          if (successfullyAdded > 0) {
            message += '($successfullyAdded item(s) added to cart)';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFCD34D), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Some items unavailable',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(message,
                            style: const TextStyle(
                                color: Color(0xFFCBD5E1), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 5),
            ),
          );

          // Navigate to cart if any items were added
          if (successfullyAdded > 0 && mounted) {
            Navigator.pushNamed(context, CartScreen.routeName);
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      
      final cleanMessage = error is ApiException
          ? error.message
          : error
              .toString()
              .replaceFirst('ApiException: ', '')
              .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFCA5A5), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to add items',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(cleanMessage,
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isReordering = false);
      }
    }
  }

  // ─── Backend Status Flow ──────────────────────────────────────────────────
  // PENDING_PAYMENT → (sepay confirmed) → CONFIRMED
  // PAID (cash)     → (QR scan)         → CONFIRMED
  //                                      → (callNextNumber) → COMPLETED
  bool _isStepDone(String status, String step) {
    final s = status.toUpperCase();
    if (s == 'CANCELLED' || s == 'EXPIRED') return false;
    switch (step) {
      case 'placed':
        return true;
      case 'paid':
        return s == 'PAID' || s == 'CONFIRMED' || s == 'COMPLETED';
      case 'confirmed':
        return s == 'CONFIRMED' || s == 'COMPLETED';
      case 'ready':
        return s == 'COMPLETED';
      default:
        return false;
    }
  }

  bool _isStepActive(String status, String step) {
    final s = status.toUpperCase();
    if (s == 'CANCELLED' || s == 'EXPIRED') return false;
    switch (step) {
      case 'placed':
        return false;
      case 'paid':
        return s == 'PENDING_PAYMENT';
      case 'confirmed':
        return s == 'PAID';
      case 'ready':
        return s == 'CONFIRMED';
      default:
        return false;
    }
  }

  _StatusMeta _statusMeta(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_PAYMENT':
        return _StatusMeta(
          label: 'Pending Payment',
        );
      case 'PAID':
        return _StatusMeta(
          label: 'Paid',
        );
      case 'CONFIRMED':
        return _StatusMeta(
          label: 'In Kitchen',
        );
      case 'COMPLETED':
        return _StatusMeta(
          label: 'Completed',
        );
      case 'CANCELLED':
        return _StatusMeta(
          label: 'Cancelled',
        );
      case 'EXPIRED':
        return _StatusMeta(
          label: 'Expired',
        );
      default:
        return _StatusMeta(
          label: status,
        );
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime.toLocal());
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Loading order details...',
                  style: TextStyle(color: AppColors.subText, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Order Details'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: AppColors.error, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  _errorMessage ?? 'Failed to load order details.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.subText, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _fetchOrderDetail,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final s = order.status.toUpperCase();
    final canCancel = s == 'PENDING_PAYMENT' || s == 'PAID';
    final canRate = s == 'COMPLETED' &&
        order.paymentStatus.toUpperCase() == 'PAID' &&
        !_hasRatedAllItems;
    final canReorder = s == 'COMPLETED' || s == 'CANCELLED';
    final meta = _statusMeta(order.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchOrderDetail,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Hero Header ────────────────────────────────────────
            SliverToBoxAdapter(child: _buildOrderHeader(order, meta)),

            // ─── Body content ────────────────────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Order Code Banner ─────────────────────
                        // ── Payment QR Code (only show when payment is pending and order not cancelled/expired/completed)
                        if (order.status.toUpperCase() != 'CANCELLED' &&
                            order.status.toUpperCase() != 'EXPIRED' &&
                            order.status.toUpperCase() != 'COMPLETED' &&
                            order.paymentStatus.toUpperCase() == 'PENDING' &&
                            order.paymentInfo?.qrCodeUrl != null &&
                            order.paymentInfo!.qrCodeUrl!.isNotEmpty) ...[
                          _buildSectionTitle('Payment QR Code'),
                          const SizedBox(height: 12),
                          _buildPaymentQRCodeCard(order),
                          const SizedBox(height: 24),
                        ],
                        // ── Order Code QR (show when payment is completed/confirmed and order is PAID or CONFIRMED, not COMPLETED)
                        if (order.status.toUpperCase() != 'CANCELLED' &&
                            order.status.toUpperCase() != 'EXPIRED' &&
                            order.status.toUpperCase() != 'COMPLETED' &&
                            (order.status.toUpperCase() == 'PAID' || order.status.toUpperCase() == 'CONFIRMED') &&
                            order.code.isNotEmpty) ...[
                          _buildSectionTitle('Order Code'),
                          const SizedBox(height: 12),
                          _buildOrderCodeCard(order),
                          const SizedBox(height: 24),
                        ],
                        // ── Timeline ──────────────────────────────
                        _buildSectionTitle('Order Timeline'),
                        const SizedBox(height: 12),
                        _buildTimeline(order),
                        const SizedBox(height: 24),
                        // ── Order Info ───────────────────────────
                        // ── Order Items ──────────────────────────
                        _buildSectionTitle('Order Items'),
                        const SizedBox(height: 12),
                        _buildItemsCard(order),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Order Info'),
                        const SizedBox(height: 12),
                        _buildInfoCard(order),
                        const SizedBox(height: 28),
                        // ── Action Buttons ────────────────────────
                        _buildActions(context, order, canCancel, canRate, canReorder),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(Order order, _StatusMeta meta) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.text,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.label,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.subText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            const TextSpan(text: 'Order Code  '),
                            TextSpan(
                              text: order.code,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'QUEUE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.queueNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
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
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing,
        ],
      ],
    );
  }

  Widget _buildTimeline(Order order) {
    final steps = [
      _TimelineStep(
        title: 'Order Placed',
        icon: Icons.shopping_bag_outlined,
        stepKey: 'placed',
      ),
      _TimelineStep(
        title: 'Payment Confirmed',
        icon: Icons.credit_card_rounded,
        stepKey: 'paid',
      ),
      _TimelineStep(
        title: 'Order Confirmed',
        icon: Icons.restaurant_rounded,
        stepKey: 'confirmed',
      ),
      _TimelineStep(
        title: 'Ready for Pickup',
        icon: Icons.check_circle_outline_rounded,
        stepKey: 'ready',
      ),
    ];

    final isCancelledOrExpired =
        ['CANCELLED', 'EXPIRED'].contains(order.status.toUpperCase());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isCancelledOrExpired)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    order.status.toUpperCase() == 'CANCELLED'
                        ? Icons.cancel_outlined
                        : Icons.timer_off_outlined,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    order.status.toUpperCase() == 'CANCELLED'
                        ? 'This order was cancelled'
                        : 'This order expired',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: steps.asMap().entries.map((entry) {
                final idx = entry.key;
                final step = entry.value;
                final done = _isStepDone(order.status, step.stepKey);
                final isActive = _isStepActive(order.status, step.stepKey);
                final isLast = idx == steps.length - 1;
                return _TimelineItem(
                  step: step,
                  done: done,
                  isActive: isActive,
                  isLast: isLast,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Order order) {
    final paymentPaid = order.paymentStatus.toUpperCase() == 'PAID';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.qr_code_rounded,
            label: 'Order Code',
            value: order.code,
            isFirst: true,
          ),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Placed At',
            value: _formatDateTime(order.createdAt),
          ),
          _InfoRow(
            icon: Icons.payment_rounded,
            label: 'Payment Method',
            value: order.paymentMethod,
          ),
          _InfoRow(
            icon: paymentPaid
                ? Icons.check_circle_rounded
                : Icons.pending_rounded,
            label: 'Payment Status',
            value: order.paymentStatus,
            valueColor: paymentPaid ? AppColors.success : AppColors.warning,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCodeCard(Order order) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Scan for Counter Staff',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: QrImageView(
                  data: order.code,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Order Code: ${order.code}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentQRCodeCard(Order order) {
    if (order.paymentInfo?.qrCodeUrl == null) {
      return const SizedBox.shrink();
    }

    // Check if payment time has expired
    if (_remainingPaymentSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final minutes = _remainingPaymentSeconds ~/ 60;
    final seconds = _remainingPaymentSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Countdown Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _remainingPaymentSeconds <= 60
                    ? Colors.red.withValues(alpha: 0.1)
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _remainingPaymentSeconds <= 60
                      ? Colors.red.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: _remainingPaymentSeconds <= 60 ? Colors.red : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment expires in $timeString',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _remainingPaymentSeconds <= 60 ? Colors.red : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bank Info Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  order.paymentInfo?.bankName ?? 'Vietcombank',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // QR Code Image
            Container(
              width: 240,
              height: 240,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  order.paymentInfo!.qrCodeUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Could not load QR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Total Amount
            const Text(
              'Total Payment',
              style: TextStyle(color: AppColors.subText, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.vnd(order.totalPrice),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Manual Transfer Section
            _buildCopyRow(
              context,
              'Account Number',
              order.paymentInfo?.accountNumber ?? 'N/A',
              icon: Icons.numbers,
            ),
            const SizedBox(height: 12),
            _buildCopyRow(
              context,
              'Amount',
              order.totalPrice.toString(),
              displayValue: CurrencyFormatter.vnd(order.totalPrice),
              icon: Icons.payments,
            ),
            const SizedBox(height: 12),
            _buildCopyRow(
              context,
              'Transfer Content',
              order.transferContent ?? order.code,
              icon: Icons.edit_document,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyRow(BuildContext context, String title, String value,
      {String? displayValue, required IconData icon}) {
    return _CopyRowWidget(
      title: title,
      value: value,
      displayValue: displayValue,
      icon: icon,
    );
  }

  Widget _buildItemsCard(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...order.items.map((item) => _buildItemRow(item)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppColors.border, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_rounded,
                        color: AppColors.subText, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Total',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.subText),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.vnd(order.totalPrice),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    final imageUrl = _resolvedImageUrl(item.food);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl == null
                  ? Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.fastfood_rounded,
                          color: AppColors.primary, size: 26),
                    )
                  : Image.network(
                      imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.fastfood_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.food.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.text),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '×${item.quantity}',
                        style: const TextStyle(
                            color: AppColors.subText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      CurrencyFormatter.vnd(item.food.price),
                      style: const TextStyle(
                          color: AppColors.subText, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.vnd(item.subtotal),
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, Order order, bool canCancel, bool canRate, bool canReorder) {
    return Column(
      children: [
        if (canReorder)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isReordering ? null : _reorder,
              icon: _isReordering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isReordering ? 'Adding...' : 'Re-order',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        if (canRate) ...[
          if (canReorder) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  CreateRatingScreen.routeName,
                  arguments: CreateRatingArgs(order: order),
                );
                if (mounted) await _fetchOrderDetail(quiet: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF3C7),
                foregroundColor: const Color(0xFFD97706),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Rate Your Meal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        if (canCancel) ...[
          if (canRate || canReorder) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(context),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel Order',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cancel this order?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can cancel before the kitchen starts final preparation. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.subText, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Keep Order',
                    secondary: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Cancel Order',
                    danger: true,
                    onPressed: _cancelOrder,
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

// ─── Copy Row Widget ──────────────────────────────────────────────────────────
class _CopyRowWidget extends StatefulWidget {
  final String title;
  final String value;
  final String? displayValue;
  final IconData icon;

  const _CopyRowWidget({
    required this.title,
    required this.value,
    this.displayValue,
    required this.icon,
  });

  @override
  State<_CopyRowWidget> createState() => _CopyRowWidgetState();
}

class _CopyRowWidgetState extends State<_CopyRowWidget> {
  bool _isCopied = false;

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${widget.title}!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {
      _isCopied = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isCopied ? Colors.green.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isCopied ? Colors.green.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, color: AppColors.primaryDark, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          color: AppColors.subText, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    widget.displayValue ?? widget.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isCopied ? Icons.check_circle : Icons.copy_rounded,
              size: 20,
              color: _isCopied ? Colors.green : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data Helpers ────────────────────────────────────────────────────────────
class _StatusMeta {
  final String label;

  _StatusMeta({
    required this.label,
  });
}

class _TimelineStep {
  final String title;
  final IconData icon;
  final String stepKey;

  _TimelineStep({
    required this.title,
    required this.icon,
    required this.stepKey,
  });
}

// ─── Timeline Item ────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final _TimelineStep step;
  final bool done;
  final bool isActive;
  final bool isLast;

  const _TimelineItem({
    required this.step,
    required this.done,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    Color lineColor;

    if (done) {
      iconBg = AppColors.primary;
      iconColor = Colors.white;
      lineColor = AppColors.primary;
    } else if (isActive) {
      iconBg = AppColors.primarySoft;
      iconColor = AppColors.primary;
      lineColor = AppColors.border;
    } else {
      iconBg = AppColors.muted;
      iconColor = AppColors.subText;
      lineColor = AppColors.border;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + Line column
        SizedBox(
          width: 40,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  boxShadow: done
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : isActive
                        ? _PulsingInnerDot(color: AppColors.primary)
                        : Icon(step.icon, color: iconColor, size: 17),
              ),
              if (!isLast)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 2,
                  height: 36,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Text content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: done || isActive
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: done || isActive
                              ? AppColors.text
                              : AppColors.subText,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Now',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppColors.subText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.subText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: valueColor ?? AppColors.text,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppColors.border),
          ),
      ],
    );
  }
}

// ─── Pulsing Inner Dot (for active step) ─────────────────────────────────────
class _PulsingInnerDot extends StatefulWidget {
  final Color color;
  const _PulsingInnerDot({required this.color});

  @override
  State<_PulsingInnerDot> createState() => _PulsingInnerDotState();
}

class _PulsingInnerDotState extends State<_PulsingInnerDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0)
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
      animation: _scaleAnim,
      builder: (_, __) => Transform.scale(
        scale: _scaleAnim.value,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
