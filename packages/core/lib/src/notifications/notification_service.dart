import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../api/api_client.dart';

/// Types of in-app notifications
enum AppNotificationType { info, success, warning, error, sync }

/// An in-app notification (DB-backed)
class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final String category;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = AppNotificationType.info,
    this.category = 'general',
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  AppNotification markAsRead() => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        category: category,
        createdAt: createdAt,
        read: true,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _parseType(json['type'] as String? ?? 'info'),
      category: json['category'] as String? ?? 'general',
      createdAt: DateTime.parse(json['created_at'] as String),
      read: json['is_read'] as bool? ?? false,
    );
  }

  static AppNotificationType _parseType(String type) {
    switch (type) {
      case 'success':
        return AppNotificationType.success;
      case 'warning':
        return AppNotificationType.warning;
      case 'error':
        return AppNotificationType.error;
      case 'sync':
        return AppNotificationType.sync;
      default:
        return AppNotificationType.info;
    }
  }
}

/// Notification service — supports both in-memory and DB-backed notifications.
class NotificationService {
  static final _ctrl = StreamController<AppNotification>.broadcast();
  static final _notifications = <AppNotification>[];
  static final _uuid = const Uuid();
  static ApiClient? _api;

  static int _pageSize = 50;
  static int _currentPage = 0;
  static bool _hasMore = true;

  /// Stream of new notifications
  static Stream<AppNotification> get stream => _ctrl.stream;

  /// All loaded notifications (most recent first)
  static List<AppNotification> get all =>
      List.unmodifiable(_notifications.reversed);

  /// Unread count
  static int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Whether there are more notifications to load
  static bool get hasMore => _hasMore;

  /// Initialize with API client for DB persistence
  static void init(ApiClient api) {
    _api = api;
  }

  /// Push a new notification (in-memory + optional DB write)
  static void push(
    String title,
    String body, {
    AppNotificationType type = AppNotificationType.info,
    String category = 'general',
    String? recipientId,
  }) {
    final notification = AppNotification(
      id: _uuid.v4(),
      title: title,
      body: body,
      type: type,
      category: category,
    );
    _notifications.add(notification);
    _ctrl.add(notification);

    // Persist to DB if recipient is specified and API is available
    if (recipientId != null && _api != null) {
      _persistNotification(notification, recipientId).catchError((e) {
        if (kDebugMode) print('Failed to persist notification: $e');
      });
    }
  }

  /// Load notifications from DB
  static Future<void> loadFromDB({bool refresh = false}) async {
    if (_api == null) return;

    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _notifications.clear();
    }

    try {
      final results = await _api!.select(
        'notifications',
        orderBy: 'created_at',
        ascending: false,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      final loaded =
          results.map((j) => AppNotification.fromJson(j)).toList();

      if (loaded.length < _pageSize) _hasMore = false;
      _notifications.addAll(loaded);
      _currentPage++;
    } catch (e) {
      if (kDebugMode) print('Failed to load notifications from DB: $e');
    }
  }

  /// Mark a notification as read (local + DB)
  static Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].markAsRead();
    }

    if (_api != null) {
      try {
        await _api!.update(
          'notifications',
          {'is_read': true, 'read_at': DateTime.now().toIso8601String()},
          filters: {'id': id},
        );
      } catch (e) {
        if (kDebugMode) print('Failed to mark notification as read in DB: $e');
      }
    }
  }

  /// Mark all as read (local + DB)
  static Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].read) {
        _notifications[i] = _notifications[i].markAsRead();
      }
    }

    if (_api != null) {
      try {
        // Batch update via Edge Function or individual updates
        for (final n in _notifications.where((n) => n.read)) {
          await _api!.update(
            'notifications',
            {'is_read': true, 'read_at': DateTime.now().toIso8601String()},
            filters: {'id': n.id},
          );
        }
      } catch (e) {
        if (kDebugMode) print('Failed to mark all as read in DB: $e');
      }
    }
  }

  /// Clear all notifications
  static void clear() => _notifications.clear();

  /// Dispose resources
  static void dispose() => _ctrl.close();

  // ---- Private ----

  static Future<void> _persistNotification(
    AppNotification notification,
    String recipientId,
  ) async {
    if (_api == null) return;
    await _api!.insert('notifications', {
      'id': notification.id,
      'recipient_id': recipientId,
      'title': notification.title,
      'body': notification.body,
      'type': notification.type.name,
      'category': notification.category,
      'is_read': false,
    });
  }
}
