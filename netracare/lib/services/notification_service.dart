import 'dart:async';
import 'doctor_api_service.dart';

/// Model for a notification
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String message;
  final String? relatedType;
  final int? relatedId;
  final bool isRead;
  final String priority;
  final DateTime createdAt;
  final String timeAgo;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.relatedType,
    this.relatedId,
    required this.isRead,
    required this.priority,
    required this.createdAt,
    required this.timeAgo,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      relatedType: json['related_type'] as String?,
      relatedId: json['related_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'normal',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      timeAgo: json['time_ago'] as String? ?? '',
    );
  }

  /// Check if this is a high priority notification
  bool get isHighPriority => priority == 'high' || priority == 'urgent';

  /// Get icon for notification type
  String get icon {
    switch (type) {
      case 'consultation_request':
        return '📋';
      case 'consultation_scheduled':
        return '📅';
      case 'new_message':
        return '💬';
      case 'test_shared':
        return '🔬';
      default:
        return '🔔';
    }
  }
}

/// Enum to identify the current user role for notification routing
enum NotificationRole { user, doctor }

/// Service to manage user notifications
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Stream controller for real-time updates
  final _notificationController =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get notificationStream =>
      _notificationController.stream;

  // Cached data
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  Timer? _pollTimer;

  // Role awareness — determines which endpoints to call
  NotificationRole _role = NotificationRole.user;

  /// Get all notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  /// Get unread count
  int get unreadCount => _unreadCount;

  /// Get current role
  NotificationRole get role => _role;

  /// Set the role for notification routing (call before initialize)
  void setRole(NotificationRole role) {
    _role = role;
  }

  bool get _isDoctor => _role == NotificationRole.doctor;

  /// Initialize and start polling
  void initialize() {
    // Initial fetch
    fetchNotifications();

    // Poll every 30 seconds for new notifications
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => fetchNotifications(),
    );
  }

  /// Fetch notifications from API (routes to user or doctor endpoint based on role)
  Future<List<AppNotification>> fetchNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final data = _isDoctor
          ? await DoctorApiService.getDoctorNotifications(
              unreadOnly: unreadOnly,
            )
          : await DoctorApiService.getUserNotifications(unreadOnly: unreadOnly);

      _notifications = data.map((n) => AppNotification.fromJson(n)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      _notificationController.add(_notifications);

      return _notifications;
    } catch (e) {
      return _notifications;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      _unreadCount = _isDoctor
          ? await DoctorApiService.getDoctorUnreadNotificationCount()
          : await DoctorApiService.getUnreadNotificationCount();
      return _unreadCount;
    } catch (e) {
      return _unreadCount;
    }
  }

  /// Alias for getUnreadCount - async version
  Future<int> getUnreadCountAsync() async {
    return getUnreadCount();
  }

  /// Mark a notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      final success = _isDoctor
          ? await DoctorApiService.markDoctorNotificationRead(notificationId)
          : await DoctorApiService.markNotificationRead(notificationId);

      if (success) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].isRead) {
          _unreadCount--;
        }
        // Refresh the list
        await fetchNotifications();
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final success = _isDoctor
          ? await DoctorApiService.markAllDoctorNotificationsRead()
          : await DoctorApiService.markAllNotificationsRead();

      if (success) {
        _unreadCount = 0;
        await fetchNotifications();
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    try {
      final success = _isDoctor
          ? await DoctorApiService.deleteDoctorNotification(notificationId)
          : await DoctorApiService.deleteNotification(notificationId);

      if (success) {
        _notifications.removeWhere((n) => n.id == notificationId);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        _notificationController.add(_notifications);
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Handle notification tap - navigate to related content
  Map<String, dynamic>? getNavigationData(AppNotification notification) {
    switch (notification.type) {
      case 'consultation_request':
      case 'consultation_scheduled':
      case 'new_message':
        if (notification.relatedId != null) {
          return {
            'route': '/consultation-detail',
            'args': {'consultationId': notification.relatedId},
          };
        }
        break;
      case 'test_shared':
        return {'route': '/test-results', 'args': null};
    }
    return null;
  }

  /// Clear all cached notifications
  void clear() {
    _notifications.clear();
    _unreadCount = 0;
    _pollTimer?.cancel();
    _notificationController.add([]);
  }

  /// Dispose resources
  void dispose() {
    _pollTimer?.cancel();
    _notificationController.close();
  }
}
