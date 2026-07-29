import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/auth_storage.dart';
import '../../auth/login_screen.dart';
import '../change_password_screen.dart';
import '../edit_profile_screen.dart';
import '../upload_avatar_screen.dart';
import '../../rating/rating_list_screen.dart';
import '../../states/ui_states_screen.dart';
import 'profile_menu_option.dart';

class ProfileActionsList extends StatelessWidget {
  const ProfileActionsList({super.key});

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
        letterSpacing: -0.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Profile Settings'),
        const SizedBox(height: 12),
        ProfileMenuOption(
          icon: Icons.person_outline_rounded,
          iconColor: const Color(0xFFF97316),
          title: 'Edit Profile',
          onTap: () =>
              Navigator.pushNamed(context, EditProfileScreen.routeName),
        ),
        ProfileMenuOption(
          icon: Icons.camera_alt_outlined,
          iconColor: const Color(0xFF3B82F6),
          title: 'Upload Avatar',
          onTap: () =>
              Navigator.pushNamed(context, UploadAvatarScreen.routeName),
        ),
        ProfileMenuOption(
          icon: Icons.lock_outline_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'Change Password',
          onTap: () =>
              Navigator.pushNamed(context, ChangePasswordScreen.routeName),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('My Activity'),
        const SizedBox(height: 12),
        ProfileMenuOption(
          icon: Icons.star_border_rounded,
          iconColor: const Color(0xFFF97316),
          title: 'My Ratings',
          onTap: () => Navigator.pushNamed(context, RatingListScreen.routeName),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('App Utilities'),
        const SizedBox(height: 12),
        ProfileMenuOption(
          icon: Icons.code_rounded,
          iconColor: const Color(0xFF3B82F6),
          title: 'UI States Screen',
          onTap: () => Navigator.pushNamed(context, UiStatesScreen.routeName),
        ),
        ProfileMenuOption(
          icon: Icons.logout_rounded,
          iconColor: AppColors.error,
          title: 'Logout',
          danger: true,
          onTap: () => _showLogout(context),
        ),
        const SizedBox(height: 40),
      ],
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
