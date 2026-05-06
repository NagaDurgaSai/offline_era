import 'dart:typed_data';

enum MessageType { text, code, clipboard, file }

class ChatMessage {
  final String id;
  final String senderName;
  final String senderIp;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isMe;
  final Uint8List? fileBytes;
  final String? fileName;
  final String? savedPath;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderIp,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isMe,
    this.fileBytes,
    this.fileName,
    this.savedPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderName': senderName,
        'senderIp': senderIp,
        'content': content,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myIp) {
    return ChatMessage(
      id: json['id'],
      senderName: json['senderName'],
      senderIp: json['senderIp'],
      content: json['content'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      isMe: json['senderIp'] == myIp,
    );
  }
}
