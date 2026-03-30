import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/chat_message_model.dart';
import 'package:netracare/widgets/consultation/chat_bubble.dart';
import 'package:netracare/services/doctor_api_service.dart';

/// Chat Tab Content
class ChatTab extends StatefulWidget {
  final List<ChatMessage> messages;
  final String? consultationId;

  const ChatTab({super.key, required this.messages, this.consultationId});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.messages);
    if (widget.consultationId != null) {
      _loadMessagesFromAPI();
    }
  }

  Future<void> _loadMessagesFromAPI() async {
    if (widget.consultationId == null) return;

    try {
      final messages = await DoctorApiService.getConsultationMessages(
        consultationId: widget.consultationId!,
      );

      if (mounted) {
        setState(() {
          _messages = messages.map((m) {
            final isDoctor = m['sender_type'] == 'doctor';
            return ChatMessage(
              id: m['id'].toString(),
              sender: isDoctor ? MessageSender.doctor : MessageSender.user,
              message: m['message'] ?? '',
              time: _formatTime(m['created_at']),
            );
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      message: messageText,
      time: _getCurrentTime(),
    );

    setState(() {
      _messages.add(newMessage);
      _isSending = true;
    });

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

    // If we have a real consultation ID, send to API
    if (widget.consultationId != null) {
      try {
        await DoctorApiService.sendPatientMessage(
          consultationId: widget.consultationId!,
          message: messageText,
        );

        if (mounted) {
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
          setState(() => _isSending = false);
        }
      } catch (e) {
        if (mounted) {
          // Keep the message in UI but show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
          setState(() => _isSending = false);
        }
      }
    } else {
      // Local-only mode (fallback)
      if (mounted) {
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
        setState(() => _isSending = false);
      }
    }
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null) return _getCurrentTime();
    try {
      final dt = DateTime.parse(dateTimeStr);
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return _getCurrentTime();
    }
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
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: AppTheme.textSecondary,
              ),
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
            child: Column(
              children: [
                Row(
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
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (widget.consultationId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spaceSM),
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () => _showShareTestMenu(),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share Test Result'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMD,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showShareTestMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Test Result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spaceMD),
            ListTile(
              leading: const Icon(Icons.remove_red_eye),
              title: const Text('Visual Acuity'),
              onTap: () {
                Navigator.pop(context);
                _shareTest('visual_acuity', 'visual_acuity_id');
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Color Vision'),
              onTap: () {
                Navigator.pop(context);
                _shareTest('colour_vision', 'colour_vision_id');
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_red_eye),
              title: const Text('Blink & Fatigue'),
              onTap: () {
                Navigator.pop(context);
                _shareTest('blink_fatigue', 'blink_fatigue_id');
              },
            ),
            ListTile(
              leading: const Icon(Icons.track_changes),
              title: const Text('Eye Tracking'),
              onTap: () {
                Navigator.pop(context);
                _shareTest('eye_tracking', 'eye_tracking_id');
              },
            ),
            const SizedBox(height: AppTheme.spaceSM),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareTest(String testType, String testIdField) async {
    try {
      // Note: In a real scenario, you'd fetch the actual test ID from user selection or database
      // For now, we'll show a dialog for the user to confirm
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Share $testType Test?'),
          content: Text('This test will be shared with your doctor.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // In a real app, get the test ID from the user's test history
                // For now, using a placeholder
                const testId = '1';

                try {
                  await DoctorApiService.shareTestWithDoctor(
                    consultationId: widget.consultationId!,
                    testType: testType,
                    testId: testId,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$testType test shared successfully!'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to share test: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}
