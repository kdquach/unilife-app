import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/profile_provider.dart';
import '../../widgets/app_button.dart';
import 'edit_profile_notifier.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  static const String routeName = '/edit-profile';

  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).value;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
  }

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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    
    final success = await ref.read(editProfileProvider.notifier).updateProfile(
      fullName: _nameController.text,
      phone: _phoneController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final editState = ref.watch(editProfileProvider);
    final isLoading = editState.isLoading;
    final errorMessage = editState.whenOrNull(error: (err, _) => err.toString());

    // Resolve current network avatar URL
    final avatarUrl = profile?.avatarUrl;
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header graphic block
                Center(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primarySoft,
                          child: fullAvatarUrl == null
                              ? Text(
                                  _getInitials(profile?.fullName ?? ''),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                )
                              : ClipOval(
                                  child: Image.network(
                                    fullAvatarUrl,
                                    fit: BoxFit.cover,
                                    width: 92,
                                    height: 92,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          _getInitials(profile?.fullName ?? ''),
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Update your account information',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.subText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message box (if any)
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Input card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      const Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppColors.subText),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Phone
                      const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        enabled: !isLoading,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onSubmit(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Enter phone number',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppColors.subText),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email (Read-Only)
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: profile?.email ?? 'customer1@unilife.local',
                        enabled: false, // Disabled
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.subText),
                        decoration: const InputDecoration(
                          fillColor: AppColors.muted,
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.subText),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Note info box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primarySoft),
                  ),
                  child: const Text(
                    'Email is used for login and OTP verification and cannot be changed.',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                AppButton(
                  label: isLoading ? 'Saving Changes...' : 'Save Changes',
                  onPressed: isLoading ? null : _onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
