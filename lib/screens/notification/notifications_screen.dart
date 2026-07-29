import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_notification.dart';
import '../../services/api_client.dart';
import '../../services/auth_storage.dart';
import '../../services/notification_service.dart';
import '../../services/notification_socket_service.dart';
import '../../widgets/app_card.dart';
import '../auth/login_screen.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  static const String routeName = '/notifications';

  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService =
      NotificationService(ApiClient());
  final NotificationSocketService _socketService = NotificationSocketService();

  StreamSubscription<UserNotification>? _socketSubscription;
  List<UserNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  bool _requiresLogin = false;
  String? _token;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final token = await AuthStorage.getToken();
    if (!mounted) return;
    setState(() => _token = token);

    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _requiresLogin = true;
        _error = null;
      });
      return;
    }

    await _loadNotifications();
    _socketSubscription = _socketService.notifications.listen(_handleRealtime);
    _socketService.connect(token);
  }

  Future<void> _loadNotifications() async {
    if (_token == null || _token!.isEmpty) return;
    setState(() {
      _isLoading = true;
      _requiresLogin = false;
      _error = null;
    });

    try {
      final result = await _notificationService.getMine(token: _token);
      if (!mounted) return;
      setState(() {
        _notifications = result.items;
        _unreadCount = result.unreadCount;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await AuthStorage.clearToken();
        setState(() {
          _token = null;
          _notifications = [];
          _unreadCount = 0;
          _requiresLogin = true;
          _isLoading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  void _handleRealtime(UserNotification notification) {
    if (!mounted) return;
    setState(() {
      final existingIndex =
          _notifications.indexWhere((item) => item.id == notification.id);
      if (existingIndex >= 0) {
        _notifications[existingIndex] = notification;
      } else {
        _notifications = [notification, ..._notifications];
      }
      _unreadCount = _notifications.where((item) => !item.isRead).length;
    });
  }

  Future<void> _openDetail(UserNotification notification) async {
    await Navigator.pushNamed(
      context,
      NotificationDetailScreen.routeName,
      arguments: notification,
    );
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('$_unreadCount unread'),
                backgroundColor: AppColors.primarySoft,
                labelStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requiresLogin) {
      return _NotificationMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Please log in to view notifications.',
        actionLabel: 'Login',
        onAction: () => Navigator.pushNamed(context, LoginScreen.routeName),
      );
    }

    if (_error != null) {
      return _NotificationMessage(
        icon: Icons.notifications_off_outlined,
        title: _error!,
        actionLabel: 'Try again',
        onAction: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return _NotificationMessage(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet.',
        actionLabel: 'Refresh',
        onAction: _loadNotifications,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationTile(
            notification: notification,
            onTap: () => _openDetail(notification),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notification.body,
            style: const TextStyle(color: AppColors.subText, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDate(notification.createdAt),
            style: const TextStyle(
              color: AppColors.subText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.subText),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}
