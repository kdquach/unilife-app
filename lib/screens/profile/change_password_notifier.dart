import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/auth_storage.dart';

class ChangePasswordNotifier extends AsyncNotifier<void> {
  final _authService = AuthService(ApiClient());

  @override
  Future<void> build() async {
    // Return void for idle state
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // 1. Client-side validation
    if (currentPassword.isEmpty) {
      state = AsyncValue.error('Current password is required', StackTrace.current);
      return false;
    }
    if (newPassword.isEmpty) {
      state = AsyncValue.error('New password is required', StackTrace.current);
      return false;
    }
    if (newPassword.length < 8) {
      state = AsyncValue.error('New password must be at least 8 characters long', StackTrace.current);
      return false;
    }
    if (newPassword == currentPassword) {
      state = AsyncValue.error('New password must be different from current password', StackTrace.current);
      return false;
    }
    if (newPassword != confirmPassword) {
      state = AsyncValue.error('Confirm password does not match new password', StackTrace.current);
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
      state = AsyncValue.error(error.message, StackTrace.current);
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
