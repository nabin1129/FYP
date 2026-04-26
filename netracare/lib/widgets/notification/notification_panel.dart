import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/notification_service.dart';
import 'notification_item.dart';

/// Dropdown panel that displays a live list of notifications.
/// Designed to be placed inside an overlay anchored below the bell icon.
class NotificationPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationPanel({super.key, this.onClose});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel>
    with SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<List<AppNotification>>? _subscription;
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _notifications = _filterNotifications(_service.notifications);
    _subscription = _service.notificationStream.listen((list) {
      if (mounted) {
        setState(() => _notifications = _filterNotifications(list));
        _staggerController.forward(from: 0);
      }
    });
    _refresh();
  }

  List<AppNotification> _filterNotifications(
    List<AppNotification> notifications,
  ) {
    // Exclude message notifications - they now appear as badge on chat icon
    return notifications.where((n) => n.type != 'new_message').toList();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _service.fetchNotifications();
    if (mounted) {
      setState(() => _isLoading = false);
      _staggerController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _staggerController.dispose();
    super.dispose();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _markAsRead(int id) async {
    await _service.markAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    await _service.markAllAsRead();
  }

  Future<void> _delete(int id) async {
    await _service.deleteNotification(id);
  }

  void _onTap(AppNotification notification) {
    if (!notification.isRead) {
      // Fire-and-forget: mark as read in background
      // The stream listener will update the badge automatically
      _service.markAsRead(notification.id);
    }

    final navData = _service.getNavigationData(notification);
    if (navData != null) {
      widget.onClose?.call();
      Navigator.pushNamed(
        context,
        navData['route'] as String,
        arguments: navData['args'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceMD,
        AppTheme.spaceSM,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: AppTheme.fontXL,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_unreadCount > 0)
                GestureDetector(
                  onTap: _markAllAsRead,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSM,
                      vertical: AppTheme.spaceXS,
                    ),
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final colors = context.appColors;
    if (_isLoading && _notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: colors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              Text(
                'No notifications yet',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: AppTheme.fontBody,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSM,
            vertical: AppTheme.spaceSM,
          ),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            // Stagger: each item fades/slides in with a slight delay
            final itemCount = _notifications.length.clamp(1, 20);
            final start = (index / itemCount) * 0.6;
            final end = start + 0.4;
            final curvedValue = Curves.easeOutCubic.transform(
              (((_staggerController.value - start) / (end - start)).clamp(
                0.0,
                1.0,
              )),
            );

            return Opacity(
              opacity: curvedValue,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - curvedValue)),
                child: NotificationItem(
                  notification: notification,
                  onTap: () => _onTap(notification),
                  onMarkRead: () => _markAsRead(notification.id),
                  onDelete: () => _delete(notification.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
