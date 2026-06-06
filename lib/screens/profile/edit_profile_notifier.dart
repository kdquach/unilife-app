import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../services/profile_provider.dart';

class EditProfileNotifier extends AsyncNotifier<void> {
  final _authService = AuthService(ApiClient());

  @override
  FutureOr<void> build() {
    // Return void synchronously for idle state
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();

    // 1. Client-side validation
    if (trimmedName.isEmpty) {
      state = AsyncValue.error('Full name cannot be empty', StackTrace.current);
      return false;
    }

    if (trimmedPhone.isNotEmpty) {
      // Validate Vietnamese phone number format (supports 10-digit numbers starting with 03, 05, 07, 08, 09 or +84 format)
      final phoneRegex = RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$');
      if (!phoneRegex.hasMatch(trimmedPhone)) {
        state = AsyncValue.error('Invalid Vietnamese phone number format (e.g. 0912345678 or +84912345678)', StackTrace.current);
        return false;
      }
    }

    state = const AsyncValue.loading();

    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw ApiException(
          statusCode: 401,
          message: 'No access token found. Please login again.',
        );
      }

      final response = await _authService.updateProfile(
        fullName: trimmedName,
        phone: trimmedPhone.isEmpty ? null : trimmedPhone,
        token: token,
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final profile = UserProfile.fromJson(data);
        
        // Instantly update global profileProvider state
        ref.read(profileProvider.notifier).updateProfile(profile);

        state = const AsyncValue.data(null);
        return true;
      } else {
        throw ApiException(
          statusCode: 400,
          message: response['message']?.toString() ?? 'Failed to update profile',
        );
      }
    } on ApiException catch (error) {
      state = AsyncValue.error(error.message, StackTrace.current);
      return false;
    } catch (error) {
      state = AsyncValue.error(error.toString(), StackTrace.current);
      return false;
    }
  }
}

final editProfileProvider =
    AsyncNotifierProvider<EditProfileNotifier, void>(() {
  return EditProfileNotifier();
});
