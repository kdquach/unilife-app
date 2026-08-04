import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_rating.dart';
import '../../models/order.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/order_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../auth/login_screen.dart';
import 'rating_success_screen.dart';

class CreateRatingArgs {
  final Order? order;
  final CustomerRating? rating;

  const CreateRatingArgs({this.order, this.rating});
}

class CreateRatingScreen extends StatefulWidget {
  static const String routeName = '/create-rating';

  final Order? initialOrder;
  final CustomerRating? rating;

  const CreateRatingScreen({
    super.key,
    this.initialOrder,
    this.rating,
  });

  @override
  State<CreateRatingScreen> createState() => _CreateRatingScreenState();
}

class _CreateRatingScreenState extends State<CreateRatingScreen> {
  final OrderService _orderService = OrderService(ApiClient());
  final RatingService _ratingService = RatingService(ApiClient());

  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, int> _starsByOrderItem = {};

  List<Order> _completedOrders = [];
  List<ReviewableRatingItem> _reviewableItems = [];
  Order? _selectedOrder;
  bool _isLoading = true;
  bool _isLoadingItems = false;
  bool _isSubmitting = false;
  String? _error;
  String? _token;

  bool get _isEditMode => widget.rating != null;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final rating = widget.rating;
    if (rating != null) {
      final controller = _controllerFor(rating.id);
      controller.text = rating.comment ?? '';
      _starsByOrderItem[rating.id] = rating.stars.clamp(1, 5);
      setState(() => _isLoading = false);
      return;
    }

    final token = await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _token = null;
        _isLoading = false;
        _error = 'Please log in to create a rating.';
      });
      return;
    }

    _token = token;

    final initialOrder = widget.initialOrder;
    if (initialOrder != null) {
      setState(() {
        _selectedOrder = initialOrder;
        _completedOrders = [initialOrder];
        _isLoading = false;
      });
      await _loadReviewableItems(initialOrder);
      return;
    }

    await _loadCompletedOrders();
  }

  Future<void> _loadCompletedOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = _token ?? await AuthStorage.getToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() {
          _token = null;
          _isLoading = false;
          _error = 'Please log in to create a rating.';
        });
        return;
      }

      final orders = await _orderService.getOrders(token: token);
      final completed = orders.where(_canReviewOrder).toList();
      final selectedOrder = completed.isNotEmpty ? completed.first : null;
      setState(() {
        _token = token;
        _completedOrders = completed;
        _selectedOrder = selectedOrder;
        _isLoading = false;
      });

      if (selectedOrder != null) {
        await _loadReviewableItems(selectedOrder);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) await AuthStorage.clearToken();
      setState(() {
        _token = error.statusCode == 401 ? null : _token;
        _isLoading = false;
        _error = error.statusCode == 401
            ? 'Please log in to create a rating.'
            : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _loadReviewableItems(Order order) async {
    setState(() {
      _isLoadingItems = true;
      _error = null;
      _reviewableItems = [];
    });

    try {
      final token = _token ?? await AuthStorage.getToken();
      final items = await _ratingService.getReviewableItems(
        orderId: order.id,
        token: token,
      );
      if (!mounted) return;
      _resetDrafts(items);
      setState(() {
        _reviewableItems = items;
        _isLoadingItems = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _error = _cleanError(error);
      });
    }
  }

  void _resetDrafts(List<ReviewableRatingItem> items) {
    final validIds = items.map((item) => item.orderItemId).toSet();
    final staleIds = _commentControllers.keys
        .where((id) => !validIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _commentControllers.remove(id)?.dispose();
      _starsByOrderItem.remove(id);
    }

    for (final item in items) {
      final controller = _controllerFor(item.orderItemId);
      if (item.isReviewed) {
        controller.text = item.review?.comment ?? '';
        _starsByOrderItem[item.orderItemId] =
            (item.review?.stars ?? 5).clamp(1, 5);
      } else {
        controller.clear();
        _starsByOrderItem[item.orderItemId] = 5;
      }
    }
  }

  TextEditingController _controllerFor(String orderItemId) {
    return _commentControllers.putIfAbsent(
      orderItemId,
      TextEditingController.new,
    );
  }

  bool _canReviewOrder(Order order) {
    return order.status.toUpperCase() == 'COMPLETED' &&
        order.paymentStatus.toUpperCase() == 'PAID';
  }

  Future<void> _selectOrder(Order? order) async {
    if (order == null) return;
    setState(() => _selectedOrder = order);
    await _loadReviewableItems(order);
  }

  void _setStars(String orderItemId, int stars) {
    setState(() => _starsByOrderItem[orderItemId] = stars);
  }

  Future<void> _submit() async {
    if (_isEditMode) {
      await _submitEdit();
      return;
    }

    final order = _selectedOrder;
    if (order == null) {
      _showError('Please select a completed order.');
      return;
    }

    final reviews = _reviewableItems
        .where((item) => !item.isReviewed)
        .map(
          (item) => {
            'orderItemId': item.orderItemId,
            'foodId': item.foodId,
            'stars': _starsByOrderItem[item.orderItemId] ?? 5,
            'comment': _controllerFor(item.orderItemId).text.trim(),
          },
        )
        .toList();

    if (reviews.isEmpty) {
      _showError('All food items in this order have already been reviewed.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = _token ?? await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        Navigator.pushNamed(context, LoginScreen.routeName);
        return;
      }

      await _ratingService.createRatingsBulk(
        orderId: order.id,
        reviews: reviews,
        token: token,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RatingSuccessScreen.routeName);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(_cleanError(error));
    }
  }

  Future<void> _submitEdit() async {
    final rating = widget.rating;
    if (rating == null) return;

    setState(() => _isSubmitting = true);
    try {
      final token = _token ?? await AuthStorage.getToken();
      await _ratingService.updateRating(
        ratingId: rating.id,
        stars: _starsByOrderItem[rating.id] ?? rating.stars,
        comment: _controllerFor(rating.id).text.trim(),
        token: token,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, RatingSuccessScreen.routeName);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(_cleanError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditMode ? 'Update Rating' : 'Rate Your Food')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _isEditMode ? () async {} : _loadCompletedOrders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null)
                    _MessageState(
                      message: _error!,
                      actionLabel: _token == null ? 'Login' : 'Retry',
                      onAction: _token == null
                          ? () => Navigator.pushNamed(
                                context,
                                LoginScreen.routeName,
                              )
                          : _loadCompletedOrders,
                    )
                  else if (_isEditMode)
                    _EditRatingForm(
                      rating: widget.rating!,
                      stars: _starsByOrderItem[widget.rating!.id] ??
                          widget.rating!.stars,
                      controller: _controllerFor(widget.rating!.id),
                      isSubmitting: _isSubmitting,
                      onStarsChanged: (stars) =>
                          _setStars(widget.rating!.id, stars),
                      onSubmit: _submit,
                    )
                  else ...[
                    if (_completedOrders.isEmpty)
                      const _MessageState(
                        message:
                            'No completed paid orders are available for review.',
                      )
                    else ...[
                      _OrderPicker(
                        orders: _completedOrders,
                        selectedOrder: _selectedOrder,
                        onChanged: _selectOrder,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Rate each food item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Each item has its own stars and comment.',
                        style: TextStyle(
                          color: AppColors.subText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isLoadingItems)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_reviewableItems.isEmpty)
                        const _MessageState(
                          message:
                              'No food items are available for review in this order.',
                        )
                      else
                        ..._reviewableItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _FoodReviewDraftCard(
                              item: item,
                              stars: _starsByOrderItem[item.orderItemId] ?? 5,
                              controller: _controllerFor(item.orderItemId),
                              onStarsChanged: (stars) =>
                                  _setStars(item.orderItemId, stars),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Submit',
                        isLoading: _isSubmitting,
                        onPressed: _reviewableItems
                                .where((item) => !item.isReviewed)
                                .isEmpty
                            ? null
                            : _submit,
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _OrderPicker extends StatelessWidget {
  final List<Order> orders;
  final Order? selectedOrder;
  final ValueChanged<Order?> onChanged;

  const _OrderPicker({
    required this.orders,
    required this.selectedOrder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed order',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select order',
            style: TextStyle(color: AppColors.subText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedOrder?.id,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: orders
                .map(
                  (order) => DropdownMenuItem(
                    value: order.id,
                    child: Text('Order #${order.code}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              final order = _firstWhereOrNull(
                orders,
                (item) => item.id == value,
              );
              onChanged(order);
            },
          ),
        ],
      ),
    );
  }
}

class _FoodReviewDraftCard extends StatelessWidget {
  final ReviewableRatingItem item;
  final int stars;
  final TextEditingController controller;
  final ValueChanged<int> onStarsChanged;

  const _FoodReviewDraftCard({
    required this.item,
    required this.stars,
    required this.controller,
    required this.onStarsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isReviewed = item.isReviewed;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.foodName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (isReviewed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Reviewed',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Quantity: ${item.quantity} · ${CurrencyFormatter.vnd(item.unitPrice)} each',
            style: const TextStyle(color: AppColors.subText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _StarPicker(
            value: stars,
            enabled: !isReviewed,
            onChanged: onStarsChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: !isReviewed,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Comment',
              counterStyle: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRatingForm extends StatelessWidget {
  final CustomerRating rating;
  final int stars;
  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<int> onStarsChanged;
  final VoidCallback onSubmit;

  const _EditRatingForm({
    required this.rating,
    required this.stars,
    required this.controller,
    required this.isSubmitting,
    required this.onStarsChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rating.targetLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your review',
                style: TextStyle(color: AppColors.subText),
              ),
              const SizedBox(height: 16),
              _StarPicker(value: stars, onChanged: onStarsChanged),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Comment'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Update Rating',
          isLoading: isSubmitting,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _StarPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) {
          final star = index + 1;
          return InkWell(
            onTap: enabled ? () => onChanged(star) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                star <= value
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: enabled
                    ? AppColors.primary
                    : AppColors.subText.withValues(alpha: 0.45),
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: AppColors.subText,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subText),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
