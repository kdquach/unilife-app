import 'api_client.dart';

class AuthService {
  AuthService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login({required String email, required String password}) {
    return _apiClient.postJson('/auth/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register({required String fullName, required String email, required String phone, required String password}) {
    return _apiClient.postJson('/auth/register', {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> forgotPassword(String email) {
    return _apiClient.postJson('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword({required String email, required String otp, required String newPassword}) {
    return _apiClient.postJson('/auth/reset-password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }
}
