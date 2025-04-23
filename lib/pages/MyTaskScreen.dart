import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:task_management/pages/AddTaskScreen.dart';
import 'package:task_management/pages/TaskDetailScreen.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:http/http.dart' as http;

class MyTaskScreen extends StatefulWidget {
  const MyTaskScreen({super.key});

  @override
  State<MyTaskScreen> createState() => _MyTaskScreenState();
}

class _MyTaskScreenState extends State<MyTaskScreen> {
  Map<String, dynamic>? userData;
  static String baseURL = dotenv.get('HOST');
  List<dynamic> tasks = [];
  var client = http.Client();
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final Map<String, dynamic> user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    final userRole = user['userRole'];
    final userID = user['userID'];

    setState(() {
      isAdmin = userRole == 2 || userRole == 3;
    });

    await fetchTasks(userID);
  }

  Future<void> fetchTasks(String userID) async {
    final accessToken = await localStorage.getString('accessToken');
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/tasks/assigned-to-me/$userID'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      setState(() {
        tasks = jsonDecode(response.body)['data'];
      });
    } else {
      print('Failed to load tasks: ${response.body}');
    }
  }

  void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTaskScreen(),
    ).then((_) => fetchUserData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body:
          tasks.isEmpty
              ? Center(
                child: Text(
                  'No tasks found',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => Container(height: 12),

                // Divider(
                //   thickness: 0.4,
                //   color: theme.colorScheme.onSurface,
                // ),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  print("TaskID");
                  print(task['taskID']);
                  return Card(
                    elevation: 3,
                    // shape: RoundedRectangleBorder(
                    //   borderRadius: BorderRadius.circular(12),
                    // ),
                    color: theme.cardColor,
                    child: ListTile(
                      onTap: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => TaskDetailScreen(taskID: task['taskID']),
                          ),
                        );
                        if (result == true) {
                          fetchUserData(); // Refresh tasks when coming back from TaskDetailScreen
                        }
                      },

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                        side: BorderSide(
                          color: _getStatusColor(task['status'], theme),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),

                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.onSurface,
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: _getStatusColor(
                            task['status'],
                            theme,
                          ),
                          child: Icon(
                            Icons.task,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      title: Text(
                        task['title'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Trim text to max 3 line then ...
                              task['description'] ?? 'No description',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "Created by ${task['created_by_UserName']}" ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                            Text(
                              "Priority ${task['priority']}" ?? '',
                              style: TextStyle(fontSize: 14),
                            ),

                            // // border bottom
                            // const Divider(thickness: 0.4, color: Colors.grey),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task['status'], theme),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(task['status']),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton:
          isAdmin
              ? FloatingActionButton(
                onPressed: _openAddTaskModal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  // Helper function to color-code task status based on theme
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'not_assigned':
        return "Not Assigned";
      case 'pending':
        return "Pending";
      case 'in_progress':
        return "In Progress";
      case 'completed':
        return "Completed";
      default:
        return status.toString();
    }
  }
}
