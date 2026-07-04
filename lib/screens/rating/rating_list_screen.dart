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
import 'create_rating_screen.dart';

class RatingListScreen extends StatefulWidget {
  static const String routeName = '/ratings';

  const RatingListScreen({super.key});

  @override
  State<RatingListScreen> createState() => _RatingListScreenState();
}

class _RatingListScreenState extends State<RatingListScreen> {
  final RatingService _ratingService = RatingService(ApiClient());

  List<CustomerRating> _ratings = [];
  Set<String> _myRatingIds = {};
  bool _isLoading = true;
  String? _error;
  String? _token;

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
      if (token == null || token.isEmpty) {
        setState(() {
          _token = null;
          _ratings = [];
          _myRatingIds = {};
          _isLoading = false;
          _error = 'Please log in to view your ratings.';
        });
        return;
      }

      final ratings = await _ratingService.getMyRatings(token: token);
      if (!mounted) return;
      setState(() {
        _token = token;
        _ratings = ratings;
        _myRatingIds = ratings.map((rating) => rating.id).toSet();
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) await AuthStorage.clearToken();
      setState(() {
        _token = error.statusCode == 401 ? null : _token;
        _ratings = [];
        _myRatingIds = {};
        _isLoading = false;
        _error = error.statusCode == 401
            ? 'Please log in to view your ratings.'
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

  Future<void> _openCreate() async {
    final token = _token ?? await AuthStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await Navigator.pushNamed(context, LoginScreen.routeName);
      if (mounted) await _loadRatings();
      return;
    }

    await Navigator.pushNamed(context, CreateRatingScreen.routeName);
    if (mounted) await _loadRatings();
  }

  Future<void> _openEdit(CustomerRating rating) async {
    await Navigator.pushNamed(
      context,
      CreateRatingScreen.routeName,
      arguments: CreateRatingArgs(rating: rating),
    );
    if (mounted) await _loadRatings();
  }

  Future<void> _deleteRating(CustomerRating rating) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete this rating?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Keep',
                    secondary: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Delete',
                    danger: true,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    try {
      await _ratingService.deleteRating(rating.id, token: _token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating deleted')),
      );
      await _loadRatings();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ratings')),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            AppButton(
              label: 'Create New Rating',
              secondary: true,
              onPressed: _openCreate,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _MessageState(
                icon: Icons.lock_outline_rounded,
                message: _error!,
                actionLabel: _token == null ? 'Login' : 'Retry',
                onAction: _token == null
                    ? () => Navigator.pushNamed(context, LoginScreen.routeName)
                    : _loadRatings,
              )
            else if (_ratings.isEmpty)
              _MessageState(
                icon: Icons.rate_review_outlined,
                message:
                    'You have not submitted any ratings yet. You can review completed orders.',
                actionLabel: 'Refresh',
                onAction: _loadRatings,
              )
            else
              ..._ratings.map(
                (rating) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RatingCard(
                    rating: rating,
                    canManage: _myRatingIds.contains(rating.id),
                    onEdit: () => _openEdit(rating),
                    onDelete: () => _deleteRating(rating),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final CustomerRating rating;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RatingCard({
    required this.rating,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
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
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
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
