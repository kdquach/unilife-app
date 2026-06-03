import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/app_card.dart';
import '../auth/login_screen.dart';
import '../rating/rating_list_screen.dart';
import '../states/ui_states_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'upload_avatar_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Profile',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Manage your account',
              style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 28),
          Center(
            child: CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.primarySoft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(AppAssets.logoMd, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Nguyen Khanh Duy',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('customer1@unilife.local',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subText)),
          const SizedBox(height: 30),
          _ProfileRow(
              title: 'Edit profile',
              onTap: () =>
                  Navigator.pushNamed(context, EditProfileScreen.routeName)),
          _ProfileRow(
              title: 'Upload avatar',
              onTap: () =>
                  Navigator.pushNamed(context, UploadAvatarScreen.routeName)),
          _ProfileRow(
              title: 'Change password',
              onTap: () =>
                  Navigator.pushNamed(context, ChangePasswordScreen.routeName)),
          _ProfileRow(
              title: 'My ratings',
              onTap: () =>
                  Navigator.pushNamed(context, RatingListScreen.routeName)),
          _ProfileRow(
              title: 'UI states',
              onTap: () =>
                  Navigator.pushNamed(context, UiStatesScreen.routeName)),
          _ProfileRow(
              title: 'Logout', danger: true, onTap: () => _showLogout(context)),
        ],
      ),
    );
  }

  void _showLogout(BuildContext context) {
    final authService = AuthService(ApiClient());
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        bool isLoading = false;
        String? errorMessage;

        Future<void> handleLogout(StateSetter setState) async {
          setState(() {
            isLoading = true;
            errorMessage = null;
          });

          final token = await AuthStorage.getToken();
          if (token != null) {
            try {
              await authService.logout(token: token);
            } on ApiException catch (error) {
              setState(() {
                isLoading = false;
                errorMessage = error.message;
              });
              return;
            } catch (_) {
              setState(() {
                isLoading = false;
                errorMessage = 'Logout failed. Please try again.';
              });
              return;
            }
          }

          await AuthStorage.clearToken();
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
              context, LoginScreen.routeName, (_) => false);
        }

        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Logout?',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text(
                    'You will need to login again to place orders and view your profile.',
                    style: TextStyle(color: AppColors.subText)),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage!,
                      style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Stay'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        onPressed:
                            isLoading ? null : () => handleLogout(setState),
                        child: Text(isLoading ? 'Logging out...' : 'Logout'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String title;
  final bool danger;
  final VoidCallback onTap;

  const _ProfileRow(
      {required this.title, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: danger ? AppColors.error : AppColors.text,
                        fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.subText),
          ],
        ),
      ),
    );
  }
}
