import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';

class ChangePasswordNotifier extends AsyncNotifier<void> {
  final _authService = AuthService(ApiClient());
  Map<String, String?> _fieldErrors = {
    'currentPassword': null,
    'newPassword': null,
  };

  Map<String, String?> get fieldErrors => _fieldErrors;

  @override
  FutureOr<void> build() {
    // Return void synchronously for idle state
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // Clear field errors
    _fieldErrors = {
      'currentPassword': null,
      'newPassword': null,
    };

    // 1. Client-side validation
    if (currentPassword.isEmpty) {
      _fieldErrors['currentPassword'] = 'Current password is required';
      state = const AsyncValue.data(null);
      return false;
    }
    if (newPassword.isEmpty) {
      _fieldErrors['newPassword'] = 'New password is required';
      state = const AsyncValue.data(null);
      return false;
    }
    if (newPassword.length < 8) {
      _fieldErrors['newPassword'] = 'New password must be at least 8 characters long';
      state = const AsyncValue.data(null);
      return false;
    }
    if (newPassword.contains(' ')) {
      _fieldErrors['newPassword'] = 'New password must not contain spaces';
      state = const AsyncValue.data(null);
      return false;
    }
    if (!newPassword.contains(RegExp(r'[a-z]'))) {
      _fieldErrors['newPassword'] = 'New password must contain at least one lowercase letter';
      state = const AsyncValue.data(null);
      return false;
    }
    if (!newPassword.contains(RegExp(r'[A-Z]'))) {
      _fieldErrors['newPassword'] = 'New password must contain at least one uppercase letter';
      state = const AsyncValue.data(null);
      return false;
    }
    if (!newPassword.contains(RegExp(r'[0-9]'))) {
      _fieldErrors['newPassword'] = 'New password must contain at least one number';
      state = const AsyncValue.data(null);
      return false;
    }
    if (!newPassword.contains(RegExp(r'[^A-Za-z0-9]'))) {
      _fieldErrors['newPassword'] = 'New password must contain at least one special character';
      state = const AsyncValue.data(null);
      return false;
    }
    if (newPassword == currentPassword) {
      _fieldErrors['newPassword'] = 'New password must be different from current password';
      state = const AsyncValue.data(null);
      return false;
    }
    if (newPassword != confirmPassword) {
      _fieldErrors['newPassword'] = 'Confirm password does not match new password';
      state = const AsyncValue.data(null);
      return false;
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

      final response = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        token: token,
      );

      if (response['success'] == true) {
        state = const AsyncValue.data(null);
        return true;
      } else {
        throw ApiException(
          statusCode: 400,
          message: response['message']?.toString() ?? 'Failed to change password',
        );
      }
    } on ApiException catch (error) {
      // Parse field errors from backend response
      if (error.errors != null && error.errors is Map<String, dynamic>) {
        final errors = error.errors as Map<String, dynamic>;
        if (errors['currentPassword'] != null) {
          _fieldErrors['currentPassword'] = errors['currentPassword'].toString();
        }
        if (errors['newPassword'] != null) {
          _fieldErrors['newPassword'] = errors['newPassword'].toString();
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

final changePasswordProvider =
    AsyncNotifierProvider<ChangePasswordNotifier, void>(() {
  return ChangePasswordNotifier();
});
