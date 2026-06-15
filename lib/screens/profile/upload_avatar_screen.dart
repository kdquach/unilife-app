import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';
import '../../services/profile_provider.dart';
import '../../widgets/app_button.dart';
import 'upload_avatar_notifier.dart';

class UploadAvatarScreen extends ConsumerWidget {
  static const String routeName = '/upload-avatar';

  const UploadAvatarScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final uploadState = ref.watch(uploadAvatarProvider);
    final isLoading = uploadState.uploadStatus.isLoading;
    final errorMessage = uploadState.uploadStatus.whenOrNull(error: (err, _) => err.toString());

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

    // Image provider logic
    final ImageProvider? imageProvider;
    if (uploadState.pickedImagePath != null) {
      imageProvider = FileImage(File(uploadState.pickedImagePath!));
    } else if (fullAvatarUrl != null) {
      imageProvider = NetworkImage(fullAvatarUrl);
    } else {
      imageProvider = null;
    }

    Future<void> handleUpload() async {
      final success = await ref.read(uploadAvatarProvider.notifier).uploadAvatar();
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Avatar updated successfully!'),
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

    final isPermanentDenial = errorMessage == 'camera_permanently_denied' || errorMessage == 'photos_permanently_denied';
    final userFriendlyError = errorMessage == 'camera_permanently_denied'
        ? 'Camera permission has been permanently denied. Please enable Camera permission in Settings to take a photo.'
        : errorMessage == 'photos_permanently_denied'
            ? 'Photo library permission has been permanently denied. Please enable Photo library permission in Settings to select a photo.'
            : errorMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Avatar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose a profile photo',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.subText, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 36),

              // Error feedback (if any)
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              userFriendlyError ?? '',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isPermanentDenial) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => openAppSettings(),
                          icon: const Icon(Icons.settings_rounded, size: 18),
                          label: const Text('Open Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Interactive Preview Avatar
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: AppColors.primarySoft,
                        child: imageProvider == null
                            ? Text(
                                _getInitials(profile?.fullName ?? ''),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              )
                            : ClipOval(
                                child: Image(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                  width: 160,
                                  height: 160,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        _getInitials(profile?.fullName ?? ''),
                                        style: const TextStyle(
                                          fontSize: 48,
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
                    if (uploadState.pickedImagePath != null)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: isLoading ? null : () => ref.read(uploadAvatarProvider.notifier).clearPickedImage(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Picking controls
              AppButton(
                label: 'Choose from Gallery',
                secondary: true,
                onPressed: isLoading
                    ? null
                    : () => ref.read(uploadAvatarProvider.notifier).pickImage(ImageSource.gallery),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Take Photo',
                secondary: true,
                onPressed: isLoading
                    ? null
                    : () => ref.read(uploadAvatarProvider.notifier).pickImage(ImageSource.camera),
              ),
              
              const Spacer(),

              // Submit button
              AppButton(
                label: isLoading ? 'Uploading...' : 'Upload Avatar',
                onPressed: (uploadState.pickedImagePath == null || isLoading) ? null : handleUpload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
