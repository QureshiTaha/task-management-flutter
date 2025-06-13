class ChatList {
  final String chatName;
  final String chatType;
  final String receiverUserID;
  final String chatID;
  final String recentMessage;
  final String recentMessageTimestamp;

  ChatList({
    required this.chatName,
    required this.chatType,
    required this.receiverUserID,
    required this.chatID,
    required this.recentMessage,
    required this.recentMessageTimestamp,
  });

  factory ChatList.fromMap(Map<String, dynamic> map) => ChatList(
    chatName: map['chatName'] ?? 'Null',
    chatType: map['chatType'],
    receiverUserID: map['receiverUserID'] ?? 'Null',
    chatID: map['chatID'],
    recentMessage: map['recentMessage'] ?? '',
    recentMessageTimestamp: map['recentMessageTimestamp'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'chatName': chatName,
    'chatType': chatType,
    'receiverUserID': receiverUserID,
    'chatID': chatID,
    'recentMessage': recentMessage,
    'recentMessageTimestamp': recentMessageTimestamp,
  };
}
