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
        message: 'Namaste! I have reviewed your recent test results. How are you feeling today?',
        time: '10:30 AM',
      ),
      ChatMessage(
        id: '2',
        sender: MessageSender.user,
        message: 'Namaste Doctor, I have been experiencing some eye strain lately, especially when working on computer.',
        time: '10:32 AM',
      ),
      ChatMessage(
        id: '3',
        sender: MessageSender.doctor,
        message: 'I see. Based on your fatigue test results, I recommend taking regular breaks from screen time. Try the 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds.',
        time: '10:35 AM',
      ),
      ChatMessage(
        id: '4',
        sender: MessageSender.user,
        message: 'Thank you Doctor! I will follow your advice. Should I schedule a follow-up visit?',
        time: '10:37 AM',
      ),
      ChatMessage(
        id: '5',
        sender: MessageSender.doctor,
        message: 'Let\'s see how you feel in 2 weeks. If the strain persists, please book a video consultation so I can examine your eyes more thoroughly.',
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
