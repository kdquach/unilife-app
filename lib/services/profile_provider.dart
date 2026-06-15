import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'auth_storage.dart';

class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  final _authService = AuthService(ApiClient());

  @override
  Future<UserProfile?> build() async {
    return _fetchProfile();
  }

  Future<UserProfile?> _fetchProfile() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception('No access token found. Please login again.');
    }
    final response = await _authService.getProfile(token: token);
    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } else {
      throw ApiException(
        statusCode: 400,
        message: response['message']?.toString() ?? 'Failed to load profile',
      );
    }
  }

  Future<void> refreshProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchProfile());
  }

  void updateProfile(UserProfile profile) {
    state = AsyncValue.data(profile);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile?>(() {
  return ProfileNotifier();
});
