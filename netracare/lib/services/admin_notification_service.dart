import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'notification_service.dart';

/// Lightweight admin notification fetcher (read-only).
class AdminNotificationService {
  static Future<List<AppNotification>> fetchNotifications({
    bool unreadOnly = false,
    String? priority,
    String? type,
    int limit = 100,
  }) async {
    final token = await ApiService.getAdminToken();
    if (token == null || token.isEmpty) {
      throw 'Admin session expired. Please login again.';
    }

    final params = <String, String>{
      'limit': '$limit',
      if (unreadOnly) 'unread': 'true',
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (type != null && type.isNotEmpty) 'type': type,
    };

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/notifications/admin',
    ).replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final list = data['notifications'] as List? ?? [];
      return list
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
    }

    throw data['message'] as String? ?? 'Failed to fetch notifications';
  }
}
