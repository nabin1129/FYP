import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/consultation/chat_message_model.dart';
import 'chat_history_store.dart';
import 'chat_message_firestore_mapper.dart';

class FirebaseChatHistoryStore implements ChatHistoryStore {
  FirebaseChatHistoryStore({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<void> authenticateWithCustomToken(String customToken) async {
    if (customToken.trim().isEmpty) {
      throw Exception('Missing Firebase custom token.');
    }

    final current = _auth.currentUser;
    if (current != null) {
      return;
    }

    await _auth.signInWithCustomToken(customToken);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(int consultationId) {
    return _firestore
        .collection('consultations')
        .doc(consultationId.toString())
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ChatMessageFirestoreMapper.fromFirestore)
              .toList(),
        );
  }

  @override
  Future<void> dispose() async {
    // Keep Firebase auth session alive for app-level reuse.
  }
}
