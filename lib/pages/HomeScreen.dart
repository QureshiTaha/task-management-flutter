// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:task_management/pages/AddTaskScreen.dart';
import 'package:task_management/pages/TaskDetailScreen.dart';
import 'package:task_management/resources/drawer.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:intl/intl.dart';
import 'package:task_management/utils/AnimatedFabFloating.dart';
import 'package:task_management/utils/network_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final client = http.Client();
  static String baseURL = dotenv.get('HOST');
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? taskData;
  List<dynamic> logs = [];
  List<dynamic> messageLogs = [];
  List<dynamic> users = [];
  String? selectedUserID;
  bool isLoading = true;
  bool isOffline = false;
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
    _handleInteractionWithNotification();
    _updateFCMTokenINDatabase();

    // Initialize scroll controller for infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // Near bottom
        if (page < maxPages && !isLoading) {
          setState(() {
            page++;
            fetchMessageLogs();
          });
        }
      }
    });

    final Map<String, dynamic> user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    this.user = user;

    // Call the onInternetReconnect function and pass the callback
    NetworkUtils.onInternetReconnect(
      () async => setState(() {
        isOffline = false;
        fetchMessageLogs();
        _handleInteractionWithNotification();
        _updateFCMTokenINDatabase();
      }),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    debugPrint('FCM Token: $fcmToken');
    // Get from local storage
    String? localFcmToken = await localStorage.getString('fcmToken'); //FCM
    if (fcmToken != localFcmToken || user['fcmToken'] != fcmToken) {
      // Update the FCM token in the database
      final accessToken = await localStorage.getString('accessToken');

      final userID = user['userID'];

      try {
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
          debugPrint('FCM token updated successfully');
        } else {
          debugPrint('Failed to update FCM token');
        }
      } catch (e) {
        debugPrint('Failed to update FCM token Catch: $e');
      }
    } else {
      debugPrint('FCM token is already up to date');
    }
  }

  Future<void> fetchMessageLogs() async {
    final accessToken = await localStorage.getString('accessToken');

    if (await NetworkUtils.hasInternetConnection() == false) {
      setState(() {
        isLoading = false;
        isOffline = true;
        messageLogs = [];
      });
      return;
    }
    final userID = user['userID'];
    final response = await client
        .get(
          Uri.https(baseURL, '/api/v1/logs/by-user/$userID', {
            'page': page.toString(),
            'limit': limit.toString(),
          }),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 7));

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to load data from server',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Failed to load logs: ${response.body}');
    }
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

  void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTaskModal(),
    ).then((_) => fetchMessageLogs());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = ThemeData().colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Exit App'),
                content: const Text('Do you want to exit the app?'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          centerTitle: true,
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.search),
          //     onPressed: () {
          //       // Add search functionality
          //     },
          //   ),
          // ],
        ),
        drawer: SideDrawer(user: user),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: fetchMessageLogs,
          color: colorScheme.primary,
          displacement: 40,
          edgeOffset: 20,
          child:
              isLoading
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: colorScheme.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                  : messageLogs.isNotEmpty
                  ? SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: messageLogs.length,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final log = messageLogs[index];
                              String message = log['message'] ?? 'No message';
                              String logType = log['log_type'] ?? '';
                              String taskID = log['taskID'] ?? '';
                              bool isDeleted =
                                  log['taskDeleted'] == '1' ? true : false;
                              String taskTitle =
                                  '${log['taskTitle']}-${taskID.substring(24, 36)}';
                              String userName =
                                  log['userName'].length > 12
                                      ? log['userName'].substring(0, 12) + '...'
                                      : log['userName'] ?? '';
                              // log['userName'] ?? '';
                              final timestamp = log['timestamp'] ?? '';
                              final logTimestampDate = _formatTime(timestamp);
                              //  DateFormat(
                              //   'dd-MM-yyyy',
                              // ).format(DateTime.parse(timestamp).toLocal());
                              // final logTimestampTime = DateFormat(
                              //   'hh:mm a',
                              // ).format(DateTime.parse(timestamp).toLocal());

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap:
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => TaskDetailScreen(
                                              taskID: taskID,
                                            ),
                                      ),
                                    ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            logType != 'system'
                                                ? colorScheme.primary
                                                    .withOpacity(0.5)
                                                : isDarkMode
                                                ? Colors.white.withOpacity(0.2)
                                                : Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    color: theme.cardColor,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  isDeleted
                                                      ? colorScheme.error
                                                      : logType == 'system'
                                                      ? colorScheme.primary
                                                      : colorScheme.secondary,
                                            ),
                                            child: Center(
                                              child:
                                                  isDeleted
                                                      ? Icon(
                                                        Icons.delete,
                                                        color: Colors.white,
                                                        size: 20,
                                                      )
                                                      : logType == 'system'
                                                      ? Icon(
                                                        Icons.settings,
                                                        color:
                                                            colorScheme
                                                                .onSecondary,
                                                        size: 20,
                                                      )
                                                      : Text(
                                                        userName
                                                            .split(' ')
                                                            .map(
                                                              (n) =>
                                                                  n.isNotEmpty
                                                                      ? n[0]
                                                                          .toUpperCase()
                                                                      : '',
                                                            )
                                                            .join(),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      userName,
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          logTimestampDate,
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  message,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(height: 1.4),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (taskID.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: Text(
                                                      'Task : $taskTitle',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                colorScheme
                                                                    .primary,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (maxPages > 1) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios),
                                  color:
                                      page > 1
                                          ? colorScheme.primary
                                          : Colors.grey,
                                  onPressed:
                                      page > 1
                                          ? () {
                                            setState(() {
                                              page--;
                                              fetchMessageLogs();
                                            });
                                          }
                                          : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Page $page of $maxPages',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.secondary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios),
                                  color:
                                      page < maxPages
                                          ? colorScheme.primary
                                          : Colors.grey,
                                  onPressed:
                                      page < maxPages
                                          ? () {
                                            setState(() {
                                              page++;
                                              fetchMessageLogs();
                                            });
                                          }
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                  : isOffline
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 80,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Connection Lost',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check your internet connection',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: fetchMessageLogs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                  : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 80,
                          color: colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When you have messages, they will appear here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
        ),
        floatingActionButton: AnimatedFab(
          onPressed: _openAddTaskModal,
          text: "Create Task",
        ),
      ),
    );
  }
}
