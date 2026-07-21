import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
  final TextEditingController _commentController = TextEditingController();

  List<Order> _completedOrders = [];
  Order? _selectedOrder;
  int _stars = 5;
  bool _isLoading = true;
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
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final rating = widget.rating;
    if (rating != null) {
      _commentController.text = rating.comment ?? '';
      setState(() {
        _stars = rating.stars.clamp(1, 5);
        _isLoading = false;
      });
      return;
    }

    final initialOrder = widget.initialOrder;
    if (initialOrder != null) {
      setState(() {
        _selectedOrder = initialOrder;
        _completedOrders = [initialOrder];
        _isLoading = false;
      });
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

      final orders = await _orderService.getOrders(token: token);
      final completed = orders.where(_canReviewOrder).toList();
      setState(() {
        _token = token;
        _completedOrders = completed;
        _selectedOrder = completed.isNotEmpty ? completed.first : null;
        _isLoading = false;
      });
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
        _error = error.toString();
      });
    }
  }

  bool _canReviewOrder(Order order) {
    return order.status.toUpperCase() == 'COMPLETED' &&
        order.paymentStatus.toUpperCase() == 'PAID';
  }

  void _selectOrder(Order? order) {
    if (order == null) return;
    setState(() {
      _selectedOrder = order;
    });
  }

  Future<void> _submit() async {
    if (_stars < 1 || _stars > 5) {
      _showError('Please select a star rating.');
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

      final comment = _commentController.text.trim();
      if (_isEditMode) {
        await _ratingService.updateRating(
          ratingId: widget.rating!.id,
          stars: _stars,
          comment: comment,
          token: token,
        );
      } else {
        final order = _selectedOrder;
        if (order == null) {
          throw ApiException(
            statusCode: 400,
            message: 'Please select a completed order.',
          );
        }

        if (!_canReviewOrder(order)) {
          throw ApiException(
            statusCode: 400,
            message: 'You can review only after receiving your food.',
          );
        }

        await _ratingService.createRating(
          orderId: order.id,
          ratingType: 'ORDER',
          stars: _stars,
          comment: comment,
          token: token,
        );
      }

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
      appBar: AppBar(title: Text(_isEditMode ? 'Update Rating' : 'Rate Meal')),
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
                  else ...[
                    if (_isEditMode)
                      _RatingTargetCard(rating: widget.rating!)
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
                      ],
                    ],
                    const SizedBox(height: 34),
                    const Text(
                      'How was your meal?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StarPicker(
                        value: _stars,
                        onChanged: (v) {
                          setState(() => _stars = v);
                        }),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Comment',
                        hintText: 'Tell us about your experience.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      label: _isEditMode ? 'Update Rating' : 'Submit Rating',
                      isLoading: _isSubmitting,
                      onPressed: (!_isEditMode && _completedOrders.isEmpty)
                          ? null
                          : _submit,
                    ),
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
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedOrder?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Select order'),
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

class _RatingTargetCard extends StatelessWidget {
  final CustomerRating rating;

  const _RatingTargetCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rating.targetLabel,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your review',
            style: TextStyle(color: AppColors.subText),
          ),
        ],
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (index) {
          final star = index + 1;
          return IconButton(
            onPressed: () => onChanged(star),
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_border_rounded,
              color: AppColors.primary,
              size: 36,
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
          const Icon(Icons.rate_review_outlined,
              size: 48, color: AppColors.subText),
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
