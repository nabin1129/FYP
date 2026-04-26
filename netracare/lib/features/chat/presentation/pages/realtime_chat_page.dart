import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../config/app_theme.dart';
import '../../../../models/consultation/chat_message_model.dart';
import '../../../../models/consultation/message_delivery_status.dart';
import '../../../../models/consultation/attachment_model.dart';
import '../../../../services/message/chat_service.dart';
import '../../../../services/message/chat_socket_manager.dart';
import '../../../../services/message/chat_attachment_service.dart';
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
    this.onMarkCompleted,
  });

  final String title;
  final String subtitle;
  final bool isDoctor;
  final int? consultationId;
  final int? doctorId;
  final int? patientId;
  final String? avatarUrl;
  final Future<void> Function(BuildContext context)? onMarkCompleted;

  @override
  State<RealtimeChatPage> createState() => _RealtimeChatPageState();
}

class _RealtimeChatPageState extends State<RealtimeChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ChatAttachmentService _attachmentService = ChatAttachmentService();
  final List<Attachment> _selectedAttachments = [];
  String? _currentAttachmentType; // Tracks the type of attachments being shared

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isShowingAttachmentPanel = false;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;
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

    _connectionSub = _chatService.connectionStatusStream.listen((status) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionState = status;
      });
    });

    _errorSub = _chatService.errorStream.listen((message) {
      if (!mounted || message == null || message.isEmpty) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.appColors.error,
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
          backgroundColor: context.appColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    final hasAttachments = _selectedAttachments.isNotEmpty;

    if (text.isEmpty && !hasAttachments) {
      return;
    }

    _inputController.clear();
    _chatService.stopTyping();

    if (hasAttachments) {
      // Set the message type based on attachment type
      final attachmentsToSend = _selectedAttachments.map((att) {
        final updated = Attachment(
          id: att.id,
          fileName: att.fileName,
          type: _currentAttachmentType != null
              ? (_currentAttachmentType == 'clinical'
                    ? AttachmentType.clinicalNote
                    : _currentAttachmentType == 'test'
                    ? AttachmentType.testResult
                    : AttachmentType.medicalRecord)
              : att.type,
          fileSizeBytes: att.fileSizeBytes,
          url: att.url,
          linkedEntityId: att.linkedEntityId,
          linkedEntityTitle: att.linkedEntityTitle,
          linkedEntityDescription: att.linkedEntityDescription,
        );
        return updated;
      }).toList();

      await _chatService.sendMessageWithAttachments(
        text: text.isNotEmpty ? text : null,
        attachments: attachmentsToSend,
      );
      setState(() {
        _selectedAttachments.clear();
        _currentAttachmentType = null;
        _isShowingAttachmentPanel = false;
      });
    } else {
      await _chatService.sendMessage(text);
    }
  }

  Future<void> _showAttachmentPanel() async {
    setState(() => _isShowingAttachmentPanel = !_isShowingAttachmentPanel);

    if (!_isShowingAttachmentPanel) {
      setState(() => _selectedAttachments.clear());
    }
  }

  Future<void> _shareTestResults() async {
    try {
      final patientId = widget.isDoctor
          ? '${widget.patientId}'
          : 'current_user';
      final testResults = await _attachmentService.getShareableTestResults(
        patientId,
      );

      if (!mounted) return;

      if (testResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No test results available to share')),
        );
        return;
      }

      _showAttachmentSelectionDialog('Test Results', testResults, 'test');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading test results: $e')));
    }
  }

  Future<void> _shareMedicalRecords() async {
    try {
      final patientId = widget.isDoctor
          ? '${widget.patientId}'
          : 'current_user';
      final records = await _attachmentService.getShareableMedicalRecords(
        patientId,
      );

      if (!mounted) return;

      if (records.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No medical records available to share'),
          ),
        );
        return;
      }

      _showAttachmentSelectionDialog('Medical Records', records, 'medical');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading medical records: $e')),
      );
    }
  }

  Future<void> _shareClinicalNotes() async {
    try {
      final patientId = widget.isDoctor
          ? '${widget.patientId}'
          : 'current_user';
      final notes = await _attachmentService.getShareableClinicalNotes(
        patientId,
      );

      if (!mounted) return;

      if (notes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No clinical notes available to share')),
        );
        return;
      }

      _showAttachmentSelectionDialog('Clinical Notes', notes, 'clinical');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clinical notes: $e')),
      );
    }
  }

  Future<void> _pickAndAttachFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files
          .where((f) => (f.name).trim().isNotEmpty)
          .map(
            (f) => Attachment(
              id: '${DateTime.now().millisecondsSinceEpoch}_${f.name}',
              fileName: f.name,
              filePath: f.path,
              type: AttachmentType.file,
              fileSizeBytes: f.size > 0 ? f.size : null,
            ),
          )
          .toList();

      if (picked.isEmpty || !mounted) {
        return;
      }

      setState(() {
        _selectedAttachments.addAll(picked);
        _isShowingAttachmentPanel = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to pick file: $e')));
    }
  }

  void _showAttachmentSelectionDialog(
    String title,
    List<Attachment> attachments,
    String attachmentType,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share $title'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final attachment = attachments[index];
              final isSelected = _selectedAttachments.contains(attachment);

              return CheckboxListTile(
                title: Text(
                  attachment.linkedEntityTitle ?? attachment.fileName,
                ),
                subtitle: Text(
                  attachment.linkedEntityDescription ?? attachment.sizeDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedAttachments.add(attachment);
                      _currentAttachmentType = attachmentType;
                    } else {
                      _selectedAttachments.remove(attachment);
                      if (_selectedAttachments.isEmpty) {
                        _currentAttachmentType = null;
                      }
                    }
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _selectedAttachments.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    setState(() => _isShowingAttachmentPanel = false);
                  },
            child: Text('Share (${_selectedAttachments.length})'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: AppTheme.fontSM)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: AppTheme.spaceSM,
        ),
        side: BorderSide(color: context.appColors.primary.withValues(alpha: 0.5)),
      ),
    );
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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.testIconBackground,
              backgroundImage:
                  (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                  ? NetworkImage(widget.avatarUrl!)
                  : null,
              child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                  ? Text(
                      _initials(widget.title),
                      style: TextStyle(
                        color: colors.primary,
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
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _typingText.isNotEmpty
                        ? _typingText
                        : _subtitleForConnectionState(),
                    style: TextStyle(
                      color: _typingText.isNotEmpty
                          ? colors.primary
                          : _subtitleColorForConnectionState(),
                      fontSize: AppTheme.fontSM,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            _buildConnectionChip(),
          ],
        ),
        actions: [
          if (widget.onMarkCompleted != null)
            IconButton(
              icon: Icon(
                Icons.check_circle_outline,
                color: colors.success,
              ),
              tooltip: 'Mark Completed',
              onPressed: () async {
                await widget.onMarkCompleted!(context);
              },
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: colors.textPrimary),
            onPressed: _chatService.refreshHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_connectionState == ChatConnectionState.reconnecting ||
              _connectionState == ChatConnectionState.failed ||
              _connectionState == ChatConnectionState.disconnected)
            Container(
              width: double.infinity,
              color: colors.warning,
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
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _chatService.refreshHistory,
                    child: _messages.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: colors.textSecondary,
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
                                child: ChatBubble(
                                  message: msg,
                                  isMine: widget.isDoctor
                                      ? msg.sender == MessageSender.doctor
                                      : msg.sender == MessageSender.user,
                                ),
                              );
                            },
                          ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attachment panel
                if (_isShowingAttachmentPanel)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                      vertical: AppTheme.spaceSM,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceLight,
                      border: Border(
                        top: BorderSide(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildAttachmentButton(
                                  icon: Icons.science_outlined,
                                  label: 'Test Results',
                                  onPressed: _shareTestResults,
                                ),
                                const SizedBox(width: AppTheme.spaceSM),
                                _buildAttachmentButton(
                                  icon: Icons.description_outlined,
                                  label: 'Medical Records',
                                  onPressed: _shareMedicalRecords,
                                ),
                                const SizedBox(width: AppTheme.spaceSM),
                                _buildAttachmentButton(
                                  icon: Icons.note_outlined,
                                  label: 'Clinical Notes',
                                  onPressed: _shareClinicalNotes,
                                ),
                                if (widget.isDoctor) ...[
                                  const SizedBox(width: AppTheme.spaceSM),
                                  _buildAttachmentButton(
                                    icon: Icons.upload_file_outlined,
                                    label: 'Attach File',
                                    onPressed: _pickAndAttachFile,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Selected attachments preview
                if (_selectedAttachments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                      vertical: AppTheme.spaceSM,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      border: Border(
                        top: BorderSide(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _selectedAttachments.map((attachment) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppTheme.spaceSM,
                            ),
                            child: Chip(
                              label: Text(
                                attachment.linkedEntityTitle ??
                                    attachment.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: () {
                                setState(() {
                                  _selectedAttachments.remove(attachment);
                                });
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                // Input and send row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                    vertical: AppTheme.spaceSM,
                  ),
                  decoration: BoxDecoration(color: colors.surface),
                  child: Row(
                    children: [
                      // Attachment toggle button
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          icon: Icon(
                            _isShowingAttachmentPanel
                                ? Icons.close
                                : Icons.attach_file_outlined,
                            color: colors.primary,
                          ),
                          onPressed: _showAttachmentPanel,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onChanged: _onTextChanged,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            filled: true,
                            fillColor: colors.surfaceLight,
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
                            backgroundColor: colors.primary,
                          ),
                          onPressed: _send,
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleForConnectionState() {
    switch (_connectionState) {
      case ChatConnectionState.connected:
        return widget.subtitle;
      case ChatConnectionState.connecting:
        return 'Connecting...';
      case ChatConnectionState.reconnecting:
        return 'Reconnecting...';
      case ChatConnectionState.failed:
        return 'Connection failed';
      case ChatConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  Color _subtitleColorForConnectionState() {
    final colors = context.appColors;
    switch (_connectionState) {
      case ChatConnectionState.connected:
        return colors.success;
      case ChatConnectionState.connecting:
      case ChatConnectionState.reconnecting:
        return colors.warning;
      case ChatConnectionState.failed:
      case ChatConnectionState.disconnected:
        return colors.error;
    }
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

  Widget _buildConnectionChip() {
    final label = _chipLabelForConnectionState();
    final color = _subtitleColorForConnectionState();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _chipLabelForConnectionState() {
    switch (_connectionState) {
      case ChatConnectionState.connected:
        return 'Live';
      case ChatConnectionState.connecting:
      case ChatConnectionState.reconnecting:
        return 'Syncing';
      case ChatConnectionState.failed:
      case ChatConnectionState.disconnected:
        return 'Offline';
    }
  }
}
