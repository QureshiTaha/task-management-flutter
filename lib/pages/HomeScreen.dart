import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/pages/TaskDetailScreen.dart';
import 'package:task_management/resources/drawer.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final client = http.Client();
  static String baseURL = dotenv.get('HOST');
  Map<String, dynamic>? taskData;
  List<dynamic> logs = [];
  List<dynamic> messageLogs = [];
  List<dynamic> users = [];
  String? selectedUserID;
  bool isLoading = true;
  bool isAssigning = false;
  Map<String, dynamic> user = {};
  int totalCount = 0;
  int page = 1;
  int maxPages = 1;
  int limit = 10;

  @override
  void initState() {
    super.initState();
    fetchMessageLogs();
    // Initialize notification handling and interaction listeners
    // _handleForegroundNotification();
    _handleInteractionWithNotification();
    _updateFCMTokenINDatabase();

    final Map<String, dynamic> user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    this.user = user;
  }

  void _handleInteractionWithNotification() {
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // Navigate to a designated screen upon interaction with the notification
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  void _updateFCMTokenINDatabase() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $fcmToken');
    // Get from local storage
    String? localfcmToken = await localStorage.getString('fcmToken'); //FCM
    if (fcmToken != localfcmToken || user['fcmToken'] != fcmToken) {
      // Update the FCM token in the database
      final accessToken = await localStorage.getString('accessToken');

      final userID = user['userID'];

      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/update-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"userID": userID, "fcmToken": fcmToken}),
      );

      if (response.statusCode == 200) {
        if (fcmToken != null) {
          await localStorage.putString('fcmToken', fcmToken);
        }
        print('FCM token updated successfully');
      } else {
        print('Failed to update FCM token');
      }
    } else {
      print('FCM token is already up to date');
    }
  }

  Future<void> fetchMessageLogs() async {
    final accessToken = await localStorage.getString('accessToken');

    final userID = user['userID'];
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/logs/by-user/$userID', {
        'page': page.toString(),
        'limit': limit.toString(),
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        messageLogs = jsonDecode(response.body)['data']['logs'] ?? [];
        totalCount = jsonDecode(response.body)['data']['totalCount'];
        maxPages = (totalCount / limit).ceil();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      print('Failed to load logs: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var isAdmin =
        user['userRole'] != null && user['userRole'] >= 2 ? true : false;

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Exit App'),
              content: Text('Do you want to exit the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Yes'),
                ),
              ],
            );
          },
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        drawer: SideDrawer(user: user),
        body: RefreshIndicator(
          onRefresh: fetchMessageLogs,
          child:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messageLogs.isNotEmpty
                  ? Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: messageLogs.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = messageLogs[index];
                            String message = log['message'] ?? 'No-msg';
                            String logType = log['log_type'] ?? '';
                            String taskID = log['taskID'] ?? '';
                            String userName = log['userName'] ?? '';
                            print(logType);

                            final logTimestampDate = DateFormat(
                              'dd-MM-yyyy',
                            ).format(
                              DateTime.parse(log['timestamp']).toLocal(),
                            );
                            final logTimestampTime = DateFormat(
                              'hh:mm a',
                            ).format(
                              DateTime.parse(log['timestamp']).toLocal(),
                            );
                            return GestureDetector(
                              onTap:
                                  () => {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => TaskDetailScreen(
                                              taskID: taskID,
                                            ),
                                      ),
                                    ),
                                  },
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                shadowColor:
                                    logType == 'system'
                                        ? Colors.amber
                                        : Colors.lightGreen,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                logType == 'system'
                                                    ? Colors.amber
                                                    : Colors.lightGreen,
                                            child:
                                                logType == 'system'
                                                    ? Icon(
                                                      Icons.person_4,
                                                      color:
                                                          ThemeData()
                                                              .colorScheme
                                                              .onPrimary,
                                                    )
                                                    : Text(
                                                      userName
                                                          .split(' ')
                                                          .map(
                                                            (name) =>
                                                                name.length > 0
                                                                    ? name[0]
                                                                    : '',
                                                          )
                                                          .join(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                          ),

                                          const SizedBox(width: 10),
                                          // Assigned By Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .onBackground,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                Text(
                                                  message,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .onBackground,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 10),
                                          Column(
                                            children: [
                                              Text(
                                                logTimestampDate,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                              Text(
                                                logTimestampTime,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  page > 1
                                      ? theme.colorScheme.surfaceVariant
                                      : Colors.grey,
                              foregroundColor:
                                  page > 1 ? Colors.black : Colors.white,
                            ),
                            // disable previous button if page 1
                            child: const Text("< Newer"),
                            onPressed: () {
                              if (page > 1) {
                                setState(() {
                                  page--;
                                  fetchMessageLogs();
                                });
                              } else {
                                // pull down to refresh
                                fetchMessageLogs();
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          Text("Page $page"),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  page == maxPages
                                      ? Colors.grey
                                      : theme.colorScheme.surfaceVariant,
                              foregroundColor:
                                  page == maxPages
                                      ? Colors.white
                                      : Colors.black,
                            ),
                            child: const Text("older >"),
                            onPressed: () {
                              if (page < maxPages) {
                                setState(() {
                                  page++;
                                  fetchMessageLogs();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  )
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(width: 10, height: 20),
                        Text(
                          "Hello User 😇",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "There is no logs to show.",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}
