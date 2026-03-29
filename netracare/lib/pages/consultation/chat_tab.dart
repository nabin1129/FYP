import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/chat_message_model.dart';
import 'package:netracare/widgets/consultation/chat_bubble.dart';

/// Chat Tab Content
class ChatTab extends StatefulWidget {
  final List<ChatMessage> messages;

  const ChatTab({super.key, required this.messages});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.messages);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      message: _messageController.text.trim(),
      time: _getCurrentTime(),
    );

    setState(() {
      _messages.add(newMessage);
    });

    _messageController.clear();

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message sent successfully'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${now.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color: AppTheme.testIconBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            const Text(
              'Start a conversation with your doctor',
              style: TextStyle(fontSize: AppTheme.fontBody, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Messages List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return ChatBubble(message: _messages[index]);
            },
          ),
        ),
        // Message Input
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(color: AppTheme.textLight),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD,
                        vertical: AppTheme.spaceSM,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
