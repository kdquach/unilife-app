class NotificationContent {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime? createdAt;

  const NotificationContent({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.createdAt,
  });

  factory NotificationContent.fromJson(Map<String, dynamic> json) {
    return NotificationContent(
      id: _readId(json),
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'GENERAL',
      createdAt: _parseDate(json['createdAt']),
    );
  }
}

class UserNotification {
  final String id;
  final String userId;
  final NotificationContent notification;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  const UserNotification({
    required this.id,
    required this.userId,
    required this.notification,
    required this.isRead,
    this.readAt,
    this.createdAt,
  });

  String get title => notification.title;
  String get body => notification.body;
  String get type => notification.type;

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    final rawNotification = json['notificationId'];
    final notificationJson = rawNotification is Map<String, dynamic>
        ? rawNotification
        : <String, dynamic>{
            '_id': rawNotification?.toString() ?? '',
            'title': json['title'],
            'body': json['body'],
            'type': json['type'],
            'createdAt': json['createdAt'],
          };

    return UserNotification(
      id: _readId(json),
      userId: json['userId']?.toString() ?? '',
      notification: NotificationContent.fromJson(notificationJson),
      isRead: json['isRead'] == true,
      readAt: _parseDate(json['readAt']),
      createdAt: _parseDate(json['createdAt']) ??
          NotificationContent.fromJson(notificationJson).createdAt,
    );
  }

  UserNotification copyWith({bool? isRead, DateTime? readAt}) {
    return UserNotification(
      id: id,
      userId: userId,
      notification: notification,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

class NotificationListResult {
  final List<UserNotification> items;
  final int unreadCount;
  final bool hasNotifications;
  final String emptyMessage;

  const NotificationListResult({
    required this.items,
    required this.unreadCount,
    required this.hasNotifications,
    required this.emptyMessage,
  });

  factory NotificationListResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(UserNotification.fromJson)
            .toList()
        : <UserNotification>[];

    return NotificationListResult(
      items: items,
      unreadCount: _parseInt(data['unreadCount']),
      hasNotifications: data['hasNotifications'] == true || items.isNotEmpty,
      emptyMessage: data['emptyMessage']?.toString() ?? 'No notifications yet.',
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _parseInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _readId(Map<String, dynamic> json) {
  return _scalarString(json['userNotificationId']) ??
      _scalarString(json['notificationId']) ??
      _scalarString(json['_id']) ??
      _scalarString(json['id']) ??
      '';
}

String? _scalarString(Object? value) {
  if (value == null || value is Map || value is List) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}
