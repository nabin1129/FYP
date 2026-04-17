import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/api_config.dart';

class ChatSocketManager {
  io.Socket? _socket;

  final StreamController<Map<String, dynamic>> _newMessageController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _messageSentController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _readController =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();
  final StreamController<String> _errorController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageSent =>
      _messageSentController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _readController.stream;
  Stream<bool> get onConnectionState => _connectionController.stream;
  Stream<String> get onError => _errorController.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect({required String token}) async {
    if (isConnected) {
      return;
    }

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(15000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      _connectionController.add(false);
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
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _messageSentController.close();
    _typingController.close();
    _readController.close();
    _connectionController.close();
    _errorController.close();
  }
}
