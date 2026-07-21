import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_notification.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_card.dart';

class NotificationDetailScreen extends StatefulWidget {
  static const String routeName = '/notification-detail';

  final UserNotification? initialNotification;

  const NotificationDetailScreen({super.key, this.initialNotification});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final NotificationService _notificationService =
      NotificationService(ApiClient());

  UserNotification? _notification;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _notification = widget.initialNotification;
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final notification = _notification;
    if (notification == null || notification.id.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final token = await AuthStorage.getToken();
      final updated = await _notificationService.getMineById(
        notification.id,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _notification = updated;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = _notification;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: notification == null
          ? const Center(child: Text('Notification not found.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 16),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(notification.createdAt),
                        style: const TextStyle(color: AppColors.subText),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _typeLabel(notification.type),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          color: AppColors.subText,
                          height: 1.5,
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

String _typeLabel(String type) {
  switch (type) {
    case 'CART_ITEM_ADDED':
      return 'Cart update';
    case 'ORDER_CREATED':
      return 'Order created';
    case 'PAYMENT_SUCCESS':
      return 'Payment success';
    case 'ORDER_CANCELLED':
      return 'Order cancelled';
    case 'ORDER_COMPLETED':
    case 'ORDER_DONE':
    case 'ORDER_FINISHED':
      return 'Order completed';
    case 'ORDER_READY':
      return 'Food is ready';
    default:
      return 'Notification';
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}
