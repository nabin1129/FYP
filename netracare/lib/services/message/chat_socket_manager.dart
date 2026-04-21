import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/api_config.dart';
import '../../models/consultation/attachment_model.dart';

enum ChatConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class ChatSocketManager {
  io.Socket? _socket;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;

  void _disposeSocketInstance() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  final StreamController<Map<String, dynamic>> _newMessageController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _messageSentController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _readController =
      StreamController.broadcast();
  final StreamController<ChatConnectionState> _connectionStatusController =
      StreamController.broadcast();
  final StreamController<String> _errorController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageSent =>
      _messageSentController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _readController.stream;
  Stream<ChatConnectionState> get onConnectionStatus =>
      _connectionStatusController.stream;
  Stream<bool> get onConnectionState =>
      onConnectionStatus.map((state) => state == ChatConnectionState.connected);
  Stream<String> get onError => _errorController.stream;

  bool get isConnected => _socket?.connected == true;
  ChatConnectionState get connectionState => _connectionState;

  void _emitConnectionState(ChatConnectionState state) {
    if (_connectionState == state) {
      return;
    }
    _connectionState = state;
    _connectionStatusController.add(state);
  }

  Future<void> connect({required String token}) async {
    if (isConnected) {
      return;
    }

    _emitConnectionState(ChatConnectionState.connecting);

    // Ensure we don't keep stale socket instances between reconnect attempts.
    if (_socket != null) {
      _disposeSocketInstance();
    }

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          // Allow polling as fallback if WebSocket upgrade fails.
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(500) // first retry after 500 ms
          .setReconnectionDelayMax(3000) // cap retries at 3 s (was 15 s)
          .setTimeout(5000) // connection handshake timeout 5 s
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect(([dynamic _]) {
      _emitConnectionState(ChatConnectionState.connected);
    });

    _socket!.onDisconnect(([dynamic _]) {
      _emitConnectionState(ChatConnectionState.reconnecting);
    });

    _socket!.onConnectError(([dynamic error]) {
      _emitConnectionState(ChatConnectionState.failed);
      _errorController.add('Connection error: ${error.toString()}');
    });

    _socket!.onError(([dynamic error]) {
      _emitConnectionState(ChatConnectionState.failed);
      _errorController.add('Socket error: ${error.toString()}');
    });

    _socket!.on('reconnect_attempt', ([dynamic _]) {
      _emitConnectionState(ChatConnectionState.reconnecting);
    });

    _socket!.on('reconnect', ([dynamic _]) {
      _emitConnectionState(ChatConnectionState.connected);
    });

    _socket!.on('reconnect_error', ([dynamic error]) {
      _emitConnectionState(ChatConnectionState.failed);
      _errorController.add('Reconnect error: ${error.toString()}');
    });

    _socket!.on('reconnect_failed', ([dynamic _]) {
      _emitConnectionState(ChatConnectionState.failed);
      _errorController.add('Reconnect failed.');
    });

    _socket!.on('new_message', (payload) {
      if (payload is Map<String, dynamic>) {
        _newMessageController.add(payload);
      } else if (payload is Map) {
        _newMessageController.add(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.on('message_sent', (payload) {
      if (payload is Map<String, dynamic>) {
        _messageSentController.add(payload);
      } else if (payload is Map) {
        _messageSentController.add(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.on('typing', (payload) {
      if (payload is Map<String, dynamic>) {
        _typingController.add(payload);
      } else if (payload is Map) {
        _typingController.add(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.on('messages_read', (payload) {
      if (payload is Map<String, dynamic>) {
        _readController.add(payload);
      } else if (payload is Map) {
        _readController.add(Map<String, dynamic>.from(payload));
      }
    });

    _socket!.on('chat_error', (payload) {
      if (payload is Map<String, dynamic>) {
        _errorController.add(payload['message']?.toString() ?? 'Chat error');
      } else {
        _errorController.add('Chat error');
      }
    });

    _socket!.connect();
  }

  void joinRoom(int consultationId) {
    _socket?.emit('join_room', {'consultation_id': consultationId});
  }

  void sendMessage({
    required int consultationId,
    required String content,
    required String tempId,
  }) {
    _socket?.emit('send_message', {
      'consultation_id': consultationId,
      'content': content,
      'message_type': 'text',
      'temp_id': tempId,
    });
  }

  Future<bool> sendMessageWithAck({
    required int consultationId,
    required String content,
    required String tempId,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!isConnected || _socket == null) {
      return false;
    }

    final completer = Completer<bool>();
    Timer? timer;

    void completeOnce(bool value) {
      if (completer.isCompleted) {
        return;
      }
      timer?.cancel();
      completer.complete(value);
    }

    timer = Timer(timeout, () {
      completeOnce(false);
    });

    try {
      _socket!.emitWithAck(
        'send_message',
        {
          'consultation_id': consultationId,
          'content': content,
          'message_type': 'text',
          'temp_id': tempId,
        },
        ack: (dynamic ackPayload) {
          if (ackPayload is Map) {
            final data = Map<String, dynamic>.from(ackPayload);
            final successValue = data['success'];
            final statusValue = data['status']?.toString().toLowerCase();
            final hasError = data['error'] != null;

            if (successValue == false || statusValue == 'error' || hasError) {
              completeOnce(false);
              return;
            }
          }

          // If the server returns any non-error ACK payload, treat it as accepted.
          completeOnce(true);
        },
      );
    } catch (_) {
      completeOnce(false);
    }

    return completer.future;
  }

  Future<bool> sendMessageWithAttachmentsAndAck({
    required int consultationId,
    required String? content,
    required List<Attachment> attachments,
    required String tempId,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!isConnected || _socket == null || attachments.isEmpty) {
      return false;
    }

    // Determine message_type based on attachment type
    String messageType = 'file';
    if (attachments.isNotEmpty) {
      final type = attachments.first.type;
      if (type == AttachmentType.testResult) {
        messageType = 'testResult';
      } else if (type == AttachmentType.clinicalNote) {
        messageType = 'clinicalNote';
      } else if (type == AttachmentType.medicalRecord) {
        messageType = 'medicalRecord';
      } else if (type == AttachmentType.file) {
        messageType = 'file';
      }
    }

    final completer = Completer<bool>();
    Timer? timer;

    void completeOnce(bool value) {
      if (completer.isCompleted) {
        return;
      }
      timer?.cancel();
      completer.complete(value);
    }

    timer = Timer(timeout, () {
      completeOnce(false);
    });

    try {
      _socket!.emitWithAck(
        'send_message',
        {
          'consultation_id': consultationId,
          'content': content,
          'message_type': messageType,
          'attachments': attachments.map((a) => a.toJson()).toList(),
          'temp_id': tempId,
        },
        ack: (dynamic ackPayload) {
          if (ackPayload is Map) {
            final data = Map<String, dynamic>.from(ackPayload);
            final successValue = data['success'];
            final statusValue = data['status']?.toString().toLowerCase();
            final hasError = data['error'] != null;

            if (successValue == false || statusValue == 'error' || hasError) {
              completeOnce(false);
              return;
            }
          }

          // If the server returns any non-error ACK payload, treat it as accepted.
          completeOnce(true);
        },
      );
    } catch (_) {
      completeOnce(false);
    }

    return completer.future;
  }

  void typingStart(int consultationId) {
    _socket?.emit('typing_start', {'consultation_id': consultationId});
  }

  void typingStop(int consultationId) {
    _socket?.emit('typing_stop', {'consultation_id': consultationId});
  }

  void markRead(int consultationId, List<String> messageIds) {
    _socket?.emit('mark_read', {
      'consultation_id': consultationId,
      'message_ids': messageIds,
    });
  }

  void disconnect() {
    _disposeSocketInstance();
    _emitConnectionState(ChatConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _messageSentController.close();
    _typingController.close();
    _readController.close();
    _connectionStatusController.close();
    _errorController.close();
  }
}
