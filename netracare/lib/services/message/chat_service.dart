import 'dart:async';

import '../../models/consultation/chat_message_model.dart';
import '../../models/consultation/message_delivery_status.dart';
import '../../models/consultation/attachment_model.dart';
import 'chat_repository.dart';
import 'chat_history_store.dart';
import 'chat_socket_manager.dart';
import 'firebase_chat_history_store.dart';

class ChatService {
  ChatService({
    ChatRepository? repository,
    ChatSocketManager? socketManager,
    ChatHistoryStore? historyStore,
  }) : _repository = repository ?? ChatRepository(),
       _socketManager = socketManager ?? ChatSocketManager(),
       _historyStore = historyStore ?? FirebaseChatHistoryStore();

  final ChatRepository _repository;
  final ChatSocketManager _socketManager;
  final ChatHistoryStore _historyStore;

  final StreamController<List<ChatMessage>> _messagesController =
      StreamController.broadcast();
  final StreamController<String> _typingController =
      StreamController.broadcast();
  final StreamController<String?> _errorController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();
  final StreamController<ChatConnectionState> _connectionStatusController =
      StreamController.broadcast();

  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  Stream<String> get typingStream => _typingController.stream;
  Stream<String?> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<ChatConnectionState> get connectionStatusStream =>
      _connectionStatusController.stream;

  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _pendingQueue = [];
  final Map<String, Timer> _deliveryTimeouts = <String, Timer>{};

  int? _consultationId;
  bool _isDoctor = false;
  StreamSubscription? _subNewMessage;
  StreamSubscription? _subMessageSent;
  StreamSubscription? _subTyping;
  StreamSubscription? _subRead;
  StreamSubscription? _subConnection;
  StreamSubscription? _subError;
  StreamSubscription? _subFirebaseHistory;

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

    // Run Firebase history in the background - don't block socket connection.
    _initializeFirebaseHistory();

    final token = await _repository.getSocketToken(isDoctor: _isDoctor);
    if (token == null) {
      _errorController.add('Missing authentication token for chat.');
      return;
    }

    _registerListeners();
    await _socketManager.connect(token: token);
    if (_socketManager.isConnected) {
      _socketManager.joinRoom(_consultationId!);
    }
  }

  Future<void> _initializeFirebaseHistory() async {
    if (_consultationId == null) {
      return;
    }

    try {
      final customToken = await _repository.getFirebaseCustomToken(
        isDoctor: _isDoctor,
        consultationId: _consultationId!,
      );

      if (customToken == null || customToken.trim().isEmpty) {
        return;
      }

      await _historyStore.authenticateWithCustomToken(customToken);

      await _subFirebaseHistory?.cancel();
      _subFirebaseHistory = _historyStore
          .watchMessages(_consultationId!)
          .listen(
            _mergePersistedMessages,
            onError: (_) {
              _errorController.add('Unable to read Firebase chat history.');
            },
          );
    } catch (_) {
      _errorController.add('Unable to initialize Firebase chat history.');
    }
  }

  void _mergePersistedMessages(List<ChatMessage> persisted) {
    if (persisted.isEmpty) {
      return;
    }

    var changed = false;
    for (final incoming in persisted) {
      final existingIndex = _messages.indexWhere(
        (msg) =>
            msg.id == incoming.id ||
            (incoming.tempId != null && msg.tempId == incoming.tempId),
      );

      if (existingIndex >= 0) {
        if (!_sameMessage(_messages[existingIndex], incoming)) {
          _messages[existingIndex] = incoming;
          changed = true;
        }
      } else {
        _messages.add(incoming);
        changed = true;
      }
    }

    if (!changed) {
      return;
    }

    _messages.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return left.compareTo(right);
    });
    _messagesController.add(List.unmodifiable(_messages));
  }

  bool _sameMessage(ChatMessage left, ChatMessage right) {
    return left.id == right.id &&
        left.tempId == right.tempId &&
        left.message == right.message &&
        left.status == right.status &&
        left.isRead == right.isRead &&
        left.readAt == right.readAt &&
        left.createdAt == right.createdAt;
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
    _subConnection = _socketManager.onConnectionStatus.listen((status) {
      _connectionStatusController.add(status);
      final connected = status == ChatConnectionState.connected;
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

    if (incoming.tempId != null && incoming.tempId!.isNotEmpty) {
      _clearDeliveryTimeout(incoming.tempId!);
    }

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

    if (tempId != null && tempId.isNotEmpty) {
      _clearDeliveryTimeout(tempId);
    } else if (sent.tempId != null && sent.tempId!.isNotEmpty) {
      _clearDeliveryTimeout(sent.tempId!);
    }

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
      await _socketManager.sendMessageWithAck(
        consultationId: _consultationId!,
        content: content,
        tempId: tempId,
      );

      _scheduleDeliveryTimeout(tempId);
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

  Future<void> sendMessageWithAttachments({
    String? text,
    required List<Attachment> attachments,
  }) async {
    if (attachments.isEmpty || _consultationId == null) {
      return;
    }

    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];
      final tempId = '${DateTime.now().millisecondsSinceEpoch}_$i';
      final messageText = i == 0 ? text : null;

      final optimistic = ChatMessage(
        id: tempId,
        tempId: tempId,
        sender: _isDoctor ? MessageSender.doctor : MessageSender.user,
        message: messageText ?? 'Shared ${attachment.type.displayName}',
        time: _formatNow(),
        createdAt: DateTime.now(),
        status: MessageDeliveryStatus.pending,
        attachments: [attachment],
      );

      _messages.add(optimistic);
      _messagesController.add(List.unmodifiable(_messages));

      if (_socketManager.isConnected) {
        final accepted = await _socketManager.sendMessageWithAttachmentsAndAck(
          consultationId: _consultationId!,
          content: messageText,
          attachments: [attachment],
          tempId: tempId,
        );

        if (accepted) {
          _scheduleDeliveryTimeout(tempId);
          continue;
        }
      }

      try {
        final fallback = await _repository.sendFallbackWithAttachments(
          isDoctor: _isDoctor,
          consultationId: _consultationId!,
          content: messageText,
          attachments: [attachment],
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

  void _replaceMessage(String tempId, ChatMessage replacement) {
    final idx = _messages.indexWhere(
      (item) => item.id == tempId || item.tempId == tempId,
    );
    if (idx >= 0) {
      _messages[idx] = replacement;
    }
    if (replacement.status != MessageDeliveryStatus.pending) {
      _clearDeliveryTimeout(tempId);
    }
    _messagesController.add(List.unmodifiable(_messages));
  }

  void _scheduleDeliveryTimeout(
    String tempId, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    _clearDeliveryTimeout(tempId);
    _deliveryTimeouts[tempId] = Timer(timeout, () {
      _deliveryTimeouts.remove(tempId);

      final idx = _messages.indexWhere(
        (item) => item.tempId == tempId || item.id == tempId,
      );
      if (idx < 0) {
        return;
      }

      final current = _messages[idx];
      if (current.status != MessageDeliveryStatus.pending) {
        return;
      }

      _messages[idx] = current.copyWith(status: MessageDeliveryStatus.failed);
      _messagesController.add(List.unmodifiable(_messages));
      _errorController.add('Message delivery timed out. Tap to retry.');
    });
  }

  void _clearDeliveryTimeout(String tempId) {
    _deliveryTimeouts.remove(tempId)?.cancel();
  }

  Future<void> _flushPendingQueue() async {
    if (_pendingQueue.isEmpty || _consultationId == null) {
      return;
    }

    final queue = List<ChatMessage>.from(_pendingQueue);
    _pendingQueue.clear();

    for (final pending in queue) {
      final tempId = pending.tempId ?? pending.id;
      await _socketManager.sendMessageWithAck(
        consultationId: _consultationId!,
        content: pending.message,
        tempId: tempId,
      );

      _scheduleDeliveryTimeout(tempId);
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
    await _subFirebaseHistory?.cancel();

    for (final timer in _deliveryTimeouts.values) {
      timer.cancel();
    }
    _deliveryTimeouts.clear();

    _socketManager.dispose();
    await _historyStore.dispose();
    await _messagesController.close();
    await _typingController.close();
    await _errorController.close();
    await _connectionController.close();
    await _connectionStatusController.close();
  }
}
