import 'dart:async';

import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/notification_service.dart';
import 'package:netracare/widgets/notification/notification_item.dart';

/// User notification center (full screen) powered by NotificationService.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  late StreamSubscription<List<AppNotification>> _subscription;
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    // Ensure user role and start listening
    _service.setRole(NotificationRole.user);
    _notifications = _service.notifications;
    _subscription = _service.notificationStream.listen((list) {
      if (mounted) setState(() => _notifications = list);
    });
    _refresh();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.fetchNotifications(unreadOnly: _unreadOnly);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: Icon(
              Icons.mark_email_read_outlined,
              color: colors.textPrimary,
            ),
            onPressed: _notifications.isEmpty ? null : _markAllRead,
          ),
          IconButton(
            icon: Icon(
              _unreadOnly
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: colors.textPrimary,
            ),
            tooltip: _unreadOnly ? 'Show all' : 'Show unread only',
            onPressed: () {
              setState(() => _unreadOnly = !_unreadOnly);
              _refresh();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colors.textPrimary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _notifications.isEmpty
          ? Center(
              child: Text(
                'No notifications',
                style: TextStyle(color: colors.textPrimary),
              ),
            )
          : RefreshIndicator(
              color: colors.primary,
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = _notifications[i];
                  return NotificationItem(
                    notification: n,
                    onTap: () async {
                      await _service.markAsRead(n.id);
                      // Navigation handling can be added based on getNavigationData
                    },
                    onMarkRead: n.isRead
                        ? null
                        : () async {
                            await _service.markAsRead(n.id);
                          },
                    onDelete: () async {
                      await _service.deleteNotification(n.id);
                      setState(() {
                        _notifications = _service.notifications;
                      });
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildError() {
    final colors = context.appColors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.error),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Failed to load notifications',
            style: TextStyle(color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
