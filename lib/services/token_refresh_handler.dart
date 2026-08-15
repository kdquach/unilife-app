import 'auth_storage.dart';
import 'auth_service.dart';
import 'api_client.dart';

class TokenRefreshHandler {
  static bool _isRefreshing = false;
  static bool _shouldRetry = false;

  static Future<bool> handleTokenRefresh(
    int statusCode,
    String? errorMessage,
  ) async {
    // Only handle 401 with token-related error messages
    if (statusCode != 401) return false;
    
    if (errorMessage != null &&
        (errorMessage.contains('token') ||
         errorMessage.contains('Token') ||
         errorMessage.contains('expired') ||
         errorMessage.contains('Expired'))) {
      
      if (_isRefreshing) {
        // If already refreshing, wait and retry
        _shouldRetry = true;
        return false;
      }

      _isRefreshing = true;
      _shouldRetry = false;

      try {
        final refreshToken = await AuthStorage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          // No refresh token, clear access token
          await AuthStorage.clearToken();
          return false;
        }

        // Try to refresh token
        final apiClient = ApiClient();
        final authService = AuthService(apiClient);
        final response = await authService.refreshToken(
          refreshToken: refreshToken,
        );

        if (response['success'] == true) {
          // Save new access token
          final newAccessToken = response['accessToken'] ?? response['token'];
          if (newAccessToken != null) {
            await AuthStorage.saveToken(newAccessToken);
            return true; // Retry the original request
          }
        }
      } catch (e) {
        // Refresh failed, clear tokens
        await AuthStorage.clearToken();
      } finally {
        _isRefreshing = false;
        if (_shouldRetry) {
          _shouldRetry = false;
          // If there were pending requests, they should retry now
        }
      }
    }

    return false;
  }
}
