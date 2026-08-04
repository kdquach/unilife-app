import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/customer_rating.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/rating_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../auth/login_screen.dart';

class RatingListScreen extends StatefulWidget {
  static const String routeName = '/ratings';

  final RatingListArgs? args;

  const RatingListScreen({super.key, this.args});

  @override
  State<RatingListScreen> createState() => _RatingListScreenState();
}

class _RatingListScreenState extends State<RatingListScreen> {
  final RatingService _ratingService = RatingService(ApiClient());

  List<CustomerRating> _ratings = [];
  RatingPage? _ratingsPage;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String? _token;

  bool get _isFoodReviewMode =>
      widget.args?.foodId != null && widget.args!.foodId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthStorage.getToken();
      if (!mounted) return;
      if (_isFoodReviewMode) {
        final result = await _loadFoodRatingsPage(
          token: token,
          page: 1,
          limit: 20,
        );
        if (!mounted) return;
        setState(() {
          _token = token;
          _ratings = result.items;
          _ratingsPage = result;
          _isLoading = false;
        });
        return;
      }

      if (token == null || token.isEmpty) {
        setState(() {
          _token = null;
          _ratings = [];
          _ratingsPage = null;
          _isLoading = false;
          _error = 'Please log in to view your ratings.';
        });
        return;
      }

      final result = await _ratingService.getMyRatingsPage(token: token);
      if (!mounted) return;
      setState(() {
        _token = token;
        _ratings = result.items;
        _ratingsPage = result;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) await AuthStorage.clearToken();
      setState(() {
        _token = error.statusCode == 401 ? null : _token;
        _ratings = [];
        _ratingsPage = null;
        _isLoading = false;
        if (_isFoodReviewMode &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          _error = null;
        } else {
          _error = error.statusCode == 401
              ? 'Please log in to view your ratings.'
              : error.message;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadMoreRatings() async {
    final currentPage = _ratingsPage;
    if (currentPage == null || !currentPage.hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = currentPage.page + 1;
      final result = _isFoodReviewMode
          ? await _loadFoodRatingsPage(
              token: _token,
              page: nextPage,
              limit: currentPage.limit,
            )
          : await _ratingService.getMyRatingsPage(
              token: _token,
              page: nextPage,
              limit: currentPage.limit,
            );
      if (!mounted) return;
      setState(() {
        _ratings = [..._ratings, ...result.items];
        _ratingsPage = result;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<RatingPage> _loadFoodRatingsPage({
    required String? token,
    required int page,
    required int limit,
  }) async {
    return _ratingService.getRatingsPage(
      token: token,
      foodId: widget.args!.foodId,
      ratingType: 'FOOD',
      page: page,
      limit: limit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args?.title ?? 'Ratings')),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (_isFoodReviewMode && widget.args?.foodName != null) ...[
              Text(
                widget.args!.foodName!,
                style: const TextStyle(
                  color: AppColors.subText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _MessageState(
                icon: _isFoodReviewMode
                    ? Icons.rate_review_outlined
                    : Icons.lock_outline_rounded,
                message: _error!,
                actionLabel:
                    !_isFoodReviewMode && _token == null ? 'Login' : 'Retry',
                onAction: !_isFoodReviewMode && _token == null
                    ? () => Navigator.pushNamed(context, LoginScreen.routeName)
                    : _loadRatings,
              )
            else if (_ratings.isEmpty)
              _MessageState(
                icon: Icons.rate_review_outlined,
                message: _isFoodReviewMode
                    ? 'No comments yet'
                    : 'You have not submitted any ratings yet. You can review completed orders.',
                actionLabel: 'Refresh',
                onAction: _loadRatings,
              )
            else
              ..._ratings.map(
                (rating) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RatingCard(
                    rating: rating,
                  ),
                ),
              ),
            if (!_isLoading && _ratingsPage?.hasMore == true) ...[
              const SizedBox(height: 4),
              AppButton(
                label: 'Load More',
                secondary: true,
                isLoading: _isLoadingMore,
                onPressed: _loadMoreRatings,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RatingListArgs {
  final String? foodId;
  final String? foodName;
  final String? title;

  const RatingListArgs({
    this.foodId,
    this.foodName,
    this.title,
  });
}

class _RatingCard extends StatelessWidget {
  final CustomerRating rating;

  const _RatingCard({
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.targetLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rating.user?.fullName ?? 'Customer',
                      style: const TextStyle(color: AppColors.subText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stars(value: rating.stars),
          const SizedBox(height: 10),
          Text(
            rating.comment ?? 'No comment',
            style: const TextStyle(color: AppColors.subText, height: 1.4),
          ),
          if (rating.staffReply != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Staff reply: ${rating.staffReply}'),
            ),
          ],
          if (rating.createdAt != null) ...[
            const SizedBox(height: 10),
            Text(
              DateFormat('dd/MM/yyyy HH:mm')
                  .format(rating.createdAt!.toLocal()),
              style: const TextStyle(color: AppColors.subText, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int value;

  const _Stars({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < value ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.subText),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subText),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}
