import '../models/user_notification.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationListResult> getMine({
    String? token,
    int page = 1,
    int limit = 50,
    bool? isRead,
    String? type,
    String? keyword,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (isRead != null) 'isRead': isRead.toString(),
      if (type != null && type.isNotEmpty) 'type': type,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
    };
    final path = Uri(
      path: '/user-notifications/me',
      queryParameters: queryParameters,
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return NotificationListResult.fromJson(response);
  }

  Future<UserNotification> getMineById(
    String id, {
    String? token,
    bool markAsRead = true,
  }) async {
    final path = Uri(
      path: '/user-notifications/me/$id',
      queryParameters: {'markAsRead': markAsRead.toString()},
    ).toString();
    final response = await _apiClient.getJson(path, token: token);
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return UserNotification.fromJson(data);
    }
    return UserNotification.fromJson(response);
  }
}
