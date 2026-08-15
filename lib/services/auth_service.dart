import 'api_client.dart';
import 'auth_storage.dart';

class AuthService {
  AuthService(this._apiClient);

  final ApiClient _apiClient;

  static Future<void> saveAuthTokens(Map<String, dynamic> response) async {
    final accessToken = AuthService.extractAccessToken(response);
    final refreshToken = response['refreshToken'] as String?;
    
    if (accessToken != null) {
      await AuthStorage.saveToken(accessToken);
    }
    if (refreshToken != null) {
      await AuthStorage.saveRefreshToken(refreshToken);
    }
  }

  Future<Map<String, dynamic>> login(
      {required String email, required String password}) {
    return _apiClient
        .postJson('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register(
      {required String fullName,
      required String email,
      required String phone,
      required String password}) {
    return _apiClient.postJson('/auth/register', {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> verifyRegisterOtp(
      {required String email, required String otp, bool rememberMe = true}) {
    return _apiClient.postJson('/auth/verify-register-otp', {
      'email': email,
      'otp': otp,
      'rememberMe': rememberMe,
    });
  }

  Future<Map<String, dynamic>> resendRegisterOtp(String email) {
    return _apiClient.postJson('/auth/resend-register-otp', {'email': email});
  }

  Future<Map<String, dynamic>> forgotPassword(String email) {
    return _apiClient.postJson('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> resendForgotPasswordOtp(String email) {
    return _apiClient
        .postJson('/auth/resend-forgot-password-otp', {'email': email});
  }

  Future<Map<String, dynamic>> refreshToken({required String refreshToken}) {
    return _apiClient.postJson('/auth/refresh-token', {'refreshToken': refreshToken});
  }

  Future<Map<String, dynamic>> resetPassword(
      {required String email,
      required String otp,
      required String newPassword}) {
    return _apiClient.postJson('/auth/reset-password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> logout({required String token}) {
    return _apiClient.postJson('/auth/logout', {}, token: token);
  }

  Future<Map<String, dynamic>> getProfile({required String token}) {
    return _apiClient.getJson('/users/profile', token: token);
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) {
    return _apiClient.patchJson(
      '/auth/change-password',
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> uploadAvatar({
    required String filePath,
    required String token,
  }) {
    return _apiClient.uploadFile(
      '/users/profile/avatar',
      'avatar',
      filePath,
      token: token,
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? phone,
    required String token,
  }) {
    return _apiClient.patchJson(
      '/users/profile',
      {
        'fullName': fullName,
        'phone': phone,
      },
      token: token,
    );
  }

  static String? extractAccessToken(Map<String, dynamic> response) {
    return _stringOrNull(response['accessToken']) ??
        _stringOrNull(response['token']) ??
        _stringOrNull(response['jwt']) ??
        _extractTokenFromData(response['data']);
  }

  static String? _extractTokenFromData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _stringOrNull(data['accessToken']) ??
          _stringOrNull(data['token']) ??
          _stringOrNull(data['jwt']) ??
          _stringOrNull(data['access_token']);
    }
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }
}
