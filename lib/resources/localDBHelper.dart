import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:task_management/resources/model/chatListModal.dart';
import 'package:task_management/resources/model/chatMessageModal.dart';

class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._init();
  static Database? _database;

  ChatDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // await deleteDatabase(path); //Add this When Appending New DB
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _migrateDB,
    );
  }

  Future<void> _migrateDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _createDB(db, newVersion);
    }
    // Add more version checks here as your app evolves
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE messages ADD COLUMN new_column TEXT');
    // }
  }

  Future _createDB(Database db, int version) async {
    // Create the messages table
    await db.execute('''
    CREATE TABLE messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      messageID TEXT UNIQUE,
      chatID TEXT,
      senderID TEXT,
      message TEXT,
      timestamp TEXT,
      isRead INTEGER,
      isQueued INTEGER DEFAULT 0,
      messageType TEXT
    )
    ''');

    // Create the chats table (missing part)
    await db.execute('''
    CREATE TABLE chats (
      chatID TEXT PRIMARY KEY,
      chatName TEXT,
      chatType TEXT,
      receiverUserID TEXT,
      recentMessage TEXT,
      recentMessageTimestamp INTEGER
    )
    ''');
  }

  Future<void> insertMessage(ChatMessage msg) async {
    final db = await instance.database;
    await db.insert(
      'messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ChatMessage> getMessageByID(ChatMessage msg) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'messageID = ?',
      whereArgs: [msg.messageID],
    );

    return result.map((json) => ChatMessage.fromMap(json)).first;
  }

  Future<void> deleteMessage(String messageID) async {
    final db = await instance.database;
    await db.delete('messages', where: 'messageID = ?', whereArgs: [messageID]);
  }

  Future<void> updateMessage(ChatMessage msg) async {
    final db = await instance.database;
    await db.update(
      'messages',
      msg.toMap(),
      where: 'messageID = ?',
      whereArgs: [msg.messageID],
    );
  }

  // DElete all chats with ChatID
  Future<void> deleteAllMessagesByChatID(String chatID) async {
    final db = await instance.database;
    await db.delete('messages', where: 'chatID = ?', whereArgs: [chatID]);
  }

  Future<List<ChatMessage>> getMessagesByChatID(String chatID) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'chatID = ?',
      whereArgs: [chatID],
      orderBy: 'timestamp ASC',
    );

    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }

  // For Chat Lists
  Future<void> insertChat(ChatList chat) async {
    final db = await instance.database;
    await db.insert(
      'chats',
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAllChats() async {
    final db = await instance.database;
    await db.delete('chats');
  }

  Future<void> insertMultipleChats(List<ChatList> chats) async {
    final db = await instance.database;
    final batch = db.batch();

    for (final chat in chats) {
      batch.insert(
        'chats',
        chat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  Future<List<ChatList>> getChatList(String userID) async {
    final db = await instance.database;
    final result = await db.query(
      'chats',
      orderBy: 'recentMessageTimestamp ASC',
    );
    return result.map((json) => ChatList.fromMap(json)).toList();
  }

  Future<void> deleteChat(String chatID) async {
    final db = await instance.database;
    await db.delete('chats', where: 'chatID = ?', whereArgs: [chatID]);
  }

  Future<void> deleteAllChats() async {
    final db = await instance.database;
    await db.delete('chats');
    await db.delete('messages');
  }

  // getChatListByChatID
  Future<ChatList> getChatListByChatID(String chatID) async {
    final db = await instance.database;
    final result = await db.query(
      'chats',
      where: 'chatID = ?',
      whereArgs: [chatID],
    );
    if (result.isEmpty) {
      return ChatList(
        chatID: "",
        chatName: "",
        chatType: "",
        receiverUserID: "",
        recentMessage: "",
        recentMessageTimestamp: "",
      );
    }
    return result.map((json) => ChatList.fromMap(json)).first;
  }

  Future<void> updateChat(ChatList chat) async {
    final db = await instance.database;

    // Insert or update
    // await db.update(
    //   'chats',
    //   chat.toMap(),
    //   where: 'chatID = ?',
    //   whereArgs: [chat.chatID],
    // );

    await db.insert(
      'chats',
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMessageReedAllPrevious(
    String messageID,
    String chatID,
  ) async {
    final db = await instance.database;

    // Step 1: Get id of the target message
    final result = await db.query(
      'messages',
      columns: ['id'],
      where: 'messageID = ? AND chatID = ?',
      whereArgs: [messageID, chatID],
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception("Message with ID $messageID not found in chat $chatID");
    }

    final targetId = result.first['id'];

    // Step 2: Update all messages in the chat with id <= target
    await db.update(
      'messages',
      {'isRead': 1},
      where: 'chatID = ? AND id <= ?',
      whereArgs: [chatID, targetId],
    );
  }

  Future<void> updateMessageSeenStatus(String messageID) async {
    final db = await instance.database;
    await db.update(
      'messages',
      {'isRead': 1},
      where: 'messageID = ?',
      whereArgs: [messageID],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
