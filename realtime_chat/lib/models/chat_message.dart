class ChatMessage {
  final String userId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.userId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      userId: json['userId'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class UserInfo {
  final String userId;
  final String displayName;
  final int colorIndex;

  UserInfo({
    required this.userId,
    required this.displayName,
    required this.colorIndex,
  });
}