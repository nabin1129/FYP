/// Model for Chat Messages
class ChatMessage {
  final String id;
  final MessageSender sender;
  final String message;
  final String time;
  final String messageType;
  final String? testType;
  final int? testId;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.time,
    this.messageType = 'text',
    this.testType,
    this.testId,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Handle both old and new API response formats
    final senderType = json['sender_type'] ?? json['sender'] ?? 'user';
    final isFromDoctor =
        json['isFromDoctor'] as bool? ?? senderType == 'doctor';

    // Parse timestamp
    String timeStr = json['time'] as String? ?? '';
    if (json['timestamp'] != null) {
      try {
        final dt = DateTime.parse(json['timestamp'] as String);
        timeStr =
            '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
      } catch (_) {
        timeStr = json['timestamp'] as String? ?? '';
      }
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      sender: isFromDoctor ? MessageSender.doctor : MessageSender.user,
      message: json['content'] as String? ?? json['message'] as String? ?? '',
      time: timeStr,
      messageType: json['message_type'] as String? ?? 'text',
      testType: json['test_type'] as String?,
      testId: json['test_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toString(),
      'message': message,
      'time': time,
      'message_type': messageType,
      if (testType != null) 'test_type': testType,
      if (testId != null) 'test_id': testId,
      'is_read': isRead,
    };
  }

  /// Check if this is a test result message
  bool get isTestResult => messageType == 'test_result' && testType != null;

  // Static method to get mock chat messages
  static List<ChatMessage> getMockMessages() {
    return [
      ChatMessage(
        id: '1',
        sender: MessageSender.doctor,
        message:
            'Namaste! I have reviewed your recent test results. How are you feeling today?',
        time: '10:30 AM',
      ),
      ChatMessage(
        id: '2',
        sender: MessageSender.user,
        message:
            'Namaste Doctor, I have been experiencing some eye strain lately, especially when working on computer.',
        time: '10:32 AM',
      ),
      ChatMessage(
        id: '3',
        sender: MessageSender.doctor,
        message:
            'I see. Based on your fatigue test results, I recommend taking regular breaks from screen time. Try the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.',
        time: '10:35 AM',
      ),
      ChatMessage(
        id: '4',
        sender: MessageSender.user,
        message:
            'Thank you Doctor! I will follow your advice. Should I schedule a follow-up visit?',
        time: '10:37 AM',
      ),
      ChatMessage(
        id: '5',
        sender: MessageSender.doctor,
        message:
            'Let\'s see how you feel in 2 weeks. If the strain persists, please book a video consultation so I can examine your eyes more thoroughly.',
        time: '10:39 AM',
      ),
    ];
  }
}

/// Enum for message sender
enum MessageSender {
  doctor,
  user;

  static MessageSender fromString(String sender) {
    switch (sender.toLowerCase()) {
      case 'doctor':
        return MessageSender.doctor;
      case 'user':
        return MessageSender.user;
      default:
        return MessageSender.user;
    }
  }

  @override
  String toString() {
    switch (this) {
      case MessageSender.doctor:
        return 'doctor';
      case MessageSender.user:
        return 'user';
    }
  }
}
