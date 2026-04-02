import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/admin_notification_service.dart';
import 'package:netracare/services/notification_service.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  bool _unreadOnly = false;
  String? _priority;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminNotificationService.fetchNotifications(
        unreadOnly: _unreadOnly,
        priority: _priority,
      );
      if (!mounted) return;
      setState(() => _notifications = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Admin Notifications',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _priority,
              hint: const Text('Priority'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (v) {
                setState(() => _priority = v);
                _load();
              },
            ),
          ),
          IconButton(
            icon: Icon(
              _unreadOnly ? Icons.mark_email_unread : Icons.mark_email_read,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              setState(() => _unreadOnly = !_unreadOnly);
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
          ? _buildError()
          : _notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                itemCount: _notifications.length,
                itemBuilder: (_, i) => _buildTile(_notifications[i]),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Failed to load notifications'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(AppNotification n) {
    final color = n.isHighPriority ? AppTheme.error : AppTheme.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(n.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n.title,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (n.isHighPriority ? AppTheme.error : AppTheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  n.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: n.isHighPriority ? AppTheme.error : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(n.message, style: const TextStyle(color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                n.timeAgo,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontXS,
                ),
              ),
              const Spacer(),
              Text(
                n.type.replaceAll('_', ' '),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontXS,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
