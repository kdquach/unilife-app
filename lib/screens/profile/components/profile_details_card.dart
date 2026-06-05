import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/app_card.dart';
import 'profile_detail_item.dart';

class ProfileDetailsCard extends StatelessWidget {
  final UserProfile profile;

  const ProfileDetailsCard({super.key, required this.profile});

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        children: [
          ProfileDetailItem(
            icon: Icons.phone_android_rounded,
            iconColor: Colors.blue,
            label: 'Phone number',
            value: profile.phone ?? 'Not set',
          ),
          const Divider(height: 28, color: AppColors.border),
          ProfileDetailItem(
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.success,
            label: 'Account Status',
            value: profile.isActive ? 'Active' : 'Inactive',
            valueColor: profile.isActive ? AppColors.success : AppColors.error,
          ),
          const Divider(height: 28, color: AppColors.border),
          ProfileDetailItem(
            icon: Icons.calendar_today_rounded,
            iconColor: Colors.purple,
            label: 'Member Since',
            value: _formatDate(profile.createdAt),
          ),
        ],
      ),
    );
  }
}
