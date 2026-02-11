/// Model for Chat Messages
class ChatMessage {
  final String id;
  final MessageSender sender;
  final String message;
  final String time;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.time,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sender: MessageSender.fromString(json['sender'] as String),
      message: json['message'] as String,
      time: json['time'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toString(),
      'message': message,
      'time': time,
    };
  }

  // Static method to get mock chat messages
  static List<ChatMessage> getMockMessages() {
    return [
      ChatMessage(
        id: '1',
        sender: MessageSender.doctor,
        message: 'Hello! I have reviewed your recent test results. How are you feeling today?',
        time: '10:30 AM',
      ),
      ChatMessage(
        id: '2',
        sender: MessageSender.user,
        message: 'Hi Doctor, I have been experiencing some eye strain lately.',
        time: '10:32 AM',
      ),
      ChatMessage(
        id: '3',
        sender: MessageSender.doctor,
        message: 'I see. Based on your fatigue test results, I recommend taking regular breaks from screen time. Try the 20-20-20 rule.',
        time: '10:35 AM',
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
