import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:task_management/main.dart';
import 'package:task_management/pages/Messenger/ChatScreen.dart';
import 'package:task_management/resources/localDBHelper.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/resources/model/chatListModal.dart';
import 'package:task_management/resources/model/chatMessageModal.dart';
import 'package:task_management/utils/network_utils.dart';
import 'package:task_management/utils/socket_service.dart';

class MessengerHomeScreen extends StatefulWidget {
  const MessengerHomeScreen({super.key});

  @override
  State<MessengerHomeScreen> createState() => _MessengerHomeScreenState();
}

class _MessengerHomeScreenState extends State<MessengerHomeScreen>
    with WidgetsBindingObserver {
  List<dynamic> recentChats = [];
  List<dynamic> users = [];
  bool isLoading = false;
  bool haveMore = true;
  int pageCounter = 1;
  final SocketService socketService = SocketService();
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  late AppLifecycleState _appState = AppLifecycleState.resumed;
  final client = http.Client();
  final TextEditingController searchController = TextEditingController();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late String userID;
  late String baseURL;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    baseURL = dotenv.get('HOST');
    final Map<String, dynamic> user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    userID = user['userID'];
    connectToSocket(userID);
    fetchRecentChats();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState = state;
    print(
      '🌀🌀🌀 App lifecycle changed: $_appState is Background $isAppInBackground',
    );
  }

  bool get isAppInBackground => _appState != AppLifecycleState.resumed;

  void showLocalNotification(ChatMessage message) {
    // Current route

    String? currentPath;
    navigatorKey.currentState?.popUntil((route) {
      currentPath = route.settings.name;
      return true;
    });
    print("👉currentRoute: $currentPath");
    if (currentPath == "/chat") return;
    flutterLocalNotificationsPlugin.show(
      message.timestamp.hashCode,
      "New MessageHome",
      message.message,
      const NotificationDetails(
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

  // Connect to socket function
  void connectToSocket(userID) {
    socketService.connect(userID: userID, chatIDs: [userID], isChat: false);
    socketService.chatListUpdate((data) async {
      print(' [📥📥] New message from socket in ChatList: $data');
      if (isAppInBackground) showLocalNotification(ChatMessage.fromMap(data));
      showLocalNotification(ChatMessage.fromMap(data));
      final newMsg = ChatMessage.fromMap(data);
      await ChatDatabase.instance.insertMessage(newMsg);
      updateMyChatList(newMsg);
    });
  }

  Future<void> updateMyChatList(ChatMessage newMsg) async {
    if (isLoading) return;

    // Update ChatList By chatID
    try {
      final chatList = await ChatDatabase.instance.getChatListByChatID(
        newMsg.chatID,
      );

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
    } catch (e) {
      print('Error updating chat list: $e');
    }

    setState(() {
      // recentChats
      recentChats =
          recentChats.map((chat) {
            if (chat['chatID'] == newMsg.chatID) {
              return {
                'chatName': chat['chatName'],
                'chatType': chat['chatType'],
                'receiverUserID': chat['receiverUserID'],
                'chatID': chat['chatID'],
                'recentMessage': newMsg.message,
                'recentMessageTimestamp': newMsg.timestamp,
              };
            }
            return chat;
          }).toList();
    });
  }

  Future<void> fetchRecentChats() async {
    print("fetchRecentChats: $isLoading, $haveMore");
    if (isLoading || !haveMore) return;
    recentChats = [];
    setState(() => isLoading = true);

    final currentPage = pageCounter; // Keep track of the current page
    setState(() {
      pageCounter++; // Increment the page counter for the next fetch
    });
    final accessToken = localStorage.getString('accessToken');
    // Check is connected to internet..
    var isConnected = await NetworkUtils.hasInternetConnection();

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

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newChatList =
            (data['data'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();

        if (newChatList.isNotEmpty) {
          // Save messages to the local db
          for (var chats in newChatList) {
            final chatList = ChatList.fromMap(chats);
            print("Inserting chat: ${chatList.toMap()}");
            await ChatDatabase.instance.insertChat(chatList);
          }

          // Get messages from the database after inserting
          final chatsFromLocalDb = await ChatDatabase.instance.getChatList(
            userID,
          );

          final messageMaps =
              chatsFromLocalDb
                  .map((msg) => msg.toMap())
                  .toList()
                  .reversed
                  .toList();

          setState(() {
            recentChats.insertAll(
              0,
              messageMaps,
            ); // Insert message maps at the start
          });
          // Check if there are more messages to load
          if (data['data'][data['data'].length - 1]['haveMore'] == true) {
            setState(() {
              haveMore = true;
              isLoading = false;
              fetchRecentChats();
            });
          } else {
            pageCounter = 1;
          }
        }
      } else {
        print('Error fetching messages: ${response.body}');
      }
    } else {
      // Load from local db
      final chatsFromLocalDb = await ChatDatabase.instance.getChatList(userID);
      final messageMaps =
          chatsFromLocalDb.map((msg) => msg.toMap()).toList().reversed.toList();
      print(messageMaps);
      setState(() {
        recentChats.insertAll(
          0,
          messageMaps,
        ); // Insert message maps at the start
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> searchUsers(String search) async {
    final accessToken = await localStorage.getString('accessToken');
    baseURL = dotenv.get('HOST');
    try {
      final response = await client.get(
        Uri.https(baseURL, '/api/v1/users/allUsers', {'search': search}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        users = data['data'];
      } else {
        print('Failed to load users: ${response.body}');
      }
    } catch (e) {
      print('Error searching users: $e');
    }
  }

  void _openNewChatDialog() {
    String selectedChatType = 'private';
    String? selectedUserID;
    String selectedUserName = '';
    String chatName = '';
    TextEditingController groupNameController = TextEditingController();
    TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                "Start New Chat",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedChatType,
                    decoration: const InputDecoration(labelText: 'Chat Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private'),
                      ),
                      DropdownMenuItem(
                        value: 'broadcast',
                        child: Text('Broadcast'),
                      ),
                      DropdownMenuItem(value: 'group', child: Text('Group')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedChatType = val!;
                        selectedUserID = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  if (selectedChatType == 'group') ...[
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'Enter a group name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Autocomplete<String>(
                      optionsBuilder: (
                        TextEditingValue textEditingValue,
                      ) async {
                        await searchUsers(textEditingValue.text);
                        return users.map((user) {
                          return '${user['userFirstName']} ${user['userSurname'] ?? ''} (${user['userAddressLine2'] ?? ''})';
                        }).toList();
                      },
                      onSelected: (String value) {
                        final selectedUser = users.firstWhere(
                          (u) =>
                              '${u['userFirstName']} ${u['userSurname'] ?? ''} (${u['userAddressLine2'] ?? ''})' ==
                              value,
                        );
                        selectedUserID = selectedUser['userID'];
                        selectedUserName =
                            '${selectedUser['userFirstName']} ${selectedUser['userSurname'] ?? ''}';
                      },
                      fieldViewBuilder: (context, controller, focusNode, _) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Search user...',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final createdBy = userID;

                    if (selectedChatType == 'group' &&
                        groupNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Group name is required")),
                      );
                      return;
                    }

                    if ((selectedChatType != 'group') &&
                        selectedUserID == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a user")),
                      );
                      return;
                    }

                    final accessToken = await localStorage.getString(
                      'accessToken',
                    );

                    final payload = {
                      "chatType": selectedChatType,
                      "createdBy": createdBy,
                      if (selectedChatType != 'private')
                        "chatName": groupNameController.text.trim(),
                      if (selectedChatType != 'group')
                        "chatWith": selectedUserID,
                    };

                    final response = await client.post(
                      Uri.https(baseURL, '/api/v1/chats/new-chat'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $accessToken',
                      },
                      body: jsonEncode(payload),
                    );

                    if (response.statusCode == 200) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Chat created successfully!"),
                        ),
                      );

                      var resData = jsonDecode(response.body)['data'][0];
                      print(resData);
                      // Fetch Again
                      setState(() {
                        haveMore = true;
                        pageCounter = 1;
                        isLoading = false;
                      });
                      await fetchRecentChats();

                      // navigatorKey.currentState?.pushNamed(
                      //   '/chat',
                      //   arguments: {
                      //     'chatID': resData['chatID'],
                      //     'chatType': selectedChatType,
                      //     'chatName':
                      //         selectedChatType != 'private'
                      //             ? groupNameController.text.trim()
                      //             : selectedUserName,
                      //     'receiverUserID':
                      //         resData['chatWith'] ?? resData['chatID'],
                      //   },
                      // );
                    } else {
                      print('Chat creation failed: ${response.body}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${response.body}')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> createNewChat(String receiverID) async {
    final accessToken = await localStorage.getString('accessToken');

    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/chats/new-chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'chatType': 'private',
          'members': [userID, receiverID],
        }),
      );

      if (response.statusCode == 200) {
        _showSnack("Chat started successfully");
        await fetchRecentChats();
      } else {
        _showSnack("Failed to create chat: ${response.body}");
      }
    } catch (e) {
      _showSnack("Error creating chat: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatTime(String timeStr) {
    bool isSameDay(DateTime d1, DateTime d2) {
      return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    }

    bool isYesterday(DateTime d1, DateTime now) {
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      return d1.year == yesterday.year &&
          d1.month == yesterday.month &&
          d1.day == yesterday.day;
    }

    bool isSameWeek(DateTime d1, DateTime d2) {
      final startOfWeek = d2.subtract(Duration(days: d2.weekday % 7));
      final endOfWeek = startOfWeek.add(Duration(days: 6));
      return d1.isAfter(startOfWeek) &&
          d1.isBefore(endOfWeek.add(Duration(days: 1)));
    }

    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} sec ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (isSameDay(dt, now)) {
        return DateFormat('h:mma').format(dt).toLowerCase();
      } else if (isYesterday(dt, now)) {
        return 'Yesterday ${DateFormat('h:mma').format(dt).toLowerCase()}';
      } else if (isSameWeek(dt, now)) {
        return DateFormat('EEEE h:mma').format(dt).toLowerCase();
      } else {
        return DateFormat('d MMM y h:mma').format(dt).toLowerCase();
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messenger'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String choice) {
              if (choice == 'Sync Chats') {
                fetchRecentChats();
              } else if (choice == 'Settings') {
                // Show snackbar not implimented
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings not implimented')),
                );
              } else if (choice == 'Delete all chats') {
                ChatDatabase.instance.deleteAllChats();
                setState(() {
                  recentChats = [];
                });
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Sync older Chats', 'Settings', 'Delete all chats'}.map((
                String choice,
              ) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),

      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : recentChats.isEmpty
              ? const Center(child: Text('No chats found.'))
              : ListView.builder(
                itemCount: recentChats.length,
                itemBuilder: (context, index) {
                  final chat = recentChats[index];
                  // split chatname with space and use its 2 initial if it have length or use just first letter
                  final chatInitials =
                      chat['chatName'] != null
                          ? chat['chatName'].split(' ').length > 1
                              ? chat['chatName'].split(' ')[0][0] +
                                  chat['chatName'].split(' ')[1][0]
                              : chat['chatName'].split(' ')[0][0]
                          : 'U';

                  // Step 1: Extract reply text if present
                  String mainText = chat['recentMessage'];

                  // final replyRegex = RegExp(r'<reply>(.*?)<\/reply>', dotAll: true);
                  final replyRegex = RegExp(
                    r'<reply(?: messageID="(.*?)")?>(.*?)<\/reply>',
                    dotAll: true,
                  );
                  final match = replyRegex.firstMatch(chat['recentMessage']);
                  if (match != null) {
                    mainText = chat['recentMessage']
                        .replaceFirst(replyRegex, '')
                        .trim()
                        .replaceAll('\n', ' ');
                    mainText =
                        mainText.length > 50
                            ? mainText.substring(0, 50) + '...'
                            : mainText;
                  }
                  return ListTile(
                    leading:
                        chat['chatType'] == "private"
                            ? CircleAvatar(
                              backgroundColor: Colors.black26,
                              radius: 23.0,
                              child: CircleAvatar(
                                backgroundColor:
                                    ThemeData().colorScheme.primary,
                                radius: 21.0,
                                child: Text(
                                  chatInitials.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeData().colorScheme.onSecondary,
                                    shadows: [
                                      Shadow(
                                        color:
                                            ThemeData().colorScheme.onSurface,
                                        offset: Offset(0.5, 0.5),
                                        blurRadius: 10.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            : CircleAvatar(
                              backgroundColor: Colors.black26,
                              radius: 23.0,
                              child: CircleAvatar(
                                backgroundColor:
                                    Colors.blue, // You can customize the color~
                                child: Icon(
                                  Icons.group_sharp, // Profile icon
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    title: Text(chat['chatName']),
                    // subtitle: Text(chat['recentMessage']),
                    // make subtitle with length 20
                    subtitle: Text(
                      mainText.length > 50
                          ? mainText.substring(0, 50) + '...'
                          : mainText,
                    ),
                    trailing: Text(
                      _formatTime(chat['recentMessageTimestamp']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      navigatorKey.currentState?.pushNamed(
                        '/chat',
                        arguments: {
                          'chatID': chat['chatID'],
                          'chatType': chat['chatType'],
                          'chatName': chat['chatName'],
                          'receiverUserID':
                              chat['receiverUserID'] ?? chat['chatID'],
                        },
                      );
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewChatDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    socketService.dispose(); // Dispose the socket connection
    super.dispose();
  }
}
