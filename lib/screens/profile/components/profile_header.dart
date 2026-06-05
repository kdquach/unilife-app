import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_profile.dart';
import '../../../services/api_client.dart';

class ProfileHeader extends StatelessWidget {
  final UserProfile profile;

  const ProfileHeader({super.key, required this.profile});

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.last.isNotEmpty ? parts.last[0] : '';
      return (first + last).toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    final String? fullAvatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http')) {
        fullAvatarUrl = avatarUrl;
      } else {
        final uri = Uri.parse(ApiClient.baseUrl);
        final host = '${uri.scheme}://${uri.authority}';
        fullAvatarUrl = '$host$avatarUrl';
      }
    } else {
      fullAvatarUrl = null;
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Background Banner
        Container(
          height: 140,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
        ),
        // Avatar positioned overlapping the banner bottom
        Positioned(
          top: 80,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 56,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
              child: fullAvatarUrl == null
                  ? Text(
                      _getInitials(profile.fullName),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
