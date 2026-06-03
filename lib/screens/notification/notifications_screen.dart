import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_card.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  static const String routeName = '/notifications';

  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Updates about orders and menus', style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 20),
          _NotificationTile(title: 'Order is ready', body: 'Queue A12 can be picked up now.', unread: true, onTap: () => Navigator.pushNamed(context, NotificationDetailScreen.routeName)),
          const SizedBox(height: 14),
          const _NotificationTile(title: 'New weekly menu', body: 'This week menu has been published.', unread: true),
          const SizedBox(height: 14),
          const _NotificationTile(title: 'Payment confirmed', body: 'Sepay payment was verified.'),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String body;
  final bool unread;
  final VoidCallback? onTap;

  const _NotificationTile({required this.title, required this.body, this.unread = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(body, style: const TextStyle(color: AppColors.subText)),
              ],
            ),
          ),
          if (unread)
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
