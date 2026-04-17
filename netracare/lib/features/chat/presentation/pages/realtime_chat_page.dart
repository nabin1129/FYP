import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../models/consultation/chat_message_model.dart';
import '../../../../models/consultation/message_delivery_status.dart';
import '../../../../services/message/chat_service.dart';
import '../../../../widgets/consultation/chat_bubble.dart';

class RealtimeChatPage extends StatefulWidget {
  const RealtimeChatPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDoctor,
    this.consultationId,
    this.doctorId,
    this.patientId,
    this.avatarUrl,
  });

  final String title;
  final String subtitle;
  final bool isDoctor;
  final int? consultationId;
  final int? doctorId;
  final int? patientId;
  final String? avatarUrl;

  @override
  State<RealtimeChatPage> createState() => _RealtimeChatPageState();
}

class _RealtimeChatPageState extends State<RealtimeChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _connected = false;
  String _typingText = '';

  StreamSubscription? _messagesSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _connectionSub;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messagesSub?.cancel();
    _typingSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _messagesSub = _chatService.messagesStream.listen((messages) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
      _markInboundAsRead();
    });

    _typingSub = _chatService.typingStream.listen((typingLabel) {
      if (!mounted) {
        return;
      }
      setState(() {
        _typingText = typingLabel;
      });
    });

    _connectionSub = _chatService.connectionStream.listen((connected) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connected = connected;
      });
    });

    _errorSub = _chatService.errorStream.listen((message) {
      if (!mounted || message == null || message.isEmpty) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    try {
      await _chatService.initialize(
        isDoctor: widget.isDoctor,
        consultationId: widget.consultationId,
        doctorId: widget.doctorId,
        patientId: widget.patientId,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize chat: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _inputController.clear();
    _chatService.stopTyping();
    await _chatService.sendMessage(text);
  }

  void _onTextChanged(String value) {
    if (value.trim().isEmpty) {
      _typingDebounce?.cancel();
      _chatService.stopTyping();
      return;
    }

    _chatService.startTyping();
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 900), () {
      _chatService.stopTyping();
    });
  }

  void _markInboundAsRead() {
    final targetSender = widget.isDoctor
        ? MessageSender.user
        : MessageSender.doctor;
    final pendingRead = _messages
        .where((msg) => msg.sender == targetSender && !msg.isRead)
        .map((msg) => msg.id)
        .toList();

    if (pendingRead.isNotEmpty) {
      _chatService.markVisibleMessagesAsRead(pendingRead);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.testIconBackground,
              backgroundImage:
                  (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                  ? NetworkImage(widget.avatarUrl!)
                  : null,
              child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                  ? Text(
                      _initials(widget.title),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _typingText.isNotEmpty
                        ? _typingText
                        : (_connected ? widget.subtitle : 'Reconnecting...'),
                    style: TextStyle(
                      color: _typingText.isNotEmpty
                          ? AppTheme.primary
                          : (_connected ? AppTheme.success : AppTheme.error),
                      fontSize: AppTheme.fontSM,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _chatService.refreshHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_connected)
            Container(
              width: double.infinity,
              color: AppTheme.warning,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
              child: const Text(
                'Connection unstable. Messages will retry automatically.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _chatService.refreshHistory,
                    child: _messages.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(AppTheme.spaceMD),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return GestureDetector(
                                onLongPress: () {
                                  if (msg.status ==
                                      MessageDeliveryStatus.failed) {
                                    _chatService.retryMessage(msg.id);
                                  }
                                },
                                child: ChatBubble(message: msg),
                              );
                            },
                          ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              decoration: const BoxDecoration(color: AppTheme.surface),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: AppTheme.spaceSM,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppTheme.primary,
                      ),
                      onPressed: _send,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String input) {
    final parts = input.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
