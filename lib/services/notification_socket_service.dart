import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/user_notification.dart';
import 'api_client.dart';

class NotificationSocketService {
  io.Socket? _socket;
  final StreamController<UserNotification> _notificationController =
      StreamController<UserNotification>.broadcast();

  Stream<UserNotification> get notifications => _notificationController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (token.isEmpty) return;
    if (_socket != null) {
      if (_socket!.connected) return;
      _socket!.connect();
      return;
    }

    _socket = io.io(
      _socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setQuery({'token': token})
          .build(),
    );

    _socket!
      ..on('notification:new', _handleNotification)
      ..on('connect_error', (_) {})
      ..connect();
  }

  void _handleNotification(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      _notificationController.add(UserNotification.fromJson(payload));
      return;
    }
    if (payload is Map) {
      _notificationController.add(
        UserNotification.fromJson(Map<String, dynamic>.from(payload)),
      );
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }

  String get _socketBaseUrl {
    return ApiClient.baseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  }
}
