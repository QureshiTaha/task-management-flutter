import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:task_management/main.dart';
import 'package:task_management/resources/localDBHelper.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/resources/model/chatListModal.dart';
import 'package:task_management/resources/model/chatMessageModal.dart';
import 'package:task_management/utils/network_utils.dart';
import 'package:task_management/utils/socket_service.dart';

class MessengerHomeScreen extends StatefulWidget {
  const MessengerHomeScreen({super.key});

  @override
  _MessengerHomeScreenState createState() => _MessengerHomeScreenState();
}

class _MessengerHomeScreenState extends State<MessengerHomeScreen>
    with WidgetsBindingObserver, RouteAware {
  List<dynamic> recentChats = [];
  bool isLoading = false;
  bool haveMore = true;
  int pageCounter = 1;
  final SocketService socketService = SocketService();
  final client = http.Client();
  final TextEditingController searchController = TextEditingController();
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late String userID;
  late String baseURL;
  late RouteObserver<PageRoute> routeObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    routeObserver = RouteObserver<PageRoute>();
    _initNotifications();
    baseURL = dotenv.get('HOST');
    _loadUserData();
  }

  void _initNotifications() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await notificationsPlugin.initialize(initSettings);
  }

  void _loadUserData() {
    final user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    userID = user['userID'];
    connectToSocket(userID);
    fetchRecentChats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    socketService.dispose();
    super.dispose();
  }

  // Called when navigated back to this screen
  @override
  void didPopNext() {
    // Refresh chat list when coming back from chat
    fetchRecentChats();
  }

  // App lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optional: handle background/foreground
  }

  void connectToSocket(String userID) {
    socketService.connect(userID: userID, chatIDs: [userID], isChat: false);
    socketService.chatListUpdate((data) async {
      final message = ChatMessage.fromMap(data);
      if (mounted) {
        showLocalNotification(message);
        await ChatDatabase.instance.insertMessage(message);
        await updateChatList(message);
      }
    });
  }

  void showLocalNotification(ChatMessage message) async {
    // Show notification if not on chat screen
    String? currentRoute;
    navigatorKey.currentState?.popUntil((route) {
      currentRoute = route.settings.name;
      return true;
    });
    if (currentRoute == "/chat") return;

    await notificationsPlugin.show(
      message.timestamp.hashCode,
      "New Message",
      message.message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          'Chat Messages',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.toMap()),
    );
  }

  Future<void> updateChatList(ChatMessage newMsg) async {
    final chatList = await ChatDatabase.instance.getChatListByChatID(
      newMsg.chatID,
    );
    if (chatList != null) {
      await ChatDatabase.instance.updateChat(
        ChatList(
          chatName: chatList.chatName,
          chatType: chatList.chatType,
          receiverUserID: chatList.receiverUserID,
          chatID: chatList.chatID,
          recentMessage: newMsg.message,
          recentMessageTimestamp: newMsg.timestamp,
        ),
      );

      setState(() {
        recentChats =
            recentChats.map((chat) {
              if (chat['chatID'] == newMsg.chatID) {
                return {
                  ...chat,
                  'recentMessage': newMsg.message,
                  'recentMessageTimestamp': newMsg.timestamp,
                };
              }
              return chat;
            }).toList();
      });
    }
  }

  Future<void> fetchRecentChats({bool reset = false}) async {
    if (isLoading) return;
    if (reset) {
      pageCounter = 1;
      recentChats.clear();
      haveMore = true;
    }

    setState(() => isLoading = true);
    final currentPage = pageCounter;
    pageCounter += 1;

    final accessToken = localStorage.getString('accessToken');
    final isConnected = await NetworkUtils.hasInternetConnection();

    if (isConnected) {
      final response = await client.get(
        Uri.https(baseURL, '/api/v1/chats/get-chat-list/$userID', {
          'page': '$currentPage',
          'limit': '20',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> newChats = data['data'];

        if (newChats.isNotEmpty) {
          await ChatDatabase.instance.clearAllChats();
          await ChatDatabase.instance.insertMultipleChats(
            newChats.map((e) => ChatList.fromMap(e)).toList(),
          );

          final localChats = await ChatDatabase.instance.getChatList(userID);
          setState(() {
            recentChats.addAll(localChats.map((c) => c.toMap()).toList());
            haveMore = newChats.length == 20;
          });
        } else {
          haveMore = false;
        }
      } else {
        print('Error fetching chats: ${response.body}');
      }
    } else {
      // Load from local db
      final localChats = await ChatDatabase.instance.getChatList(userID);
      setState(() {
        recentChats = localChats.map((c) => c.toMap()).toList();
        haveMore = false; // offline, no more to load
      });
    }

    setState(() => isLoading = false);
  }

  // UI: Pull-to-refresh
  Future<void> refreshChats() async {
    await fetchRecentChats(reset: true);
  }

  void _openNewChatDialog() {
    // Your existing code to create new chat
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);
      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} sec ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (dt.day == now.day &&
          dt.month == now.month &&
          dt.year == now.year) {
        return DateFormat('h:mma').format(dt).toLowerCase();
      } else if (dt.day == now.day - 1 &&
          dt.month == now.month &&
          dt.year == now.year) {
        return 'Yesterday ${DateFormat('h:mma').format(dt).toLowerCase()}';
      } else {
        return DateFormat('d MMM y h:mma').format(dt).toLowerCase();
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messenger'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (choice) {
              if (choice == 'Sync older Chats') {
                fetchRecentChats();
              } else if (choice == 'Settings') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings not implemented')),
                );
              } else if (choice == 'Delete all chats') {
                ChatDatabase.instance.deleteAllChats();
                setState(() => recentChats = []);
              }
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'Sync older Chats',
                    child: Text('Sync older Chats'),
                  ),
                  const PopupMenuItem(
                    value: 'Settings',
                    child: Text('Settings'),
                  ),
                  const PopupMenuItem(
                    value: 'Delete all chats',
                    child: Text('Delete all chats'),
                  ),
                ],
          ),
        ],
      ),
      body:
          isLoading && recentChats.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: refreshChats,
                child:
                    recentChats.isEmpty
                        ? const Center(child: Text('No chats found.'))
                        : ListView.builder(
                          itemCount: recentChats.length + (haveMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == recentChats.length) {
                              // Load more indicator
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final chat = recentChats[index];
                            final chatInitials =
                                chat['chatName'] != null
                                    ? chat['chatName']
                                        .split(' ')
                                        .map((e) => e.isNotEmpty ? e[0] : '')
                                        .take(2)
                                        .join()
                                    : 'U';

                            // Handle reply message
                            String mainText = chat['recentMessage'] ?? '';
                            final replyRegex = RegExp(
                              r'<reply(?: messageID="(.*?)")?>(.*?)<\/reply>',
                              dotAll: true,
                            );
                            final match = replyRegex.firstMatch(mainText);
                            if (match != null) {
                              mainText = mainText
                                  .replaceFirst(replyRegex, '')
                                  .trim()
                                  .replaceAll('\n', ' ');
                              mainText =
                                  mainText.length > 50
                                      ? mainText.substring(0, 50) + '...'
                                      : mainText;
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    chat['chatType'] == 'private'
                                        ? Colors.grey[300]
                                        : Colors.blue,
                                child:
                                    chat['chatType'] == 'private'
                                        ? Text(
                                          chatInitials.toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.group,
                                          color: Colors.white,
                                        ),
                              ),
                              title: Text(chat['chatName'] ?? 'Unknown'),
                              subtitle: Text(mainText),
                              trailing: Text(
                                _formatTime(
                                  chat['recentMessageTimestamp'] ?? '',
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                navigatorKey.currentState?.pushNamed(
                                  '/chat',
                                  arguments: {
                                    'chatID': chat['chatID'],
                                    'chatType': chat['chatType'],
                                    'chatName': chat['chatName'],
                                    'receiverUserID':
                                        chat['receiverUserID'] ??
                                        chat['chatID'],
                                  },
                                );
                              },
                            );
                          },
                        ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewChatDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
