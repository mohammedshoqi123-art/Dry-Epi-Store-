import 'dart:async';
import 'package:uuid/uuid.dart';

/// Types of in-app notifications
enum AppNotificationType { info, success, warning, error, sync }

/// An in-app notification
class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = AppNotificationType.info,
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  AppNotification markAsRead() => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: true,
      );
}

/// Internal notification service for in-app alerts.
/// Push notifications (FCM) can be layered on top later.
class NotificationService {
  static final _ctrl = StreamController<AppNotification>.broadcast();
  static final _notifications = <AppNotification>[];
  static final _uuid = const Uuid();

  /// Stream of new notifications
  static Stream<AppNotification> get stream => _ctrl.stream;

  /// All notifications (most recent first)
  static List<AppNotification> get all =>
      List.unmodifiable(_notifications.reversed);

  /// Unread count
  static int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Push a new notification
  static void push(
    String title,
    String body, {
    AppNotificationType type = AppNotificationType.info,
  }) {
    final notification = AppNotification(
      id: _uuid.v4(),
      title: title,
      body: body,
      type: type,
    );
    _notifications.add(notification);
    _ctrl.add(notification);
  }

  /// Mark a notification as read
  static void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].markAsRead();
    }
  }

  /// Mark all as read
  static void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].markAsRead();
    }
  }

  /// Clear all notifications
  static void clear() => _notifications.clear();

  /// Dispose resources
  static void dispose() => _ctrl.close();
}
