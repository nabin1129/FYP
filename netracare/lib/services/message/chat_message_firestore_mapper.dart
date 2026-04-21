import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/consultation/chat_message_model.dart';

class ChatMessageFirestoreMapper {
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return DateTime.tryParse(raw.toString());
  }

  static ChatMessage fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final payload = <String, dynamic>{
      ...data,
      'id': data['id'] ?? doc.id,
      'sender_type': data['sender_type'],
      'content': data['content'],
      'created_at': _parseDate(data['created_at'])?.toIso8601String(),
      'read_at': _parseDate(data['read_at'])?.toIso8601String(),
      'is_read': data['is_read'] == true,
    };
    return ChatMessage.fromJson(payload);
  }
}
