import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:netracare/models/consultation/chat_message_model.dart';
import 'package:netracare/models/consultation/message_delivery_status.dart';
import 'package:netracare/services/message/chat_repository.dart';
import 'package:netracare/services/message/chat_service.dart';
import 'package:netracare/services/message/chat_socket_manager.dart';

class FakeChatRepository extends ChatRepository {
  FakeChatRepository({
    required this.roomId,
    required this.history,
    this.socketToken = 'test-token',
    this.failFallback = false,
  });

  final int roomId;
  final List<ChatMessage> history;
  final String? socketToken;
  final bool failFallback;

  int createRoomCalls = 0;
  int loadHistoryCalls = 0;
  int fallbackCalls = 0;
  final List<Map<String, dynamic>> fallbackPayloads = [];

  @override
  Future<int> createOrFetchRoom({
    required bool isDoctor,
    int? consultationId,
    int? doctorId,
    int? patientId,
  }) async {
    createRoomCalls += 1;
    return roomId;
  }

  @override
  Future<List<ChatMessage>> loadHistory({
    required bool isDoctor,
    required int consultationId,
  }) async {
    loadHistoryCalls += 1;
    return history;
  }

  @override
  Future<ChatMessage> sendFallback({
    required bool isDoctor,
    required int consultationId,
    required String content,
  }) async {
    fallbackCalls += 1;
    fallbackPayloads.add({
      'isDoctor': isDoctor,
      'consultationId': consultationId,
      'content': content,
    });

    if (failFallback) {
      throw Exception('fallback failed');
    }

    return ChatMessage.fromJson({
      'id': 'server-$fallbackCalls',
      'consultation_id': consultationId,
      'sender_type': isDoctor ? 'doctor' : 'patient',
      'content': content,
      'created_at': DateTime.utc(2026, 4, 11, 9, 0).toIso8601String(),
      'is_read': false,
    });
  }

  @override
  Future<String?> getSocketToken({required bool isDoctor}) async {
    return socketToken;
  }
}

class FakeChatSocketManager extends ChatSocketManager {
  final StreamController<Map<String, dynamic>> _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageSentController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  String? connectedToken;
  bool connected = false;
  final List<int> joinedRooms = [];
  final List<Map<String, dynamic>> sentMessages = [];
  final List<int> typingStartCalls = [];
  final List<int> typingStopCalls = [];
  final List<Map<String, dynamic>> readCalls = [];

  @override
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  @override
  Stream<Map<String, dynamic>> get onMessageSent =>
      _messageSentController.stream;

  @override
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;

  @override
  Stream<Map<String, dynamic>> get onMessagesRead => _readController.stream;

  @override
  Stream<bool> get onConnectionState => _connectionController.stream;

  @override
  Stream<String> get onError => _errorController.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect({required String token}) async {
    connectedToken = token;
  }

  @override
  void joinRoom(int consultationId) {
    joinedRooms.add(consultationId);
  }

  @override
  void sendMessage({
    required int consultationId,
    required String content,
    required String tempId,
  }) {
    sentMessages.add({
      'consultation_id': consultationId,
      'content': content,
      'tempId': tempId,
    });
  }

  @override
  void typingStart(int consultationId) {
    typingStartCalls.add(consultationId);
  }

  @override
  void typingStop(int consultationId) {
    typingStopCalls.add(consultationId);
  }

  @override
  void markRead(int consultationId, List<String> messageIds) {
    readCalls.add({
      'consultation_id': consultationId,
      'message_ids': messageIds,
    });
  }

  void emitConnection(bool value) {
    connected = value;
    _connectionController.add(value);
  }

  void emitMessageSent(Map<String, dynamic> payload) {
    _messageSentController.add(payload);
  }

  void emitNewMessage(Map<String, dynamic> payload) {
    _newMessageController.add(payload);
  }

  void emitTyping(Map<String, dynamic> payload) {
    _typingController.add(payload);
  }

  void emitError(String message) {
    _errorController.add(message);
  }

  @override
  void disconnect() {
    connected = false;
    _connectionController.add(false);
  }

  @override
  void dispose() {
    _newMessageController.close();
    _messageSentController.close();
    _typingController.close();
    _readController.close();
    _connectionController.close();
    _errorController.close();
  }
}

Future<void> _drainEventQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('ChatService', () {
    test('initializes history and joins the consultation room', () async {
      final repository = FakeChatRepository(
        roomId: 42,
        history: [
          ChatMessage.fromJson({
            'id': 'message-1',
            'consultation_id': 42,
            'sender_type': 'doctor',
            'content': 'Initial follow-up note',
            'created_at': DateTime.utc(2026, 4, 11, 8, 30).toIso8601String(),
            'is_read': true,
          }),
        ],
      );
      final socket = FakeChatSocketManager();
      final service = ChatService(
        repository: repository,
        socketManager: socket,
      );

      await service.initialize(
        isDoctor: false,
        consultationId: 42,
        doctorId: 7,
      );

      expect(repository.createRoomCalls, 1);
      expect(repository.loadHistoryCalls, 1);
      expect(socket.connectedToken, 'test-token');
      expect(socket.joinedRooms, [42]);
      expect(service.currentMessages, hasLength(1));
      expect(service.currentMessages.single.message, 'Initial follow-up note');
    });

    test('queues offline messages and flushes them after reconnect', () async {
      final repository = FakeChatRepository(
        roomId: 42,
        history: const [],
        failFallback: true,
      );
      final socket = FakeChatSocketManager();
      final service = ChatService(
        repository: repository,
        socketManager: socket,
      );

      await service.initialize(
        isDoctor: false,
        consultationId: 42,
        doctorId: 7,
      );
      await service.sendMessage('Reconnect me later');

      expect(repository.fallbackCalls, 1);
      expect(socket.sentMessages, isEmpty);
      expect(
        service.currentMessages.single.status,
        MessageDeliveryStatus.failed,
      );

      socket.emitConnection(true);
      await _drainEventQueue();

      expect(socket.joinedRooms, [42, 42]);
      expect(socket.sentMessages, hasLength(1));
      expect(socket.sentMessages.single['content'], 'Reconnect me later');
      expect(socket.sentMessages.single['consultation_id'], 42);
    });

    test(
      'reconciles optimistic messages when the socket acknowledges them',
      () async {
        final repository = FakeChatRepository(roomId: 42, history: const []);
        final socket = FakeChatSocketManager();
        final service = ChatService(
          repository: repository,
          socketManager: socket,
        );

        await service.initialize(
          isDoctor: false,
          consultationId: 42,
          doctorId: 7,
        );
        socket.emitConnection(true);
        await _drainEventQueue();

        await service.sendMessage('Hello doctor');

        expect(socket.sentMessages, hasLength(1));
        final tempId = socket.sentMessages.single['tempId'] as String;

        socket.emitMessageSent({
          'id': 'server-1',
          'consultation_id': 42,
          'sender_type': 'patient',
          'content': 'Hello doctor',
          'created_at': DateTime.utc(2026, 4, 11, 9, 15).toIso8601String(),
          'temp_id': tempId,
          'is_read': false,
        });
        await _drainEventQueue();

        expect(service.currentMessages, hasLength(1));
        expect(service.currentMessages.single.id, 'server-1');
        expect(
          service.currentMessages.single.status,
          MessageDeliveryStatus.sent,
        );
        expect(service.currentMessages.single.message, 'Hello doctor');
      },
    );
  });
}
