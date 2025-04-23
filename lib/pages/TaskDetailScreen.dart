import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/resources/local_storage.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskID;
  const TaskDetailScreen({super.key, required this.taskID});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class User {
  final String userID;
  final String firstName;
  final String lastName;
  final String email; // Add other user-related fields here

  User({
    required this.userID,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  // A method to create a User from a Map (e.g., from an API response)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userID: map['userID'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      email: map['email'],
    );
  }
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final client = http.Client();
  static String baseURL = dotenv.get('HOST');
  Map<String, dynamic>? taskData;
  List<dynamic> logs = [];
  List<dynamic> messageLogs = [];
  List<dynamic> users = [];
  String? selectedUserID;
  bool isLoading = true;
  bool isAssigning = false;
  bool isExpanded = false;
  final Map<String, Map<String, dynamic>> relatedUsers = {};

  final ScrollController _scrollController = ScrollController();
  int currentPage = 1;
  bool isFetchingMore = false;
  bool hasMoreLogs = true;
  int totalCount = 0;

  int limit = 10; // You can customize this

  @override
  void initState() {
    super.initState();
    fetchTaskDetails();
    fetchMessageLogs(widget.taskID);
    _scrollController.addListener(_onScroll);
    _handleForegroundNotification(widget.taskID);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Only fetch next page
      if (!isFetchingMore && hasMoreLogs) {
        fetchMoreMessageLogs(widget.taskID, isLoadMore: true);
      }
    }
  }

  void _handleForegroundNotification(taskID) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Extract notification data from the message
      final RemoteNotification? notification = message.notification;
      if (notification != null) {
        debugPrint(
          '******** Notification Data: ${message.data.toString()} ********',
        );
        fetchMessageLogs(taskID);
      }
    });
  }

  Future<void> fetchTaskDetails() async {
    final accessToken = await localStorage.getString('accessToken');
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/tasks/get/${widget.taskID}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      setState(() {
        taskData = data;
        logs = data['assignments'] ?? [];
        isLoading = false;
      });
    } else {
      print('Failed to load task details: ${response.body}');
      setState(() => isLoading = false);
    }
  }

  Future<void> searchUsers(String search) async {
    final accessToken = await localStorage.getString('accessToken');
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/users/allUsers', {'search': search}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        users = jsonDecode(response.body)['data'];
      });
    } else {
      print('Failed to load users: ${response.body}');
    }
  }

  final Map<String, dynamic> currentUser = jsonDecode(
    jsonEncode(localStorage.getObject('userData') ?? {}),
  );

  Future<void> fetchMessageLogs(String taskID) async {
    final accessToken = await localStorage.getString('accessToken');

    final response = await client.get(
      Uri.https(baseURL, '/api/v1/logs/by-task/$taskID'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        messageLogs = jsonDecode(response.body)['data']['logs'] ?? [];
      });
    } else {
      print('Failed to load logs: ${response.body}');
    }
  }

  Future<void> fetchMoreMessageLogs(
    String taskID, {
    bool isLoadMore = false,
  }) async {
    if (isFetchingMore || totalCount == messageLogs.length) return;

    setState(() {
      isFetchingMore = true;
    });

    final accessToken = localStorage.getString('accessToken');

    final response = await client.get(
      Uri.https(baseURL, '/api/v1/logs/by-task/$taskID/$currentPage/$limit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body)['data'];
      final List<dynamic> newLogs = responseData['logs'] ?? [];
      final int fetchedTotalCount = responseData['totalCount'];

      setState(() {
        totalCount = fetchedTotalCount;
        final existingLogIDs = messageLogs.map((log) => log['logID']).toSet();
        final uniqueNewLogs = newLogs.where(
          (log) => !existingLogIDs.contains(log['logID']),
        );
        if (messageLogs.isEmpty) {
          messageLogs = newLogs;
        } else {
          messageLogs.addAll(uniqueNewLogs);
        }

        hasMoreLogs = messageLogs.length < totalCount;
        if (hasMoreLogs) currentPage++;
      });
    } else {
      print('Failed to load logs: ${response.body}');
    }

    setState(() {
      isFetchingMore = false;
    });
  }

  Future<void> updateOnTask() async {
    // Show Popup for writing message
    final messageController = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Update on Task'),
            content: TextField(
              controller: messageController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(null), // Cancel and return null
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Pop and pass the text entered in the TextField
                  Navigator.of(context).pop(messageController.text);
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );

    // Use the returned message if needed
    if (message != null) {
      final accessToken = localStorage.getString('accessToken');
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': message,
          'taskID': widget.taskID,
          'userID': currentUser['userID'],
          'log_type': "user",
        }),
      );

      if (response.statusCode == 200) {
        fetchMessageLogs(widget.taskID);
      } else {
        // show Bottom error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update message 🤔')),
        );
      }
    }
  }

  Future<void> assignUserOnTask() async {
    final message = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title:
                logs.isEmpty
                    ? const Text('📝 Assign task to user')
                    : const Text('🔀Transfer Task to'),
            content: Autocomplete<String>(
              optionsBuilder: (TextEditingValue value) async {
                if (value.text.isEmpty) return [];
                await searchUsers(value.text);
                return users.map(
                  (user) => '${user['userFirstName']} ${user['userSurname']}',
                );
              },
              onSelected: (String value) {
                final user = users.firstWhere(
                  (u) => '${u['userFirstName']} ${u['userSurname']}' == value,
                );
                setState(() {
                  selectedUserID = user['userID'];
                });
              },
              fieldViewBuilder: (
                context,
                controller,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: (_) => onFieldSubmitted(),
                  decoration: const InputDecoration(
                    labelText: 'Search User here 😊',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(null), // Cancel and return null
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await assignTask();
                  Navigator.of(context).pop(null);
                  // pop
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );

    // Use the returned message if needed
    if (message != null) {
      final accessToken = localStorage.getString('accessToken');
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': message,
          'taskID': widget.taskID,
          'userID': currentUser['userID'],
          'log_type': "user",
        }),
      );

      if (response.statusCode == 200) {
        fetchMessageLogs(widget.taskID);
      } else {
        // show Bottom error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update message 🤔')),
        );
      }
    }
  }

  Future<void> assignTask() async {
    if (selectedUserID == null) return;

    setState(() => isAssigning = true);

    // Confirm with Alert
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Assignment'),
            content: const Text(
              'Are you sure you want to assign this task to ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Cancel
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Confirm
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (confirm != true) {
      setState(() => isAssigning = false);
      return;
    }

    final accessToken = await localStorage.getString('accessToken');

    final response = await client.post(
      Uri.https(baseURL, '/api/v1/tasks/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        "taskID": widget.taskID,
        "userID": selectedUserID,
        "assignedByUserID": currentUser['userID'],
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task assigned successfully')),
      );
      await fetchTaskDetails(); // Refresh logs

      await fetchMessageLogs(widget.taskID);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to assign task')));
    }

    setState(() => isAssigning = false);
  }

  Future<void> updateTaskStatus($status) async {
    debugPrint((taskData?['created_by'] == currentUser['userID']).toString());
    debugPrint(currentUser['userID'].toString());
    debugPrint(taskData?['created_by'].toString());
    debugPrint($status.toString());
    debugPrint(($status == 'completed').toString());
    if (taskData?['created_by'] != currentUser['userID'] &&
        $status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only creator can complete task')),
      );
      return;
    } else {
      final accessToken = await localStorage.getString('accessToken');
      final response = await client.put(
        Uri.https(baseURL, '/api/v1/tasks/${widget.taskID}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({"status": $status, "userID": currentUser['userID']}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully')),
        );
        await fetchTaskDetails(); // Refresh logs
        await fetchMessageLogs(widget.taskID);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete task')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Task Details')),
        body:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taskData?['title'] ?? 'No Title',
                            style: theme.textTheme.titleLarge,
                          ),

                          Text(
                            "Priority: ${taskData?['priority'] ?? 'No Priority'}",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Status: ",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _getStatusColor(
                                    taskData?['status'],
                                    theme,
                                  ),
                                ),
                              ),
                              // Update status Dropdown
                              DropdownButton<String>(
                                icon: _getStatusIcon(taskData?['status']),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(
                                    taskData?['status'],
                                    theme,
                                  ),
                                ),
                                value: taskData?['status'],
                                items: const [
                                  DropdownMenuItem(
                                    value: 'not_assigned',
                                    child: Text('Not Assigned'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('In Progress'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('Completed'),
                                  ),
                                ],
                                onChanged: (value) async {
                                  if (value != null) {
                                    await updateTaskStatus(value);
                                  }
                                },
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: Icon(
                              Icons.info,
                              color: ThemeData().colorScheme.primary,
                              size: 20,
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  ThemeData().colorScheme.onPrimary,
                              foregroundColor: ThemeData().colorScheme.primary,
                            ),
                            label: const Text('View Task Details'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder:
                                    (context) => TaskDetailPopup(
                                      taskData: taskData,
                                      currentUser: currentUser,
                                      getStatusColor: _getStatusColor,
                                      getStatusIcon: _getStatusIcon,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                      // 🔎 Searchable Dropdown
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon:
                                isAssigning
                                    ? const CircularProgressIndicator()
                                    : Icon(
                                      Icons.check,
                                      color: ThemeData().colorScheme.primary,
                                      size: 20,
                                    ),
                            label:
                                logs.isNotEmpty
                                    ? Text('Transfer task')
                                    : Text('Assign Task'),
                            onPressed: isAssigning ? null : assignUserOnTask,
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  ThemeData().colorScheme.onPrimary,
                              foregroundColor: ThemeData().colorScheme.primary,
                            ),
                          ),
                          Spacer(),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.history),
                            label: const Text('View Assignment Logs'),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  ThemeData().colorScheme.onPrimary,
                              foregroundColor: ThemeData().colorScheme.primary,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder:
                                    (context) => AssignmentLogPopup(
                                      logs: logs,
                                      relatedUsers: relatedUsers,
                                      currentUser: currentUser,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),

                      Divider(
                        color: Colors.black,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      // 📝 Logs Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Message Logs ',
                            style: theme.textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            icon: Icon(
                              Icons.message,
                              color: theme.colorScheme.onPrimary,
                              size: 20,
                            ),
                            label: const Text('Update on Task'),
                            onPressed: updateOnTask,
                            style: TextButton.styleFrom(
                              backgroundColor: ThemeData().colorScheme.primary,
                              foregroundColor:
                                  ThemeData().colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      // Message Logs
                      messageLogs.isNotEmpty
                          ? Expanded(
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount:
                                  messageLogs.length + (isFetchingMore ? 1 : 0),
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (index == messageLogs.length) {
                                  return hasMoreLogs
                                      ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                      : const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: Text("You've reached the end"),
                                        ),
                                      );
                                }
                                final log = messageLogs[index];

                                String message = log['message'] ?? 'No-msg';
                                String logType = log['log_type'] ?? '';
                                String loggedByUserID = log['userID'] ?? '';

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

                                String messagedUser =
                                    relatedUsers[loggedByUserID] != null
                                        ? "${relatedUsers[loggedByUserID]!['userFirstName']} ${relatedUsers[loggedByUserID]!['userSurname']}"
                                        : "user";
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                                      ? ThemeData()
                                                          .colorScheme
                                                          .primary
                                                      : loggedByUserID ==
                                                          currentUser['userID']
                                                      ? Colors.green
                                                      : Colors.blueAccent,
                                              child: Icon(
                                                logType == 'system'
                                                    ? Icons.info
                                                    : Icons.message,
                                                color:
                                                    ThemeData()
                                                        .colorScheme
                                                        .onSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    logType == 'system'
                                                        ? 'System'
                                                        : loggedByUserID ==
                                                            currentUser['userID']
                                                        ? 'You'
                                                        : messagedUser,

                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color:
                                                          logType == 'system'
                                                              ? ThemeData()
                                                                  .colorScheme
                                                                  .onBackground
                                                              : loggedByUserID ==
                                                                  currentUser['userID']
                                                              ? Colors
                                                                  .blueAccent
                                                              : theme
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
                                                        .bodySmall
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
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey,
                                                      ),
                                                ),
                                                Text(
                                                  logTimestampTime,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
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
                                );
                              },
                              // itemCount: messageLogs.length,
                            ),
                          )
                          : const Text("No message logs available"),
                    ],
                  ),
                ),
      ),
    );
  }

  Color _getStatusColor(String? status, ThemeData theme) {
    switch (status?.toLowerCase()) {
      case 'not_assigned':
        return Colors.red.withOpacity(0.9);
      case 'pending':
        return Colors.orange.withOpacity(0.9);
      case 'in_progress':
        return Colors.amber.withOpacity(0.9);
      case 'completed':
        return Colors.green.withOpacity(0.9);
      default:
        return theme.colorScheme.surfaceVariant;
    }
  }

  Icon _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'not_assigned':
        return const Icon(Icons.help, color: Colors.red);
      case 'pending':
        return const Icon(Icons.pending_actions, color: Colors.orange);
      case 'in_progress':
        return const Icon(Icons.schedule_rounded, color: Colors.amber);
      case 'completed':
        return const Icon(Icons.task_alt_rounded, color: Colors.green);
      default:
        return const Icon(Icons.pending_actions, color: Colors.grey);
    }
  }
}

class TaskDetailPopup extends StatelessWidget {
  final Map<String, dynamic>? taskData;
  final Map<String, dynamic> currentUser;
  final Color Function(String? status, ThemeData theme) getStatusColor;
  final Icon Function(String? status) getStatusIcon;

  const TaskDetailPopup({
    super.key,
    required this.taskData,
    required this.currentUser,
    required this.getStatusColor,
    required this.getStatusIcon,
  });

  @override
  Widget build(BuildContext context) {
    // debugPrint(taskData?['created_by'].toString());
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            taskData?['title'] ?? 'No Title',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            "Priority: ${taskData?['priority'] ?? 'No Priority'}",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Status: ${taskData?['status'] ?? 'No Status'}",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: getStatusColor(taskData?['status'], theme),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              child: SingleChildScrollView(
                // scroll if content overflows
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      child: Column(
                        children: [
                          Text(
                            taskData?['description'] ?? 'No Description',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssignmentLogPopup extends StatelessWidget {
  final List<dynamic> logs;
  final Map<String, Map<String, dynamic>> relatedUsers;
  final Map<String, dynamic> currentUser;

  const AssignmentLogPopup({
    super.key,
    required this.logs,
    required this.relatedUsers,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Assignment Logs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6, // height for logs
            child: ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = logs[index];
                final assignedBy = log['assigned_by'][0];
                final assignedTo = log['assigned_to'][0];
                final assignedAt = DateFormat(
                  'dd-MM-yyyy hh:mm a',
                ).format(DateTime.parse(log['assigned_at']).toLocal());

                final assignedByUserID = assignedBy['userID'];
                final assignedToUserID = assignedTo['userID'];

                if (!relatedUsers.containsKey(assignedByUserID)) {
                  relatedUsers[assignedByUserID] = assignedBy;
                }
                if (!relatedUsers.containsKey(assignedToUserID)) {
                  relatedUsers[assignedToUserID] = assignedTo;
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Assigned By Avatar
                            CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Text(
                                assignedBy['userFirstName'][0] +
                                    assignedBy['userSurname'][0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Assigned By Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignedBy['userID'] ==
                                            currentUser['userID']
                                        ? 'You'
                                        : '${assignedBy['userFirstName']} ${assignedBy['userSurname']}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          assignedBy['userID'] ==
                                                  currentUser['userID']
                                              ? Colors.blueAccent
                                              : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    assignedBy['userEmail'],
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          assignedBy['userID'] ==
                                                  currentUser['userID']
                                              ? Colors.blueAccent
                                              : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            index == 0
                                ? const Text("Assigned task to")
                                : const Text("Transferred task to"),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            // Assigned To Avatar
                            CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Text(
                                assignedTo['userFirstName'][0] +
                                    assignedTo['userSurname'][0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Assigned To Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignedTo['userID'] ==
                                            currentUser['userID']
                                        ? 'You'
                                        : '${assignedTo['userFirstName']} ${assignedTo['userSurname']}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color:
                                              assignedTo['userID'] ==
                                                      currentUser['userID']
                                                  ? Colors.blueAccent
                                                  : theme
                                                      .colorScheme
                                                      .onBackground,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    assignedTo['userEmail'],
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          assignedTo['userID'] ==
                                                  currentUser['userID']
                                              ? Colors.blueAccent
                                              : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "At $assignedAt",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
