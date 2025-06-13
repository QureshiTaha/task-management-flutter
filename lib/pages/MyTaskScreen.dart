import 'dart:async';
import 'dart:convert';
import 'package:api_cache_manager/models/cache_db_model.dart';
import 'package:api_cache_manager/utils/cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:task_management/pages/AddTaskScreen.dart';
import 'package:task_management/pages/TaskDetailScreen.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/utils/AnimatedFabFloating.dart';
import 'package:task_management/utils/network_utils.dart';

class MyTaskScreen extends StatefulWidget {
  const MyTaskScreen({super.key});

  @override
  State<MyTaskScreen> createState() => _MyTaskScreenState();
}

class _MyTaskScreenState extends State<MyTaskScreen> {
  // Existing variables
  static String baseURL = dotenv.get('HOST');
  TextEditingController searchController = TextEditingController();
  ScrollController scrollController = ScrollController();
  var client = http.Client();
  Timer? debounceTimer;
  int currentPage = 1;
  bool hasMore = true;
  bool isFetchingMore = false;
  bool isLoading = false;
  String currentSearchTerm = '';
  Map<String, dynamic> currentUser = {};
  Map<String, dynamic>? userData;
  bool isAdmin = false;
  List<dynamic> tasks = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();

    // Setup scroll listener
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 100) {
        if (hasMore && !isFetchingMore) {
          fetchMoreTasks();
        }
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    searchController.dispose();
    debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    final Map<String, dynamic> user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    setState(() {
      currentUser = user;
      userData = user;
    });
    final userRole = user['userRole'];

    setState(() {
      isAdmin = userRole >= 2;
    });

    fetchTasks(reset: true);
  }

  void onSearchChanged(String value) {
    // Cancel previous timer
    debounceTimer?.cancel();

    // Set new debounce timer
    debounceTimer = Timer(const Duration(milliseconds: 500), () {
      currentSearchTerm = value;
      fetchTasks(reset: true);
    });
  }

  void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTaskModal(),
    ).then((_) => fetchUserData());
  }

  Future<void> fetchTasks({bool reset = true}) async {
    if (reset) {
      currentPage = 1;
      hasMore = true;
      tasks.clear();
    }

    setState(() {
      isLoading = true;
    });

    String cacheKey = "task_list_${currentUser['userID']}_$currentSearchTerm";

    if (await NetworkUtils.hasInternetConnection()) {
      try {
        final accessToken = localStorage.getString('accessToken');
        final response = await client.get(
          Uri.https(
            baseURL,
            '/api/v1/tasks/assigned-to-me/${currentUser['userID']}',
            {
              'search': currentSearchTerm,
              'page': currentPage.toString(),
              'limit': '5',
            },
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          await APICacheManager().addCacheData(
            APICacheDBModel(key: cacheKey, syncData: response.body),
          );

          final dataBody = jsonDecode(response.body);
          final List<dynamic> fetchedTasks = dataBody["data"];

          final bool serverHasMore =
              dataBody["data"].isNotEmpty &&
              (dataBody["data"].last["haveMore"] ?? false);

          setState(() {
            tasks.addAll(fetchedTasks);
            // Assume API indicates if more data exists
            hasMore = serverHasMore;
            isLoading = false;
            isFetchingMore = false;
            currentPage++;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to load tasks from server',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
          final cachedData = await APICacheManager().getCacheData(cacheKey);

          if (cachedData != null) {
            setState(() {
              tasks = jsonDecode(cachedData.syncData)['data'];
              isLoading = false;
            });
          }
        }
      } catch (e) {
        setState(() => isLoading = false);
        print('Error fetching tasks: $e');
      }
    } else {
      final cachedData = await APICacheManager().getCacheData(cacheKey);
      if (cachedData != null) {
        setState(() {
          tasks = jsonDecode(cachedData.syncData)['data'];
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchMoreTasks() async {
    if (hasMore && !isFetchingMore) {
      setState(() {
        isFetchingMore = true;
      });
      await fetchTasks(reset: false);
    }
  }

  Widget buildSearchBar() {
    final theme = Theme.of(context);
    bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search Tasks...',
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.white : Colors.black,
          ),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget buildTaskItem(dynamic task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Choose gradient colors based on theme
    final gradientColors =
        isDark
            ? [Colors.grey[800]!, Colors.grey[900]!]
            : [Colors.white, Colors.white];

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
              builder: (_) => TaskDetailScreen(taskID: task['taskID']),
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
            backgroundColor: _getStatusColor(task['status'], theme),
            child: Icon(Icons.task, color: theme.colorScheme.onPrimary),
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
            color: isDark ? Colors.white54 : Colors.black,
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
                  color:
                      isDark
                          ? Colors.white54.withOpacity(0.7)
                          : Colors.black38.withOpacity(0.7),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "Created by ${task['created_by_UserName']}" ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isDark
                          ? Colors.white54.withOpacity(0.7).withOpacity(0.7)
                          : Colors.black54.withOpacity(0.7).withOpacity(0.7),
                ),
              ),
              // // border bottom
              // const Divider(thickness: 0.4, color: Colors.grey),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _getStatusColor(task['status'], theme),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusText(task['status']),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Priority ${task['priority']}" ?? '',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Tasks')),
      body:
          tasks.isEmpty && isLoading
              ? Center(child: CircularProgressIndicator())
              : tasks.isEmpty
              ? Center(
                child: Text(
                  'No tasks found',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              )
              : Column(
                children: [
                  buildSearchBar(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => fetchTasks(reset: true),
                      child: ListView.separated(
                        separatorBuilder: (_, __) => Container(height: 12),
                        padding: const EdgeInsets.all(12),
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: tasks.length + 1,
                        itemBuilder: (context, index) {
                          if (index == tasks.length) {
                            // Show loader at bottom
                            return hasMore
                                ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : SizedBox.shrink();
                          }
                          final task = tasks[index];
                          return buildTaskItem(task);
                        },
                      ),
                    ),
                  ),
                  if (isLoading && tasks.isEmpty)
                    Center(child: CircularProgressIndicator()),
                ],
              ),
      floatingActionButton:
          isAdmin
              ? AnimatedFab(onPressed: _openAddTaskModal, text: "Create Task")
              : null,
    );
  }

  Color _getStatusColor(String? status, ThemeData theme) {
    switch (status?.toLowerCase()) {
      case 'not_assigned':
        return const Color(0xFFF44336).withOpacity(0.9);
      case 'pending':
        return const Color(0xFFFF9800).withOpacity(0.9);
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
