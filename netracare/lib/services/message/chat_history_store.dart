import '../../models/consultation/chat_message_model.dart';

abstract class ChatHistoryStore {
  Future<void> authenticateWithCustomToken(String customToken);

  Stream<List<ChatMessage>> watchMessages(int consultationId);

  Future<void> dispose();
}
