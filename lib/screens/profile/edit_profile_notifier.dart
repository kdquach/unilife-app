import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';
import '../../services/profile_provider.dart';

class EditProfileNotifier extends AsyncNotifier<void> {
  final _authService = AuthService(ApiClient());
  Map<String, String?> _fieldErrors = {
    'fullName': null,
    'phone': null,
  };

  Map<String, String?> get fieldErrors => _fieldErrors;

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

    // Clear field errors
    _fieldErrors = {
      'fullName': null,
      'phone': null,
    };

    // 1. Client-side validation
    if (trimmedName.isEmpty) {
      _fieldErrors['fullName'] = 'Full name cannot be empty';
      state = const AsyncValue.data(null);
      return false;
    }

    // Full name validation: at least 2 chars, no leading/trailing spaces, no consecutive spaces, must have first and last name
    if (trimmedName.length < 2) {
      _fieldErrors['fullName'] = 'Full name must be at least 2 characters';
      state = const AsyncValue.data(null);
      return false;
    }

    if (trimmedName != trimmedName.trim()) {
      _fieldErrors['fullName'] = 'Full name must not have leading or trailing spaces';
      state = const AsyncValue.data(null);
      return false;
    }

    if (RegExp(r'\s{2,}').hasMatch(trimmedName)) {
      _fieldErrors['fullName'] = 'Full name must not have consecutive spaces';
      state = const AsyncValue.data(null);
      return false;
    }

    // Check if name contains at least first and last name with letters only
    final nameParts = trimmedName.trim().split(RegExp(r'\s+'));
    if (nameParts.length < 2) {
      _fieldErrors['fullName'] = 'Full name must contain at least first name and last name';
      state = const AsyncValue.data(null);
      return false;
    }

    // Check if all parts contain only letters (including Vietnamese characters)
    for (final part in nameParts) {
      if (!RegExp(r'^[\p{L}]+$', unicode: true).hasMatch(part)) {
        _fieldErrors['fullName'] = 'Full name must contain only letters and spaces';
        state = const AsyncValue.data(null);
        return false;
      }
    }

    if (trimmedPhone.isNotEmpty) {
      // Phone validation: Vietnamese phone number format (10 digits starting with 03, 05, 07, 08, 09)
      if (!RegExp(r'^\d+$').hasMatch(trimmedPhone)) {
        _fieldErrors['phone'] = 'Phone must contain only numbers';
        state = const AsyncValue.data(null);
        return false;
      }

      if (trimmedPhone.length != 10) {
        _fieldErrors['phone'] = 'Phone must be exactly 10 digits';
        state = const AsyncValue.data(null);
        return false;
      }

      if (!RegExp(r'^(03|05|07|08|09)\d{8}$').hasMatch(trimmedPhone)) {
        _fieldErrors['phone'] = 'Phone must be a valid Vietnamese phone number';
        state = const AsyncValue.data(null);
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
      // Parse field errors from backend response
      if (error.errors != null && error.errors is Map<String, dynamic>) {
        final errors = error.errors as Map<String, dynamic>;
        if (errors['fullName'] != null) {
          _fieldErrors['fullName'] = errors['fullName'].toString();
        }
        if (errors['phone'] != null) {
          _fieldErrors['phone'] = errors['phone'].toString();
        }
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(error.message, StackTrace.current);
      }
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
