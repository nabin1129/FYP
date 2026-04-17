import 'dart:async';

import '../../models/consultation/chat_message_model.dart';
import '../../models/consultation/message_delivery_status.dart';
import 'chat_repository.dart';
import 'chat_socket_manager.dart';

class ChatService {
  ChatService({ChatRepository? repository, ChatSocketManager? socketManager})
    : _repository = repository ?? ChatRepository(),
      _socketManager = socketManager ?? ChatSocketManager();

  final ChatRepository _repository;
  final ChatSocketManager _socketManager;

  final StreamController<List<ChatMessage>> _messagesController =
      StreamController.broadcast();
  final StreamController<String> _typingController =
      StreamController.broadcast();
  final StreamController<String?> _errorController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();

  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<String> get typingStream => _typingController.stream;
  Stream<String?> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _pendingQueue = [];

  int? _consultationId;
  bool _isDoctor = false;
  StreamSubscription? _subNewMessage;
  StreamSubscription? _subMessageSent;
  StreamSubscription? _subTyping;
  StreamSubscription? _subRead;
  StreamSubscription? _subConnection;
  StreamSubscription? _subError;

  List<ChatMessage> get currentMessages => List.unmodifiable(_messages);

  Future<void> initialize({
    required bool isDoctor,
    int? consultationId,
    int? doctorId,
    int? patientId,
  }) async {
    _isDoctor = isDoctor;

    _consultationId = await _repository.createOrFetchRoom(
      isDoctor: isDoctor,
      consultationId: consultationId,
      doctorId: doctorId,
      patientId: patientId,
    );

    final history = await _repository.loadHistory(
      isDoctor: _isDoctor,
      consultationId: _consultationId!,
    );

    _messages
      ..clear()
      ..addAll(history);
    _messagesController.add(List.unmodifiable(_messages));

    final token = await _repository.getSocketToken(isDoctor: _isDoctor);
    if (token == null) {
      _errorController.add('Missing authentication token for chat.');
      return;
    }

    await _socketManager.connect(token: token);
    _registerListeners();
    _socketManager.joinRoom(_consultationId!);
  }

  void _registerListeners() {
    _subNewMessage?.cancel();
    _subMessageSent?.cancel();
    _subTyping?.cancel();
    _subRead?.cancel();
    _subConnection?.cancel();
    _subError?.cancel();

    _subNewMessage = _socketManager.onNewMessage.listen(_onNewMessage);
    _subMessageSent = _socketManager.onMessageSent.listen(_onMessageSent);
    _subTyping = _socketManager.onTyping.listen(_onTyping);
    _subRead = _socketManager.onMessagesRead.listen(_onMessagesRead);
    _subConnection = _socketManager.onConnectionState.listen((connected) {
      _connectionController.add(connected);
      if (connected && _consultationId != null) {
        _socketManager.joinRoom(_consultationId!);
        _flushPendingQueue();
      }
    });
    _subError = _socketManager.onError.listen((event) {
      _errorController.add(event);
    });
  }

  void _onNewMessage(Map<String, dynamic> payload) {
    final incoming = ChatMessage.fromJson(payload);

    final existingIndex = _messages.indexWhere(
      (msg) =>
          msg.id == incoming.id ||
          (incoming.tempId != null && msg.tempId == incoming.tempId),
    );

    if (existingIndex >= 0) {
      _messages[existingIndex] = incoming;
    } else {
      _messages.add(incoming);
    }

    _messagesController.add(List.unmodifiable(_messages));
  }

  void _onMessageSent(Map<String, dynamic> payload) {
    final sent = ChatMessage.fromJson(payload);
    final tempId = payload['temp_id']?.toString();

    if (tempId != null) {
      final pendingIndex = _messages.indexWhere((msg) => msg.tempId == tempId);
      if (pendingIndex >= 0) {
        _messages[pendingIndex] = sent.copyWith(
          status: MessageDeliveryStatus.sent,
        );
        _messagesController.add(List.unmodifiable(_messages));
        return;
      }
    }

    _onNewMessage(payload);
  }

  void _onTyping(Map<String, dynamic> payload) {
    final senderRole = payload['sender_role']?.toString() ?? '';
    final isTyping = payload['is_typing'] == true;

    if ((_isDoctor && senderRole == 'doctor') ||
        (!_isDoctor && senderRole == 'patient')) {
      return;
    }

    _typingController.add(isTyping ? 'Typing...' : '');
  }

  void _onMessagesRead(Map<String, dynamic> payload) {
    final ids = List<String>.from(
      (payload['message_ids'] as List<dynamic>? ?? const []).map(
        (e) => e.toString(),
      ),
    );
    if (ids.isEmpty) {
      return;
    }

    for (var i = 0; i < _messages.length; i++) {
      if (ids.contains(_messages[i].id)) {
        _messages[i] = _messages[i].copyWith(
          isRead: true,
          status: MessageDeliveryStatus.read,
          readAt: DateTime.now(),
        );
      }
    }

    _messagesController.add(List.unmodifiable(_messages));
  }

  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || _consultationId == null) {
      return;
    }

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimistic = ChatMessage(
      id: tempId,
      tempId: tempId,
      sender: _isDoctor ? MessageSender.doctor : MessageSender.user,
      message: content,
      time: _formatNow(),
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.pending,
    );

    _messages.add(optimistic);
    _messagesController.add(List.unmodifiable(_messages));

    if (_socketManager.isConnected) {
      _socketManager.sendMessage(
        consultationId: _consultationId!,
        content: content,
        tempId: tempId,
      );
      return;
    }

    _pendingQueue.add(optimistic);
    _errorController.add('Message queued. Sending when connected.');

    try {
      final fallback = await _repository.sendFallback(
        isDoctor: _isDoctor,
        consultationId: _consultationId!,
        content: content,
      );
      _replaceMessage(
        tempId,
        fallback.copyWith(status: MessageDeliveryStatus.sent),
      );
    } catch (_) {
      _replaceMessage(
        tempId,
        optimistic.copyWith(status: MessageDeliveryStatus.failed),
      );
    }
  }

  void retryMessage(String messageId) {
    final index = _messages.indexWhere((element) => element.id == messageId);
    if (index < 0) {
      return;
    }

    final failed = _messages[index];
    sendMessage(failed.message);
    _messages.removeAt(index);
    _messagesController.add(List.unmodifiable(_messages));
  }

  Future<void> refreshHistory() async {
    if (_consultationId == null) {
      return;
    }

    final history = await _repository.loadHistory(
      isDoctor: _isDoctor,
      consultationId: _consultationId!,
    );

    _messages
      ..clear()
      ..addAll(history);
    _messagesController.add(List.unmodifiable(_messages));

    final unreadInbound = history
        .where(
          (msg) =>
              (_isDoctor
                  ? msg.sender == MessageSender.user
                  : msg.sender == MessageSender.doctor) &&
              !msg.isRead,
        )
        .map((msg) => msg.id)
        .toList();

    if (unreadInbound.isNotEmpty) {
      _socketManager.markRead(_consultationId!, unreadInbound);
    }
  }

  void startTyping() {
    if (_consultationId != null) {
      _socketManager.typingStart(_consultationId!);
    }
  }

  void stopTyping() {
    if (_consultationId != null) {
      _socketManager.typingStop(_consultationId!);
    }
  }

  void markVisibleMessagesAsRead(List<String> messageIds) {
    if (_consultationId == null || messageIds.isEmpty) {
      return;
    }
    _socketManager.markRead(_consultationId!, messageIds);
  }

  void _replaceMessage(String tempId, ChatMessage replacement) {
    final idx = _messages.indexWhere(
      (item) => item.id == tempId || item.tempId == tempId,
    );
    if (idx >= 0) {
      _messages[idx] = replacement;
    }
    _messagesController.add(List.unmodifiable(_messages));
  }

  Future<void> _flushPendingQueue() async {
    if (_pendingQueue.isEmpty || _consultationId == null) {
      return;
    }

    final queue = List<ChatMessage>.from(_pendingQueue);
    _pendingQueue.clear();

    for (final pending in queue) {
      _socketManager.sendMessage(
        consultationId: _consultationId!,
        content: pending.message,
        tempId: pending.tempId ?? pending.id,
      );
    }
  }

  String _formatNow() {
    final now = DateTime.now();
    final hourRaw = now.hour;
    final hour = hourRaw == 0 ? 12 : (hourRaw > 12 ? hourRaw - 12 : hourRaw);
    final period = hourRaw >= 12 ? 'PM' : 'AM';
    return '$hour:${now.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> dispose() async {
    await _subNewMessage?.cancel();
    await _subMessageSent?.cancel();
    await _subTyping?.cancel();
    await _subRead?.cancel();
    await _subConnection?.cancel();
    await _subError?.cancel();

    _socketManager.dispose();
    await _messagesController.close();
    await _typingController.close();
    await _errorController.close();
    await _connectionController.close();
  }
}
