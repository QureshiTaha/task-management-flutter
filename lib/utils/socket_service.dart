import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  late IO.Socket _socket;
  bool _connected = false;

  static String baseURL = dotenv.get('HOST');

  SocketService._internal();

  IO.Socket get socket => _socket;

  void connect({
    required String userID,
    required List<String> chatIDs,
    required bool isChat,
  }) {
    if (_connected) {
      print('🔄 Socket already connected. Skipping reconnection.');
      return;
    }

    _socket = IO.io('https://$baseURL', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.connect();

    _socket.onReconnect(
      (_) => print('✅ Socket reconnected ${isChat ? "Chat" : "ChatList"}'),
    );

    _socket.onConnect((_) {
      print('✅ Socket connected ${isChat ? "Chat" : "ChatList"}');
      _connected = true;

      if (isChat) {
        for (var chatID in chatIDs) {
          _socket.emit('joinRoom', {'chatID': chatID});
        }
      } else {
        _socket.emit("joinChatList", {"userID": userID});
      }
    });

    _socket.onDisconnect((_) {
      print('❌ Socket disconnected');
      _connected = false;
    });
  }

  void joinRooms({
    required String userID,
    required List<String> chatIDs,
    required bool isChat,
  }) {
    if (isChat) {
      for (var chatID in chatIDs) {
        print('➡️ Joining chat room: $chatID');
        _socket.emit('joinRoom', {'chatID': chatID});
      }
    } else {
      print('➡️ Joining chat list for user: $userID');
      _socket.emit('joinChatList', {'userID': userID});
    }
  }

  void onNewMessage(Function(dynamic) callback) {
    _socket.on('newMessage', callback);
  }

  void onMessageSeen(Function(dynamic) callback) {
    _socket.on('messageSeen', callback);
  }

  void onMessageReadAll(Function(dynamic) callback) {
    _socket.on('messageReadAll', callback);
  }

  void chatListUpdate(Function(dynamic) callback) {
    _socket.on('chatListUpdate', callback);
  }

  void readMessage({
    required String userID,
    required String chatID,
    required String messageID,
  }) {
    _socket.emit('readMessage', {
      'userID': userID,
      'chatID': chatID,
      'messageID': messageID,
    });
    print('✅✅✅ Message Readed');
  }

  void seenThisMessage({
    required String userID,
    required String chatID,
    required String messageID,
  }) {
    _socket.emit('seenThisMessage', {
      'userID': userID,
      'chatID': chatID,
      'messageID': messageID,
    });
    print('✅✅ Message Readed');
  }

  void leaveRooms({
    required String userID,
    required List<String> chatIDs,
    required bool isChat,
  }) {
    if (!_connected) return;

    if (isChat) {
      for (var chatID in chatIDs) {
        _socket.emit('leaveRoom', {'chatID': chatID});
      }
    } else {
      _socket.emit('leaveRoom', {'room': userID});
    }
  }

  void disconnect() {
    if (_connected) {
      _socket.disconnect();
      _connected = false;
    }
  }

  void dispose() {
    socket.dispose();
  }
}
