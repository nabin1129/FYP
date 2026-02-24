import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/models/consultation/chat_message_model.dart';
import 'package:netracare/services/doctor_api_service.dart';
import 'package:netracare/widgets/consultation/chat_bubble.dart';

/// Dedicated Chat Page for Doctor Consultation
class DoctorChatPage extends StatefulWidget {
  final Doctor doctor;
  final int? consultationId;

  const DoctorChatPage({
    super.key,
    required this.doctor,
    this.consultationId,
  });

  @override
  State<DoctorChatPage> createState() => _DoctorChatPageState();
}

class _DoctorChatPageState extends State<DoctorChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DoctorApiService _apiService = DoctorApiService();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessagesAsync();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessagesAsync() async {
    setState(() => _isLoading = true);
    
    if (widget.consultationId != null) {
      try {
        final response = await _apiService.getConsultationMessages(widget.consultationId!);
        if (response['success'] == true && response['messages'] != null) {
          final messagesData = response['messages'] as List;
          if (mounted) {
            setState(() {
              _messages = messagesData.map((m) => ChatMessage.fromJson(m)).toList();
              _isLoading = false;
            });
          }
          _scrollToBottom();
          return;
        }
      } catch (e) {
        // Fall through to mock data
      }
    }
    
    // Fallback to mock messages
    if (mounted) {
      setState(() {
        _messages = ChatMessage.getMockMessages();
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    setState(() => _isSending = true);

    // If we have a consultationId, send via API
    if (widget.consultationId != null) {
      try {
        final response = await _apiService.sendMessage(widget.consultationId!, messageText);
        if (response['success'] == true && response['message'] != null) {
          final newMessage = ChatMessage.fromJson(response['message']);
          if (mounted) {
            setState(() {
              _messages.add(newMessage);
              _isSending = false;
            });
          }
          _scrollToBottom();
          _showSuccessMessage();
          return;
        }
      } catch (e) {
        // Fall through to local handling
      }
    }
    
    // Fallback: Add message locally
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      message: messageText,
      time: _getCurrentTime(),
    );

    if (mounted) {
      setState(() {
        _messages.add(newMessage);
        _isSending = false;
      });
    }

    _scrollToBottom();
    _showSuccessMessage();
  }

  void _showSuccessMessage() {
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                widget.doctor.image,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.testIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctor.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.doctor.specialization,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: AppTheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video call feature coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Start video call',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onPressed: () {
              _showDoctorInfo(context);
            },
            tooltip: 'Doctor information',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppTheme.textLight.withOpacity(0.1),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: AppTheme.spaceMD),
                  Text(
                    'Loading messages...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : Column(
        children: [
          // Messages List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMessagesAsync,
              child: _messages.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
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
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceXS),
                        Text(
                          'Send a message to ${widget.doctor.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
                  color: Colors.black.withOpacity(0.05),
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
                      maxLines: null,
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
            ),
          ),
        ],
      ),
    );
  }

  void _showDoctorInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            const Text(
              'Doctor Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            _buildInfoRow(Icons.person, 'Name', widget.doctor.name),
            _buildInfoRow(
              Icons.school,
              'Qualification',
              widget.doctor.qualification,
            ),
            _buildInfoRow(
              Icons.local_hospital,
              'Working Place',
              widget.doctor.workingPlace,
            ),
            _buildInfoRow(
              Icons.verified_user,
              'NHPC Number',
              widget.doctor.nhpcNumber,
            ),
            _buildInfoRow(Icons.phone, 'Phone', widget.doctor.contactPhone),
            _buildInfoRow(Icons.email, 'Email', widget.doctor.contactEmail),
            if (widget.doctor.address != null)
              _buildInfoRow(
                Icons.location_on,
                'Address',
                widget.doctor.address!,
              ),
            const SizedBox(height: AppTheme.spaceMD),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
