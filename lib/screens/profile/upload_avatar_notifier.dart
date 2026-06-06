import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../services/profile_provider.dart';

class UploadAvatarState {
  final String? pickedImagePath;
  final AsyncValue<void> uploadStatus;

  UploadAvatarState({
    this.pickedImagePath,
    this.uploadStatus = const AsyncData(null),
  });

  UploadAvatarState copyWith({
    String? pickedImagePath,
    AsyncValue<void>? uploadStatus,
    bool clearPickedImage = false,
  }) {
    return UploadAvatarState(
      pickedImagePath: clearPickedImage ? null : (pickedImagePath ?? this.pickedImagePath),
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }
}

class UploadAvatarNotifier extends Notifier<UploadAvatarState> {
  final _authService = AuthService(ApiClient());
  final _picker = ImagePicker();

  @override
  UploadAvatarState build() {
    return UploadAvatarState();
  }

  Future<void> pickImage(ImageSource source) async {
    // Reset status/error immediately on click so UI resets and visual feedback is triggered
    state = state.copyWith(uploadStatus: const AsyncData(null));

    // Request camera permission explicitly using permission_handler
    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isPermanentlyDenied) {
        state = state.copyWith(
          uploadStatus: AsyncValue.error('camera_permanently_denied', StackTrace.current),
        );
        return;
      }
      if (cameraStatus.isDenied) {
        state = state.copyWith(
          uploadStatus: AsyncValue.error(
            'Camera access denied. Please enable camera permission in your device settings to take a photo.',
            StackTrace.current,
          ),
        );
        return;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        state = state.copyWith(
          pickedImagePath: image.path,
        );
      }
    } on PlatformException catch (e) {
      String message = 'Failed to pick image: ${e.message}';
      if (e.code == 'camera_access_denied') {
        message = 'camera_permanently_denied';
      } else if (e.code == 'photo_access_denied') {
        message = 'photos_permanently_denied';
      }
      state = state.copyWith(
        uploadStatus: AsyncValue.error(message, StackTrace.current),
      );
    } catch (e) {
      state = state.copyWith(
        uploadStatus: AsyncValue.error('Failed to pick image: $e', StackTrace.current),
      );
    }
  }

  void clearPickedImage() {
    state = state.copyWith(clearPickedImage: true);
  }

  Future<bool> uploadAvatar() async {
    final path = state.pickedImagePath;
    if (path == null) {
      state = state.copyWith(
        uploadStatus: AsyncValue.error('Please select an image first.', StackTrace.current),
      );
      return false;
    }

    state = state.copyWith(uploadStatus: const AsyncValue.loading());

    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw ApiException(
          statusCode: 401,
          message: 'No access token found. Please login again.',
        );
      }

      final response = await _authService.uploadAvatar(
        filePath: path,
        token: token,
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final profile = UserProfile.fromJson(data);
        ref.read(profileProvider.notifier).updateProfile(profile);

        state = state.copyWith(
          uploadStatus: const AsyncValue.data(null),
          clearPickedImage: true,
        );
        return true;
      } else {
        throw ApiException(
          statusCode: 400,
          message: response['message']?.toString() ?? 'Failed to upload avatar',
        );
      }
    } on ApiException catch (error) {
      state = state.copyWith(
        uploadStatus: AsyncValue.error(error.message, StackTrace.current),
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        uploadStatus: AsyncValue.error(error.toString(), StackTrace.current),
      );
      return false;
    }
  }
}

final uploadAvatarProvider =
    NotifierProvider<UploadAvatarNotifier, UploadAvatarState>(() {
  return UploadAvatarNotifier();
});
