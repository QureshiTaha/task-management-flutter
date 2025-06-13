class ChatMessage {
  final String messageID;
  final String chatID;
  final String senderID;
  final String message;
  final String timestamp;
  final String messageType;
  final int isRead;

  // {
  //   "messageID": "fa433c5f-b868-4abc-b8fa-2593217c5be6",
  //   "senderID": "0ddc7770-bb8f-4308-aad5-4e483770fd07",
  //   "receiverID": "ba9ec9ef-4f7d-46d7-9ef2-dc6e5048b442",
  //   "chatID": "7bcc656e-a30e-4b32-9c26-914c9262b9aa",
  //   "message": "yo",
  //   "messageType": "text",
  //   "isRead": 0,
  //   "timestamp": "2025-05-23 16:13:52"
  // }

  ChatMessage({
    required this.messageID,
    required this.chatID,
    required this.senderID,
    required this.message,
    required this.timestamp,
    required this.messageType,
    required this.isRead,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    messageID: map['messageID'],
    chatID: map['chatID'],
    senderID: map['senderID'],
    message: map['message'],
    timestamp: map['timestamp'],
    messageType: map['messageType'],
    isRead: map['isRead'],
  );

  Map<String, dynamic> toMap() => {
    'messageID': messageID,
    'chatID': chatID,
    'senderID': senderID,
    'message': message,
    'timestamp': timestamp,
    'isRead': isRead,
    'messageType': messageType,
  };
}
